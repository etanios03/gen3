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