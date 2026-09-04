import truststore
truststore.inject_into_ssl()  

from gen3.auth import Gen3Auth

auth = Gen3Auth("https://localhost", refresh_file="sept_3_credentials.json")

# sept 2: this does not yet work, see the readme for minio installation
from gen3.file import Gen3File 

file_client = Gen3File(auth)

record = file_client.upload_file(
    file_name="test.dcm"
)
print(record)