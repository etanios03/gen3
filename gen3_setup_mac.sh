#!/bin/bash
set -e
set -euo pipefail

# ---- FIX PATH FOR NON-INTERACTIVE + POETRY SHELLS ----
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:$PATH"


# --- macOS: add Docker Desktop CLI to PATH ---
if [[ "$(uname -s)" == "Darwin" ]]; then
  export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
fi

# --- HELPER FUNCTION CHECK FOR DEPENDENCIES ---
check_and_install() {
  local cmd=$1
  local install_cmd=$2
  local url=$3

  if ! command -v "$cmd" &>/dev/null; then
    echo "⚙️  $cmd not found. Installing..."
    eval "$install_cmd" || {
      echo "Failed to install $cmd."
      echo "Install manually: $url"
      exit 1
    }
    echo "✅ $cmd installed successfully."
  fi
}

# --- CHECK FOR DOCKER INSTALLATION ---
if ! command -v docker &> /dev/null; then
  echo "Docker command not found. Please install Docker Desktop:"
  echo " https://www.docker.com/products/docker-desktop/"
  exit 1
fi

# --- OS DETECTION  ---
OS=$(uname -s)
case "$OS" in
  Darwin) PKG_MGR="brew" ;;
  Linux)
    if command -v apt &>/dev/null; then
      PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
      PKG_MGR="dnf"
    else
      PKG_MGR=""
    fi
    ;;
  *) PKG_MGR="" ;;
esac

# --- DEPENDENCY CHECKS ---

# kind
if [[ "$PKG_MGR" == "brew" ]]; then
  check_and_install "kind" "brew install kind" "https://kind.sigs.k8s.io/"
elif [[ "$PKG_MGR" == "apt" ]]; then
  check_and_install "kind" "sudo apt-get update && sudo apt-get install -y kind" "https://kind.sigs.k8s.io/"
else
  check_and_install "kind" "curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind" "https://kind.sigs.k8s.io/"
fi

# kubectl
if [[ "$PKG_MGR" == "brew" ]]; then
  check_and_install "kubectl" "brew install kubectl" "https://kubernetes.io/docs/tasks/tools/"
elif [[ "$PKG_MGR" == "apt" ]]; then
  check_and_install "kubectl" "sudo apt-get update && sudo apt-get install -y kubectl" "https://kubernetes.io/docs/tasks/tools/"
else
  check_and_install "kubectl" "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/" "https://kubernetes.io/docs/tasks/tools/"
fi

# helm
if [[ "$PKG_MGR" == "brew" ]]; then
  check_and_install "helm" "brew install helm" "https://helm.sh/docs/intro/install/"
elif [[ "$PKG_MGR" == "apt" ]]; then
  check_and_install "helm" "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add - && sudo apt-get install apt-transport-https --yes && echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list && sudo apt-get update && sudo apt-get install helm -y" "https://helm.sh/docs/intro/install/"
else
  check_and_install "helm" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" "https://helm.sh/docs/intro/install/"
fi

# k9s
if [[ "$PKG_MGR" == "brew" ]]; then
  check_and_install "k9s" "brew install derailed/k9s/k9s" "https://k9scli.io/"
elif [[ "$PKG_MGR" == "apt" ]]; then
  check_and_install "k9s" "sudo apt-get install -y snapd && sudo snap install k9s" "https://k9scli.io/"
else
  check_and_install "k9s" "curl -sS https://webinstall.dev/k9s | bash" "https://k9scli.io/"
fi

echo "All dependencies verified."

# ---- GEN3 SETUP -----

if kind get clusters | grep -q '^kind$'; then
  echo "Deleting existing Kind cluster..."
  kind delete cluster
else
  echo " No existing Kind cluster found."
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

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml


echo "Waiting for ingress-nginx controller pod to be created..."

# Timeout: 300 seconds (5 minutes)
timeout=$((SECONDS + 300))

# Wait until at least one controller pod exists or timeout
echo "Waiting for pod to appear..."
while ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller 2>/dev/null | grep -q "controller"; do
    sleep 1
    if (( SECONDS > timeout )); then
        echo -e "\nTimed out after 5 minutes waiting for ingress-nginx pod creation."
        exit 1
    fi
done

if kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s; then
    echo "condition met: ingress-nginx controller is ready!"
else
    echo "Timed out waiting for ingress-nginx controller to be ready."
    exit 1
fi

helm repo add gen3 https://helm.gen3.org
helm repo update

# --- INSTALL GEN3 ON HELM REPO ---
helm upgrade --install dev gen3/gen3 -f values_for_new_dict.yaml
#helm upgrade --install dev gen3/gen3 

echo "Gen3 setup complete"

echo "type 'k9s' in the terminal to see all nodes"
