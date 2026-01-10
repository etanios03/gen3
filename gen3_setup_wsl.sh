#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------
# ENV + OS DETECTION
# -----------------------------
OS="$(uname -s)"
IS_WSL=false

if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

# Clean PATH (no macOS paths)
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# -----------------------------
# HELPER FUNCTION
# -----------------------------
check_and_install() {
  local cmd=$1
  local install_cmd=$2
  local url=$3

  if ! command -v "$cmd" &>/dev/null; then
    echo "⚙️  $cmd not found. Installing..."
    eval "$install_cmd" || {
      echo "❌ Failed to install $cmd"
      echo "👉 Install manually: $url"
      exit 1
    }
    echo "✅ $cmd installed."
  fi
}

# -----------------------------
# DOCKER CHECK (WSL-AWARE)
# -----------------------------
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found."

  if $IS_WSL; then
    cat <<EOF
You are running inside WSL.

Install Docker Desktop for Windows:
https://www.docker.com/products/docker-desktop/

Then enable:
  Docker Desktop → Settings → Resources → WSL Integration

After that, restart WSL:
  wsl --shutdown
EOF
  else
    echo "Install Docker for your OS."
  fi

  exit 1
fi

# -----------------------------
# PACKAGE MANAGER
# -----------------------------
if command -v apt &>/dev/null; then
  PKG_MGR="apt"
else
  PKG_MGR=""
fi

# -----------------------------
# DEPENDENCIES
# -----------------------------

# kind
check_and_install \
  kind \
  "curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x kind && sudo mv kind /usr/local/bin/kind" \
  "https://kind.sigs.k8s.io/"

# kubectl
check_and_install \
  kubectl \
  "curl -LO https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/" \
  "https://kubernetes.io/docs/tasks/tools/"

# helm
check_and_install \
  helm \
  "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" \
  "https://helm.sh/docs/intro/install/"

# k9s (NO snap — WSL safe)
check_and_install \
  k9s \
  "curl -sS https://webinstall.dev/k9s | bash" \
  "https://k9scli.io/"

echo "✅ All dependencies verified."

# -----------------------------
# KIND CLUSTER
# -----------------------------
if kind get clusters | grep -q '^kind$'; then
  echo "🧹 Deleting existing Kind cluster..."
  kind delete cluster
fi

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF

# -----------------------------
# INGRESS
# -----------------------------
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for ingress-nginx controller..."

timeout=$((SECONDS + 300))
while ! kubectl get pods -n ingress-nginx \
  -l app.kubernetes.io/component=controller 2>/dev/null | grep -q controller; do
  sleep 1
  (( SECONDS > timeout )) && {
    echo "❌ Timed out waiting for ingress-nginx pod"
    exit 1
  }
done

kubectl wait \
  --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "✅ ingress-nginx is ready"

# -----------------------------
# GEN3
# -----------------------------
helm upgrade --install dev gen3/gen3 -f values_v1.yaml

echo "🎉 Gen3 setup complete"
echo "👉 Run: k9s"
