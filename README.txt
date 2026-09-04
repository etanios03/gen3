To Visualize data: 
https://github.com/AustralianBioCommons/gen3schemadev/blob/main/docs/gen3schemadev/quickstart.md


command: gen3schemadev visualise -i gen3_data_dictionary/gen3_bundled_schema.json 

**what is currently in the visualizer is not the real data model**


after running, do: kind delete cluster to restart and refresh


if everything is ready except the portal deployment is running and keeps backing off, do: 
kubectl delete pod portal-deployment-5d8896857d-xkrm5 (with the pod name) so that it forces a restart


how to check memory limits: kubectl describe nodes | grep -A 5 "Allocated resources"

to get logs: kubectl logs 


api key for gen3-client:
https://docs.gen3.org/gen3-resources/tools/data-client/#configure-a-profile-with-credentials
/Applications/gen3-client configure --profile=demo --cred=~/Desktop/credentials.json --apiendpoint=https://localhost
/Applications/gen3-client auth --profile=demo


uploading data with data client:
https://docs.gen3.org/gen3-resources/tools/data-client/#uploading-data-with-the-data-client


how to make the program and project nodes:
https://docs.gen3.org/gen3-resources/operator-guide/submit-structured-data/#order-of-node-submission
** to check if succeeded, look at sheepdog logs


how to delete: kind delete cluster


how to add minio for data bucket storage:
https://github.com/minio/minio/blob/master/helm/minio/README.md


activate uv venv: go to desktop folder, then do source .venv/bin/activate


---- MANUAL JOB RUNNING FOR USERSYNC ----
*user sync node runs every 30 minutes, but we need it to sync so that we have sheepdog access 
before the gen3_sdk.py runs and adds the program and project nodes

run these commands: 
kubectl get cronjob -n gen3 (to see the scheduled jobs)
kubectl create job --from=cronjob/usersync manual-usersync-1 -n gen3 (for a manual usersync job to get the user.yaml)