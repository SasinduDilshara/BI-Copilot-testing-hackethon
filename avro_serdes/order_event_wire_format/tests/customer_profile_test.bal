import ballerina/avro;
import ballerina/test;

final avro:Schema customerProfileSchema = check new (customerProfileAvroSchema);

@test:Config {}
function testRoundTripWithEmailPresent() returns error? {
    CustomerProfile customerProfile = {
        customerId: "CUST-2001",
        email: "alice@example.com",
        address: {
            street: "1 Elm Street",
            city: "Metropolis",
            postalCode: "54321",
            country: "USA"
        },
        loyaltyProgramIds: ["LP-100", "LP-200"],
        consentFlags: {
            "marketingEmails": true,
            "smsNotifications": false
        },
        customerTier: GOLD
    };

    byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
    CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

    test:assertEquals(deserialized, customerProfile, msg = "round-trip with email present should preserve all fields");
}

@test:Config {}
function testRoundTripWithNullEmail() returns error? {
    CustomerProfile customerProfile = {
        customerId: "CUST-2002",
        email: (),
        address: {
            street: "2 Oak Avenue",
            city: "Gotham",
            postalCode: "11111",
            country: "USA"
        },
        loyaltyProgramIds: [],
        consentFlags: {},
        customerTier: BRONZE
    };

    byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
    CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

    test:assertEquals(deserialized.email, (), msg = "nullable email should round-trip as null");
    test:assertEquals(deserialized, customerProfile, msg = "round-trip with null email should preserve all fields");
}

@test:Config {}
function testRoundTripNestedAddress() returns error? {
    Address address = {
        street: "742 Evergreen Terrace",
        city: "Springfield",
        postalCode: "99999",
        country: "USA"
    };
    CustomerProfile customerProfile = {
        customerId: "CUST-2003",
        email: "bob@example.com",
        address,
        loyaltyProgramIds: ["LP-300"],
        consentFlags: {"marketingEmails": true},
        customerTier: SILVER
    };

    byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
    CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

    test:assertEquals(deserialized.address, address, msg = "nested address record should round-trip correctly");
}

@test:Config {}
function testRoundTripLoyaltyProgramIdsArray() returns error? {
    string[] loyaltyProgramIds = ["LP-100", "LP-200", "LP-300", "LP-400"];
    CustomerProfile customerProfile = {
        customerId: "CUST-2004",
        email: "carol@example.com",
        address: {
            street: "5 Maple Drive",
            city: "Star City",
            postalCode: "22222",
            country: "USA"
        },
        loyaltyProgramIds,
        consentFlags: {"smsNotifications": true},
        customerTier: PLATINUM
    };

    byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
    CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

    test:assertEquals(deserialized.loyaltyProgramIds, loyaltyProgramIds,
            msg = "loyalty program ids array should round-trip correctly");
}

@test:Config {}
function testRoundTripConsentFlagsMap() returns error? {
    map<boolean> consentFlags = {
        "marketingEmails": true,
        "smsNotifications": false,
        "dataSharing": true,
        "profiling": false
    };
    CustomerProfile customerProfile = {
        customerId: "CUST-2005",
        email: "dave@example.com",
        address: {
            street: "9 Birch Lane",
            city: "Central City",
            postalCode: "33333",
            country: "USA"
        },
        loyaltyProgramIds: ["LP-500"],
        consentFlags,
        customerTier: GOLD
    };

    byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
    CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

    test:assertEquals(deserialized.consentFlags, consentFlags, msg = "consent flags map should round-trip correctly");
}

@test:Config {}
function testRoundTripAllCustomerTiers() returns error? {
    CustomerTier[] tiers = [BRONZE, SILVER, GOLD, PLATINUM];
    foreach CustomerTier tier in tiers {
        CustomerProfile customerProfile = {
            customerId: "CUST-2006",
            email: "eve@example.com",
            address: {
                street: "10 Cedar Court",
                city: "Coast City",
                postalCode: "44444",
                country: "USA"
            },
            loyaltyProgramIds: ["LP-600"],
            consentFlags: {"marketingEmails": false},
            customerTier: tier
        };

        byte[] serialized = check customerProfileSchema.toAvro(customerProfile);
        CustomerProfile deserialized = check customerProfileSchema.fromAvro(serialized);

        test:assertEquals(deserialized.customerTier, tier, msg = "customerTier enum value " + tier + " should round-trip correctly");
    }
}

@test:Config {}
function testValidateCustomerProfileFailsOnBlankCustomerId() {
    CustomerProfile customerProfile = {
        customerId: "",
        email: (),
        address: {
            street: "1 Elm Street",
            city: "Metropolis",
            postalCode: "54321",
            country: "USA"
        },
        loyaltyProgramIds: [],
        consentFlags: {},
        customerTier: BRONZE
    };

    ValidationError? validationError = validateCustomerProfile(customerProfile);
    test:assertTrue(validationError is ValidationError, msg = "expected a ValidationError for blank customerId");
}

@test:Config {}
function testValidateCustomerProfileFailsOnBlankAddressField() {
    CustomerProfile customerProfile = {
        customerId: "CUST-3001",
        email: (),
        address: {
            street: "",
            city: "Metropolis",
            postalCode: "54321",
            country: "USA"
        },
        loyaltyProgramIds: [],
        consentFlags: {},
        customerTier: BRONZE
    };

    ValidationError? validationError = validateCustomerProfile(customerProfile);
    test:assertTrue(validationError is ValidationError, msg = "expected a ValidationError for blank address street");
}

@test:Config {}
function testValidateCustomerProfilePassesWithValidData() returns error? {
    CustomerProfile customerProfile = {
        customerId: "CUST-3002",
        email: (),
        address: {
            street: "1 Elm Street",
            city: "Metropolis",
            postalCode: "54321",
            country: "USA"
        },
        loyaltyProgramIds: [],
        consentFlags: {},
        customerTier: BRONZE
    };

    ValidationError? validationError = validateCustomerProfile(customerProfile);
    test:assertEquals(validationError, (), msg = "expected no validation error for a valid customer profile");
}

@test:Config {}
function testRoundTripFailsOnMalformedAvroBytes() {
    byte[] invalidBytes = [1, 2, 3, 4, 5];
    CustomerProfile|error result = customerProfileSchema.fromAvro(invalidBytes);
    test:assertTrue(result is error, msg = "expected an error when deserializing malformed avro bytes");
}
