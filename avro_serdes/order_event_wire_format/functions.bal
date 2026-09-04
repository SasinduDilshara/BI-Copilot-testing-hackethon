import ballerina/avro;
import ballerina/log;
import ballerina/time;
import ballerinax/confluent.cavroserdes;
import ballerinax/confluent.cregistry;
import ballerinax/kafka;

# Validates the required business fields of a `CustomerProfile` before serialization.
#
# + customerProfile - The customer profile to validate
# + return - A `ValidationError` if a required field is missing or invalid, `()` otherwise
public function validateCustomerProfile(CustomerProfile customerProfile) returns ValidationError? {
    if customerProfile.customerId.trim().length() == 0 {
        return error ValidationError("customerId is required and cannot be blank");
    }

    Address address = customerProfile.address;
    if address.street.trim().length() == 0 {
        return error ValidationError("address.street is required and cannot be blank");
    }
    if address.city.trim().length() == 0 {
        return error ValidationError("address.city is required and cannot be blank");
    }
    if address.postalCode.trim().length() == 0 {
        return error ValidationError("address.postalCode is required and cannot be blank");
    }
    if address.country.trim().length() == 0 {
        return error ValidationError("address.country is required and cannot be blank");
    }

    string? email = customerProfile.email;
    if email is string && email.trim().length() == 0 {
        return error ValidationError("email cannot be blank when provided");
    }

    return;
}

# Validates and serializes a `CustomerProfile` into Avro bytes registered under the
# `customer-profile-value` subject.
#
# + customerProfile - The customer profile to serialize
# + return - The serialized bytes, a `ValidationError`, or a `SerializationError`
public function serializeCustomerProfile(CustomerProfile customerProfile) returns byte[]|ValidationError|SerializationError {
    check validateCustomerProfile(customerProfile);

    byte[]|cavroserdes:Error serialized = cavroserdes:serialize(schemaRegistryClient, customerProfileAvroSchema,
            customerProfile, customerProfileValueSubject);
    if serialized is cavroserdes:Error {
        return error SerializationError("failed to serialize customer profile", serialized);
    }
    return serialized;
}

# Publishes the given `CustomerProfile` to the configured Kafka topic after validating and
# Avro serializing it.
#
# + customerProfile - The customer profile to publish
# + return - A `ValidationError`, `SerializationError`, or `PublishError` if the operation fails, `()` otherwise
public function publishCustomerProfile(CustomerProfile customerProfile) returns ValidationError|SerializationError|PublishError? {
    byte[] serializedValue = check serializeCustomerProfile(customerProfile);

    kafka:Error? sendResult = customerProfileProducer->send({
        topic: kafkaTopic,
        key: customerProfile.customerId.toBytes(),
        value: serializedValue
    });
    if sendResult is kafka:Error {
        return error PublishError("failed to publish customer profile to kafka", sendResult);
    }
    log:printInfo("published customer profile", customerId = customerProfile.customerId);
    return;
}

# Deserializes Avro encoded bytes retrieved from Kafka into a `CustomerProfile`.
#
# + value - The Avro encoded bytes consumed from Kafka
# + return - The deserialized `CustomerProfile` or a `DeserializationError`
public function deserializeCustomerProfile(byte[] value) returns CustomerProfile|DeserializationError {
    CustomerProfile|cavroserdes:Error deserialized = cavroserdes:deserialize(schemaRegistryClient, value);
    if deserialized is cavroserdes:Error {
        return error DeserializationError("failed to deserialize customer profile", deserialized);
    }
    return deserialized;
}

# Polls the configured Kafka topic for new customer profile records and deserializes each one.
#
# + timeoutSeconds - The maximum time to wait for records to be polled
# + return - An array of deserialized `CustomerProfile` records, a `ConsumeError`, or a `DeserializationError`
public function consumeCustomerProfiles(decimal timeoutSeconds) returns CustomerProfile[]|ConsumeError|DeserializationError {
    byte[][]|kafka:Error polledValues = customerProfileConsumer->pollPayload(timeoutSeconds);
    if polledValues is kafka:Error {
        return error ConsumeError("failed to consume customer profiles from kafka", polledValues);
    }

    CustomerProfile[] customerProfiles = [];
    foreach byte[] polledValue in polledValues {
        CustomerProfile customerProfile = check deserializeCustomerProfile(polledValue);
        customerProfiles.push(customerProfile);
    }
    return customerProfiles;
}

# Represents a single field of a parsed Avro record schema, used for compatibility comparison.
#
# + name - The field name
# + fieldType - The normalized `string` form of the field's Avro type
# + hasDefault - Whether the field declares a default value
type AvroSchemaField record {|
    string name;
    string fieldType;
    boolean hasDefault;
|};

# Parses the fields of an Avro record schema string into a map keyed by field name.
#
# + schema - The Avro record schema in `string` format
# + return - A map of field name to `AvroSchemaField`, or an error if the schema cannot be parsed
function parseAvroRecordFields(string schema) returns map<AvroSchemaField>|error {
    json schemaJson = check schema.fromJsonString();
    record {|json[] fields; json...;|} parsedSchema = check schemaJson.cloneWithType();

    map<AvroSchemaField> fieldsByName = {};
    foreach json fieldJson in parsedSchema.fields {
        record {|string name; json 'type; json...;|} parsedField = check fieldJson.cloneWithType();
        AvroSchemaField schemaField = {
            name: parsedField.name,
            fieldType: parsedField.'type.toJsonString(),
            hasDefault: parsedField.hasKey("default")
        };
        fieldsByName[parsedField.name] = schemaField;
    }
    return fieldsByName;
}

# Checks whether a candidate `CustomerProfile` Avro schema is backward compatible with the active schema.
#
# A candidate is considered compatible when:
# - Every field present in the active schema is still present in the candidate with the same type, and
# - Every field newly introduced by the candidate declares a default value.
#
# + activeSchema - The currently active Avro schema
# + candidateSchema - The candidate Avro schema being evaluated for promotion
# + return - `()` if compatible, or a `string` describing the first incompatibility found
function checkAvroSchemaCompatibility(string activeSchema, string candidateSchema) returns string?|error {
    map<AvroSchemaField> activeFields = check parseAvroRecordFields(activeSchema);
    map<AvroSchemaField> candidateFields = check parseAvroRecordFields(candidateSchema);

    foreach AvroSchemaField activeField in activeFields {
        AvroSchemaField? candidateField = candidateFields[activeField.name];
        if candidateField is () {
            return string `field '${activeField.name}' present in the active schema is missing in the candidate schema`;
        }
        if candidateField.fieldType != activeField.fieldType {
            return string `field '${activeField.name}' changed type from ${activeField.fieldType} to ${candidateField.fieldType}`;
        }
    }

    foreach AvroSchemaField candidateField in candidateFields {
        boolean isNewField = !activeFields.hasKey(candidateField.name);
        if isNewField && !candidateField.hasDefault {
            return string `newly added field '${candidateField.name}' does not declare a default value`;
        }
    }

    return;
}

# Registers a candidate `CustomerProfile` Avro schema under the `customer-profile-value` subject only when it is
# compatible with the currently active schema, recording an audit decision either way. Incompatible candidates are
# rejected without registering the schema or changing the active version.
#
# + candidateSchema - The candidate Avro schema to evaluate for promotion
# + return - The recorded `PromotionDecision`, or a `PromotionError` if the operation fails unexpectedly
public function promoteCustomerProfileSchema(string candidateSchema) returns PromotionDecision|PromotionError {
    _ = check validateAvroSchemaParses(candidateSchema);

    string activeSchema = getActiveCustomerProfileSchema();

    string?|error compatibilityResult = checkAvroSchemaCompatibility(activeSchema, candidateSchema);
    if compatibilityResult is error {
        return error PromotionError("failed to evaluate schema compatibility", compatibilityResult);
    }

    string decidedAt = time:utcToString(time:utcNow());

    if compatibilityResult is string {
        PromotionDecision decision = {
            subject: customerProfileValueSubject,
            outcome: "REJECTED",
            reason: compatibilityResult,
            schemaId: (),
            candidateSchema,
            decidedAt
        };
        recordPromotionDecision(decision);
        log:printWarn("rejected incompatible customer profile schema candidate", reason = compatibilityResult);
        return decision;
    }

    int|cregistry:Error registerResult = schemaRegistryClient->register(customerProfileValueSubject, candidateSchema);
    if registerResult is cregistry:Error {
        return error PromotionError("failed to register candidate schema with schema registry", registerResult);
    }

    PromotionDecision decision = {
        subject: customerProfileValueSubject,
        outcome: "APPROVED",
        reason: "candidate schema is compatible with the active schema",
        schemaId: registerResult,
        candidateSchema,
        decidedAt
    };
    setActiveCustomerProfileSchema(candidateSchema);
    recordPromotionDecision(decision);
    log:printInfo("promoted customer profile schema", schemaId = registerResult);
    return decision;
}

# Validates that the given Avro schema `string` parses as a valid Avro schema.
#
# + schema - The Avro schema to validate
# + return - `true` if valid, or a `PromotionError` if the schema is invalid
function validateAvroSchemaParses(string schema) returns boolean|PromotionError {
    avro:Schema|error parsed = new (schema);
    if parsed is error {
        return error PromotionError("candidate schema is not a valid Avro schema", parsed);
    }
    return true;
}

# Returns the currently active `CustomerProfile` Avro schema.
#
# + return - The active Avro schema `string`
public isolated function getActiveCustomerProfileSchema() returns string {
    lock {
        return activeCustomerProfileSchema;
    }
}

# Updates the currently active `CustomerProfile` Avro schema.
#
# + newSchema - The new schema to set as active
isolated function setActiveCustomerProfileSchema(string newSchema) {
    lock {
        activeCustomerProfileSchema = newSchema;
    }
}

# Appends a promotion decision to the in-memory audit log.
#
# + decision - The decision to record
isolated function recordPromotionDecision(PromotionDecision decision) {
    lock {
        promotionAuditLog.push(decision.clone());
    }
}

# Returns a snapshot of all recorded schema promotion decisions.
#
# + return - An array of recorded `PromotionDecision` records
public isolated function getPromotionAuditLog() returns PromotionDecision[] {
    lock {
        return promotionAuditLog.clone();
    }
}
