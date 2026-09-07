import ballerina/log;

public function main() returns error? {
    CustomerProfile customerProfile = {
        customerId: "CUST-1001",
        email: "jane.doe@example.com",
        address: {
            street: "123 Main St",
            city: "Springfield",
            postalCode: "12345",
            country: "USA"
        },
        loyaltyProgramIds: ["LP-100", "LP-200"],
        consentFlags: {
            "marketingEmails": true,
            "smsNotifications": false
        },
        customerTier: GOLD
    };

    ValidationError|SerializationError|PublishError? publishResult = publishCustomerProfile(customerProfile);
    if publishResult is ValidationError {
        log:printError("customer profile validation failed", publishResult);
        return publishResult;
    }
    if publishResult is SerializationError {
        log:printError("customer profile serialization failed", publishResult);
        return publishResult;
    }
    if publishResult is PublishError {
        log:printError("customer profile publish failed", publishResult);
        return publishResult;
    }

    CustomerProfile[]|ConsumeError|DeserializationError consumeResult = consumeCustomerProfiles(10);
    if consumeResult is ConsumeError {
        log:printError("customer profile consume failed", consumeResult);
        return consumeResult;
    }
    if consumeResult is DeserializationError {
        log:printError("customer profile deserialization failed", consumeResult);
        return consumeResult;
    }

    foreach CustomerProfile receivedProfile in consumeResult {
        log:printInfo("received customer profile", customerProfile = receivedProfile);
    }
}
