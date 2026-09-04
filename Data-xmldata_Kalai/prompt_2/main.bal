import ballerina/data.xmldata;
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

    # Exports a stored patient as an XML document.
    #
    # + patientId - The ID of the patient to export
    # + return - The patient XML document, a not-found response, or an internal error
    resource function get [string patientId]/export() returns xml|http:NotFound|http:InternalServerError {
        StoredPatient? storedPatient = getStoredPatient(patientId);
        if storedPatient is () {
            return <http:NotFound>{
                body: {
                    message: "Patient not found: " + patientId
                }
            };
        }

        Patient patient = toPatient(storedPatient);
        xml|xmldata:Error patientXml = xmldata:toXml(patient);
        if patientXml is xmldata:Error {
            return <http:InternalServerError>{
                body: {
                    message: "Failed to serialize patient to XML: " + patientXml.message()
                }
            };
        }

        return patientXml;
    }

    # Ingests multiple patient records supplied as a multiline XML string body,
    # where each non-blank line is a separate patient XML document.
    #
    # + payload - The multiline string body containing one patient XML document per line
    # + return - The batch ingestion result summarizing successes and failures
    resource function post batch(@http:Payload string payload) returns BatchIngestResult {
        return processBatch(payload);
    }

    # Validates an XML document against an XSD schema, both supplied in the JSON request body.
    #
    # + request - The XML document and XSD schema to validate
    # + return - The schema validation result, or a bad request if the inputs could not be processed
    resource function post validate\-schema(@http:Payload SchemaValidationRequest request) returns SchemaValidationResult|http:BadRequest {
        SchemaValidationResult|error result = validateXmlAgainstSchema(request.xmlDocument, request.xsdSchema);
        if result is error {
            return <http:BadRequest>{
                body: {
                    message: "Invalid XML document or XSD schema: " + result.message()
                }
            };
        }
        return result;
    }

    # Transforms a full patient XML document into a PatientSummary, projecting
    # only the patient ID, full name, and birth date.
    #
    # + payload - The XML payload representing a patient record
    # + return - The projected patient summary, or a bad request on invalid XML
    resource function post transform(@http:Payload xml payload) returns PatientSummary|http:BadRequest {
        string xmlPayload = payload.toString();
        PatientSummary|error summary = projectPatientSummary(xmlPayload);
        if summary is error {
            return <http:BadRequest>{
                body: {
                    message: "Invalid patient XML payload: " + summary.message()
                }
            };
        }
        return summary;
    }
}
