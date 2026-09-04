import ballerina/data.xmldata;

# Parses the raw patient XML payload into a Patient record.
#
# + xmlPayload - The raw XML string representing a patient record
# + return - The parsed Patient record, or an error if parsing fails
function parsePatientXml(string xmlPayload) returns Patient|error {
    Patient patient = check xmldata:parseString(xmlPayload);
    return patient;
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
