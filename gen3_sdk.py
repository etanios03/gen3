import truststore
# this is because we need the root CA of the mac in order to trust the localhost CA
truststore.inject_into_ssl()  

from gen3.auth import Gen3Auth

auth = Gen3Auth("https://localhost", refresh_file="sept_3_credentials.json")

# this works for creating a program and project, have not yet tested if putting in metadata works
from gen3.submission import Gen3Submission

sub = Gen3Submission("https://localhost", auth)

program_json = {
    "type": "program",
    "name": "program1",
    "dbgap_accession_number": "program-1"
}
sub.create_program(program_json)

project_json = {
    "type": "project",
    "code": "project1",
    "dbgap_accession_number": "phs001",
    "name": "project1"
}
sub.create_project("program1", project_json)

print(sub.get_programs())
print(sub.get_projects("program1"))

dictionary = sub.get_dictionary_all()

