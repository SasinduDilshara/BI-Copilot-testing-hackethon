import ballerina/http;

service /patients on new http:Listener(9090) {

    # Ingests a patient record supplied as an XML body.
    #
    # + payload - The XML payload representing a patient record
    # + return - The ingestion response, a bad request on invalid XML, or an internal error
    resource function post ingest(@http:Payload xml payload) returns PatientIngestResponse|http:BadRequest|http:InternalServerError {
        string xmlPayload = payload.toString();
        Patient|error patient = parsePatientXml(xmlPayload);
        if patient is error {
            return <http:BadRequest>{
                body: {
                    message: "Invalid patient XML payload: " + patient.message()
                }
            };
        }

        StoredPatient storedPatient = toStoredPatient(patient);
        string status = storePatient(storedPatient);
        string normalizedName = storedPatient.firstName + " " + storedPatient.lastName;

        return {
            patientId: storedPatient.patientId,
            status: status,
            normalizedName: normalizedName
        };
    }
}
