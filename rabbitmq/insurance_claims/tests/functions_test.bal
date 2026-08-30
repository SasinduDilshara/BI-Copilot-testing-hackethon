import ballerina/test;
import ballerinax/rabbitmq;

@test:Config {}
function testBuildRoutingKeyBasic() {
    string routingKey = buildRoutingKey("auto", "high");
    test:assertEquals(routingKey, "claim.auto.high", msg = "Routing key should be claim.auto.high");
}

@test:Config {}
function testBuildRoutingKeyNormalizesCase() {
    string routingKey = buildRoutingKey("Health", "LOW");
    test:assertEquals(routingKey, "claim.health.low", msg = "Routing key should be normalized to lower case");
}

@test:Config {}
function testBuildRoutingKeyNormalizesWhitespace() {
    string routingKey = buildRoutingKey("property damage", "very high");
    test:assertEquals(routingKey, "claim.property-damage.very-high",
            msg = "Whitespace in claim type/priority should be replaced with a hyphen");
}

@test:Config {}
function testExtractRetryCountWithNoProperties() {
    int retryCount = extractRetryCount(());
    test:assertEquals(retryCount, 0, msg = "Retry count should default to 0 when properties are absent");
}

@test:Config {}
function testExtractRetryCountWithNoHeaders() {
    rabbitmq:BasicProperties properties = {correlationId: "claim-1"};
    int retryCount = extractRetryCount(properties);
    test:assertEquals(retryCount, 0, msg = "Retry count should default to 0 when headers are absent");
}

@test:Config {}
function testExtractRetryCountWithHeaderPresent() {
    rabbitmq:BasicProperties properties = {
        correlationId: "claim-1",
        headers: {"x-retry-count": 2}
    };
    int retryCount = extractRetryCount(properties);
    test:assertEquals(retryCount, 2, msg = "Retry count should be read from the x-retry-count header");
}

@test:Config {}
function testExtractRetryCountWithMalformedHeader() {
    rabbitmq:BasicProperties properties = {
        correlationId: "claim-1",
        headers: {"x-retry-count": "not-a-number"}
    };
    int retryCount = extractRetryCount(properties);
    test:assertEquals(retryCount, 0, msg = "Retry count should default to 0 when the header value is not an int");
}

@test:Config {}
function testProcessClaimSucceedsForValidClaim() returns error? {
    ClaimSubmission claimSubmission = {
        claimId: "CLM-1",
        policyNumber: "POL-1",
        claimType: "auto",
        claimAmount: 1500.00d,
        incidentDate: "2026-08-01",
        priority: "high"
    };
    check processClaim(claimSubmission);
}

@test:Config {}
function testProcessClaimFailsForInvalidAmount() {
    ClaimSubmission claimSubmission = {
        claimId: "CLM-2",
        policyNumber: "POL-2",
        claimType: "health",
        claimAmount: 0d,
        incidentDate: "2026-08-01",
        priority: "low"
    };
    error? processingResult = processClaim(claimSubmission);
    test:assertTrue(processingResult is error, msg = "Processing should fail for a non-positive claim amount");
    if processingResult is error {
        test:assertEquals(processingResult.message(), "Invalid claim amount for claim CLM-2",
                msg = "Error message should describe the invalid amount");
    }
}
