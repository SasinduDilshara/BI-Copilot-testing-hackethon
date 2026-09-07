import ballerina/test;

final string compatibleCandidateSchemaWithNewDefaultedField = string `
{
    "type": "record",
    "name": "CustomerProfile",
    "namespace": "customer.profile.avro",
    "fields": [
        {"name": "customerId", "type": "string"},
        {"name": "email", "type": ["null", "string"], "default": null},
        {"name": "address", "type": {
            "type": "record",
            "name": "Address",
            "fields": [
                {"name": "street", "type": "string"},
                {"name": "city", "type": "string"},
                {"name": "postalCode", "type": "string"},
                {"name": "country", "type": "string"}
            ]
        }},
        {"name": "loyaltyProgramIds", "type": {"type": "array", "items": "string"}},
        {"name": "consentFlags", "type": {"type": "map", "values": "boolean"}},
        {"name": "customerTier", "type": "string"},
        {"name": "preferredLanguage", "type": "string", "default": "en"}
    ]
}`;

final string incompatibleCandidateSchemaMissingRequiredField = string `
{
    "type": "record",
    "name": "CustomerProfile",
    "namespace": "customer.profile.avro",
    "fields": [
        {"name": "customerId", "type": "string"},
        {"name": "address", "type": {
            "type": "record",
            "name": "Address",
            "fields": [
                {"name": "street", "type": "string"},
                {"name": "city", "type": "string"},
                {"name": "postalCode", "type": "string"},
                {"name": "country", "type": "string"}
            ]
        }},
        {"name": "loyaltyProgramIds", "type": {"type": "array", "items": "string"}},
        {"name": "consentFlags", "type": {"type": "map", "values": "boolean"}},
        {"name": "customerTier", "type": "string"}
    ]
}`;

final string incompatibleCandidateSchemaWithChangedFieldType = string `
{
    "type": "record",
    "name": "CustomerProfile",
    "namespace": "customer.profile.avro",
    "fields": [
        {"name": "customerId", "type": "string"},
        {"name": "email", "type": ["null", "string"], "default": null},
        {"name": "address", "type": {
            "type": "record",
            "name": "Address",
            "fields": [
                {"name": "street", "type": "string"},
                {"name": "city", "type": "string"},
                {"name": "postalCode", "type": "string"},
                {"name": "country", "type": "string"}
            ]
        }},
        {"name": "loyaltyProgramIds", "type": {"type": "array", "items": "string"}},
        {"name": "consentFlags", "type": {"type": "map", "values": "boolean"}},
        {"name": "customerTier", "type": "int"}
    ]
}`;

final string incompatibleCandidateSchemaWithNewFieldWithoutDefault = string `
{
    "type": "record",
    "name": "CustomerProfile",
    "namespace": "customer.profile.avro",
    "fields": [
        {"name": "customerId", "type": "string"},
        {"name": "email", "type": ["null", "string"], "default": null},
        {"name": "address", "type": {
            "type": "record",
            "name": "Address",
            "fields": [
                {"name": "street", "type": "string"},
                {"name": "city", "type": "string"},
                {"name": "postalCode", "type": "string"},
                {"name": "country", "type": "string"}
            ]
        }},
        {"name": "loyaltyProgramIds", "type": {"type": "array", "items": "string"}},
        {"name": "consentFlags", "type": {"type": "map", "values": "boolean"}},
        {"name": "customerTier", "type": "string"},
        {"name": "membershipNumber", "type": "string"}
    ]
}`;

@test:Config {}
function testCheckCompatibilityAllowsNewFieldWithDefault() returns error? {
    string? incompatibilityReason = check checkAvroSchemaCompatibility(customerProfileAvroSchema,
            compatibleCandidateSchemaWithNewDefaultedField);
    test:assertEquals(incompatibilityReason, (), msg = "a new field with a default should be compatible");
}

@test:Config {}
function testCheckCompatibilityRejectsMissingRequiredField() returns error? {
    string? incompatibilityReason = check checkAvroSchemaCompatibility(customerProfileAvroSchema,
            incompatibleCandidateSchemaMissingRequiredField);
    test:assertTrue(incompatibilityReason is string, msg = "removing a required field should be incompatible");
    string reason = <string>incompatibilityReason;
    test:assertTrue(reason.includes("email"), msg = "incompatibility reason should mention the missing field");
}

@test:Config {}
function testCheckCompatibilityRejectsChangedFieldType() returns error? {
    string? incompatibilityReason = check checkAvroSchemaCompatibility(customerProfileAvroSchema,
            incompatibleCandidateSchemaWithChangedFieldType);
    test:assertTrue(incompatibilityReason is string, msg = "changing a field's type should be incompatible");
    string reason = <string>incompatibilityReason;
    test:assertTrue(reason.includes("customerTier"), msg = "incompatibility reason should mention the changed field");
}

@test:Config {}
function testCheckCompatibilityRejectsNewFieldWithoutDefault() returns error? {
    string? incompatibilityReason = check checkAvroSchemaCompatibility(customerProfileAvroSchema,
            incompatibleCandidateSchemaWithNewFieldWithoutDefault);
    test:assertTrue(incompatibilityReason is string, msg = "a new field without a default should be incompatible");
    string reason = <string>incompatibilityReason;
    test:assertTrue(reason.includes("membershipNumber"), msg = "incompatibility reason should mention the new field");
}

@test:Config {}
function testValidateFlagsIncompatibleCandidateWithoutChangingActiveVersion() returns error? {
    string activeSchemaBeforeValidation = getActiveCustomerProfileSchema();
    int validationHistorySizeBeforeValidation = getCompatibilityValidationHistory().length();

    CompatibilityValidationRecord|ValidationOperationError result =
        validateCustomerProfileSchemaCompatibility(incompatibleCandidateSchemaMissingRequiredField);

    if result is ValidationOperationError {
        test:assertFail(msg = "an incompatible candidate should still produce a decision, not an error");
    }
    CompatibilityValidationRecord validationRecord = result;
    test:assertEquals(validationRecord.outcome, "INCOMPATIBLE", msg = "an incompatible candidate should be flagged as incompatible");
    test:assertEquals(validationRecord.subject, customerProfileValueSubject, msg = "the decision should be recorded against the customer-profile-value subject");

    string activeSchemaAfterValidation = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaAfterValidation, activeSchemaBeforeValidation,
            msg = "the active schema must remain unchanged after an incompatible candidate is validated");

    CompatibilityValidationRecord[] validationHistoryAfterValidation = getCompatibilityValidationHistory();
    test:assertEquals(validationHistoryAfterValidation.length(), validationHistorySizeBeforeValidation + 1,
            msg = "a validation decision should be appended to the validation history");
    CompatibilityValidationRecord lastValidationRecord =
        validationHistoryAfterValidation[validationHistoryAfterValidation.length() - 1];
    test:assertEquals(lastValidationRecord.outcome, "INCOMPATIBLE", msg = "the recorded validation decision should be incompatible");
    test:assertEquals(lastValidationRecord.candidateSchema, incompatibleCandidateSchemaMissingRequiredField,
            msg = "the recorded validation decision should reference the evaluated candidate schema");
}

@test:Config {}
function testValidateFlagsCandidateWithChangedFieldTypeWithoutChangingActiveVersion() returns error? {
    string activeSchemaBeforeValidation = getActiveCustomerProfileSchema();

    CompatibilityValidationRecord|ValidationOperationError result =
        validateCustomerProfileSchemaCompatibility(incompatibleCandidateSchemaWithChangedFieldType);

    if result is ValidationOperationError {
        test:assertFail(msg = "an incompatible candidate should still produce a decision, not an error");
    }
    CompatibilityValidationRecord validationRecord = result;
    test:assertEquals(validationRecord.outcome, "INCOMPATIBLE",
            msg = "a candidate with an incompatible type change should be flagged as incompatible");

    string activeSchemaAfterValidation = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaAfterValidation, activeSchemaBeforeValidation,
            msg = "the active schema must remain unchanged after validation");
}

@test:Config {}
function testValidateNeverMutatesActiveSchemaEvenWhenCandidateIsCompatible() returns error? {
    string activeSchemaBeforeValidation = getActiveCustomerProfileSchema();
    int validationHistorySizeBeforeValidation = getCompatibilityValidationHistory().length();

    CompatibilityValidationRecord|ValidationOperationError result =
        validateCustomerProfileSchemaCompatibility(compatibleCandidateSchemaWithNewDefaultedField);

    if result is ValidationOperationError {
        test:assertFail(msg = "a compatible candidate should still produce a decision, not an error");
    }
    CompatibilityValidationRecord validationRecord = result;
    test:assertEquals(validationRecord.outcome, "COMPATIBLE", msg = "a compatible candidate should be flagged as compatible");

    // This is the key proof: even though the candidate is compatible, validation is read-only and must
    // never register the schema or promote it to become the active schema.
    string activeSchemaAfterValidation = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaAfterValidation, activeSchemaBeforeValidation,
            msg = "the active schema must remain unchanged even when the candidate is found compatible");
    test:assertNotEquals(activeSchemaAfterValidation, compatibleCandidateSchemaWithNewDefaultedField,
            msg = "the candidate schema must never become the active schema as a result of validation");

    CompatibilityValidationRecord[] validationHistoryAfterValidation = getCompatibilityValidationHistory();
    test:assertEquals(validationHistoryAfterValidation.length(), validationHistorySizeBeforeValidation + 1,
            msg = "a compatible decision should still be appended to the validation history");
    CompatibilityValidationRecord lastValidationRecord =
        validationHistoryAfterValidation[validationHistoryAfterValidation.length() - 1];
    test:assertEquals(lastValidationRecord.outcome, "COMPATIBLE", msg = "the recorded validation decision should be compatible");
    test:assertEquals(lastValidationRecord.candidateSchema, compatibleCandidateSchemaWithNewDefaultedField,
            msg = "the recorded validation decision should reference the evaluated candidate schema");

    // Repeating the lookup independently confirms the active schema lookup itself is stable and
    // unaffected by any number of validation calls.
    string activeSchemaOnRepeatLookup = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaOnRepeatLookup, activeSchemaBeforeValidation,
            msg = "repeated lookups of the active schema must remain stable after validation calls");
}
