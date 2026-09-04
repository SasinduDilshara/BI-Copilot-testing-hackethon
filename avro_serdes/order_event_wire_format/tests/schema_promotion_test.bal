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
function testPromoteRejectsIncompatibleCandidateWithoutChangingActiveVersion() returns error? {
    string activeSchemaBeforePromotion = getActiveCustomerProfileSchema();
    int auditLogSizeBeforePromotion = getPromotionAuditLog().length();

    PromotionDecision|PromotionError result = promoteCustomerProfileSchema(incompatibleCandidateSchemaMissingRequiredField);

    if result is PromotionError {
        test:assertFail(msg = "an incompatible candidate should still produce a decision, not an error");
    }
    PromotionDecision decision = result;
    test:assertEquals(decision.outcome, "REJECTED", msg = "an incompatible candidate should be rejected");
    test:assertEquals(decision.schemaId, (), msg = "a rejected candidate should not be assigned a schema id");
    test:assertEquals(decision.subject, customerProfileValueSubject, msg = "the decision should be recorded against the customer-profile-value subject");

    string activeSchemaAfterPromotion = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaAfterPromotion, activeSchemaBeforePromotion,
            msg = "the active schema must remain unchanged after an incompatible candidate is rejected");

    PromotionDecision[] auditLogAfterPromotion = getPromotionAuditLog();
    test:assertEquals(auditLogAfterPromotion.length(), auditLogSizeBeforePromotion + 1,
            msg = "a rejection decision should be appended to the audit log");
    PromotionDecision lastDecision = auditLogAfterPromotion[auditLogAfterPromotion.length() - 1];
    test:assertEquals(lastDecision.outcome, "REJECTED", msg = "the recorded audit decision should be a rejection");
    test:assertEquals(lastDecision.candidateSchema, incompatibleCandidateSchemaMissingRequiredField,
            msg = "the recorded audit decision should reference the evaluated candidate schema");
}

@test:Config {}
function testPromoteRejectsCandidateWithChangedFieldTypeWithoutChangingActiveVersion() returns error? {
    string activeSchemaBeforePromotion = getActiveCustomerProfileSchema();

    PromotionDecision|PromotionError result = promoteCustomerProfileSchema(incompatibleCandidateSchemaWithChangedFieldType);

    if result is PromotionError {
        test:assertFail(msg = "an incompatible candidate should still produce a decision, not an error");
    }
    PromotionDecision decision = result;
    test:assertEquals(decision.outcome, "REJECTED", msg = "a candidate with an incompatible type change should be rejected");

    string activeSchemaAfterPromotion = getActiveCustomerProfileSchema();
    test:assertEquals(activeSchemaAfterPromotion, activeSchemaBeforePromotion,
            msg = "the active schema must remain unchanged after rejection");
}
