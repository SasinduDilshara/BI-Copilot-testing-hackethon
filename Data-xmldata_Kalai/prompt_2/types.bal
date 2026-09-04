import ballerina/data.xmldata;

# Represents the given/family name attribute value holder.
public type NamePart record {|
    @xmldata:Attribute
    string value;
|};

# Represents the patient's name element with given and family sub-elements.
public type PatientName record {|
    NamePart given;
    NamePart family;
|};

# Represents a simple attribute-valued element (id, birthDate, gender).
public type AttributeValue record {|
    @xmldata:Attribute
    string value;
|};

# Represents the blood group extension element with a value attribute.
public type BloodGroup record {|
    @xmldata:Attribute
    string value;
|};

# Represents the emergency contact details of a patient.
public type ContactName record {|
    @xmldata:Attribute
    string value;
|};

# Represents the contact phone details of a patient.
public type ContactPhone record {|
    @xmldata:Attribute
    string value;
|};

# Represents the contact element of a patient record.
public type PatientContact record {|
    @xmldata:Attribute
    string 'type;
    @xmldata:Attribute
    string relationship;
    ContactName name;
    ContactPhone phone;
|};

# Represents the canonical Patient XML record mapped from the HL7 hospital namespace.
@xmldata:Namespace {
    uri: "http://hl7.hospital.com/fhir"
}
public type Patient record {|
    AttributeValue id;
    PatientName name;
    @xmldata:Name {value: "birthDate"}
    AttributeValue birthDate;
    AttributeValue gender;
    @xmldata:Name {value: "bloodGroup"}
    @xmldata:Namespace {
        prefix: "ext",
        uri: "http://hl7.hospital.com/extensions"
    }
    BloodGroup bloodGroup;
    PatientContact contact;
|};

# Represents a stored patient record in the in-memory store.
public type StoredPatient record {|
    string patientId;
    string firstName;
    string lastName;
    string birthDate;
    string gender;
    string bloodGroup;
    string contactType;
    string contactRelationship;
    string contactName;
    string contactPhone;
|};

# Represents the response returned after ingesting a patient record.
public type PatientIngestResponse record {|
    string patientId;
    string status;
    string normalizedName;
|};

# Represents the outcome of a batch patient ingestion request.
public type BatchIngestResult record {|
    int totalSubmitted;
    int successCount;
    int failedCount;
    int[] failedLines;
|};

# Represents the request body for XML schema validation.
public type SchemaValidationRequest record {|
    string xmlDocument;
    string xsdSchema;
|};

# Represents the outcome of an XML schema validation request.
public type SchemaValidationResult record {|
    boolean valid;
    string[] validationErrors;
|};

# Represents a closed projection of the Patient XML used to extract only the
# id, name, and birthDate elements via xmldata:parseAsType, ignoring contact
# and extension fields.
@xmldata:Namespace {
    uri: "http://hl7.hospital.com/fhir"
}
type PatientProjection record {|
    AttributeValue id;
    PatientName name;
    @xmldata:Name {value: "birthDate"}
    AttributeValue birthDate;
|};

# Represents a projected summary of a patient, excluding contact and extension fields.
public type PatientSummary record {|
    string patientId;
    string fullName;
    string birthDate;
|};
