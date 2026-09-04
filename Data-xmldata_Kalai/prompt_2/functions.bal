import ballerina/data.xmldata;
import ballerina/file;
import ballerina/io;
import ballerina/log;

# Parses the raw patient XML payload into a Patient record.
#
# + xmlPayload - The raw XML string representing a patient record
# + return - The parsed Patient record, or an error if parsing fails
function parsePatientXml(string xmlPayload) returns Patient|error {
    Patient patient = check xmldata:parseString(xmlPayload);
    return patient;
}

# Validates an XML document string against an XSD schema string.
#
# xmldata:validate requires the schema to be supplied as a file path, so the given
# XSD content is written to a temporary file which is removed once validation completes.
#
# + xmlDocument - The XML document content to validate
# + xsdSchema - The XSD schema content to validate against
# + return - The schema validation result, or an error if the inputs could not be processed
function validateXmlAgainstSchema(string xmlDocument, string xsdSchema) returns SchemaValidationResult|error {
    xml xmlValue = check xml:fromString(xmlDocument);

    string tempSchemaPath = check file:createTemp(suffix = ".xsd");
    check io:fileWriteString(tempSchemaPath, xsdSchema);

    xmldata:Error? validationResult = xmldata:validate(xmlValue, tempSchemaPath);

    error? removeResult = file:remove(tempSchemaPath);
    if removeResult is error {
        log:printWarn("Failed to remove temporary schema file: " + tempSchemaPath, 'error = removeResult);
    }

    if validationResult is xmldata:Error {
        return {
            valid: false,
            validationErrors: [validationResult.message()]
        };
    }

    return {
        valid: true,
        validationErrors: []
    };
}

# Projects a patient XML document into a PatientSummary, extracting only the
# patient ID, full name, and birth date while ignoring contact and extension fields.
#
# + xmlPayload - The raw XML string representing a patient record
# + return - The projected PatientSummary, or an error if parsing fails
function projectPatientSummary(string xmlPayload) returns PatientSummary|error {
    xml xmlValue = check xml:fromString(xmlPayload);
    PatientProjection projection = check xmldata:parseAsType(xmlValue, {allowDataProjection: true});

    string fullName = projection.name.given.value + " " + projection.name.family.value;

    return {
        patientId: projection.id.value,
        fullName,
        birthDate: projection.birthDate.value
    };
}

# Rebuilds a canonical Patient record from a stored patient, for XML export.
#
# + storedPatient - The stored patient record
# + return - The reconstructed Patient record
function toPatient(StoredPatient storedPatient) returns Patient => {
    id: {value: storedPatient.patientId},
    name: {
        given: {value: storedPatient.firstName},
        family: {value: storedPatient.lastName}
    },
    birthDate: {value: storedPatient.birthDate},
    gender: {value: storedPatient.gender},
    bloodGroup: {value: storedPatient.bloodGroup},
    contact: {
        'type: storedPatient.contactType,
        relationship: storedPatient.contactRelationship,
        name: {value: storedPatient.contactName},
        phone: {value: storedPatient.contactPhone}
    }
};

# Retrieves a stored patient by ID from the in-memory store.
#
# + patientId - The patient ID to look up
# + return - The stored patient, or `()` if not found
isolated function getStoredPatient(string patientId) returns StoredPatient? {
    lock {
        StoredPatient? storedPatient = patientStore[patientId];
        return storedPatient.clone();
    }
}

# Parses a multiline XML batch payload, storing each successfully parsed patient
# and collecting the 1-based line numbers of lines that failed to parse.
#
# + batchPayload - The multiline string where each non-blank line is a patient XML document
# + return - The batch ingestion result summarizing successes and failures
function processBatch(string batchPayload) returns BatchIngestResult {
    string[] lines = re `\n`.split(batchPayload);
    int totalSubmitted = 0;
    int successCount = 0;
    int[] failedLines = [];

    foreach int index in 0 ..< lines.length() {
        string line = lines[index].trim();
        if line.length() == 0 {
            continue;
        }
        totalSubmitted += 1;
        int lineNumber = index + 1;

        Patient|error patient = parsePatientXml(line);
        if patient is error {
            log:printWarn("Failed to parse patient XML on line " + lineNumber.toString(), 'error = patient);
            failedLines.push(lineNumber);
            continue;
        }

        StoredPatient storedPatient = toStoredPatient(patient);
        _ = storePatient(storedPatient);
        successCount += 1;
    }

    return {
        totalSubmitted,
        successCount,
        failedCount: failedLines.length(),
        failedLines
    };
}

# Converts a parsed Patient record into a StoredPatient record.
#
# + patient - The parsed Patient record
# + return - The StoredPatient record derived from the parsed patient
function toStoredPatient(Patient patient) returns StoredPatient => {
    patientId: patient.id.value,
    firstName: patient.name.given.value,
    lastName: patient.name.family.value,
    birthDate: patient.birthDate.value,
    gender: patient.gender.value,
    bloodGroup: patient.bloodGroup.value,
    contactType: patient.contact.'type,
    contactRelationship: patient.contact.relationship,
    contactName: patient.contact.name.value,
    contactPhone: patient.contact.phone.value
};

# Stores the given patient in the in-memory store if not already present.
#
# + storedPatient - The patient record to store
# + return - "duplicate" if the patient already existed, "ingested" otherwise
isolated function storePatient(StoredPatient storedPatient) returns string {
    lock {
        if patientStore.hasKey(storedPatient.patientId) {
            return "duplicate";
        }
        patientStore[storedPatient.patientId] = storedPatient.clone();
        return "ingested";
    }
}
