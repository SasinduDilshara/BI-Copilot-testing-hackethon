import ballerina/log;
import ballerinax/confluent.cavroserdes;
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
