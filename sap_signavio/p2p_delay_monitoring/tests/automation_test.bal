// Tests for the SAP Signavio -> Email (SMTP) delayed-approval notification integration.
//
// SAP Signavio and the SMTP server are mocked using ballerina/test object mocks so the
// full orchestration flow (authenticate -> retrieve cases -> evaluate business rule
// -> send email) can be exercised without depending on real external systems.

import ballerina/email;
import ballerina/test;
import ballerinax/sap.signavio;

// --- Representative Signavio "cases" API responses used by the mocks below ---

signavio:CasesResourceSchema mockDelayedCaseResource = {
    id: {date: "P2P-2026-000458"},
    'type: "Cases",
    attributes: {}
};

signavio:CasesResourcesResponseSchema mockDelayedCasesResponse = {
    data: [mockDelayedCaseResource]
};

signavio:CasesResourcesResponseSchema mockEmptyCasesResponse = {
    data: []
};

# Builds a mock Signavio client whose `authenticate` and `listCases` remote functions
# are stubbed to return the given values.
#
# + authResponse - Value or error to return from `authenticate`
# + casesResponse - Value or error to return from `listCases`
# + return - A mock signavio:Client ready to be injected into the integration logic
function createMockSignavioClient(string|error authResponse,
        signavio:CasesResourcesResponseSchema|error casesResponse) returns signavio:Client {
    signavio:Client mockClient = test:mock(signavio:Client);
    test:prepare(mockClient).when("authenticate").thenReturn(authResponse);
    test:prepare(mockClient).when("listCases").thenReturn(casesResponse);
    return mockClient;
}

# Builds a mock SMTP client whose `sendMessage` remote function is stubbed to return
# the given result.
#
# + sendResult - Value or error to return from `sendMessage`
# + return - A mock email:SmtpClient ready to be injected into the integration logic
function createMockSmtpClient(email:Error? sendResult) returns email:SmtpClient {
    email:SmtpClient mockClient = test:mock(email:SmtpClient);
    test:prepare(mockClient).when("sendMessage").thenReturn(sendResult);
    return mockClient;
}

@test:Config {}
function testSuccessfulNotificationFlow() returns error? {
    signavio:Client mockSignavio = createMockSignavioClient("mock-access-token", mockDelayedCasesResponse);
    email:SmtpClient mockSmtp = createMockSmtpClient(());

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is IntegrationSuccessResponse, msg = "Expected a SUCCESS response");
    if result is IntegrationSuccessResponse {
        test:assertEquals(result.status, "SUCCESS", msg = "Status should be SUCCESS");
        test:assertEquals(result.processInstance, "P2P-2026-000458", msg = "Process instance id should match");
        test:assertEquals(result.notificationStatus, "SENT", msg = "Notification status should be SENT");
        test:assertEquals(result.recipient, "john.perera@example.com", msg = "Recipient should be the responsible manager");
    }
}

@test:Config {}
function testSignavioAuthenticationFailure() returns error? {
    error authError = error("401 Unauthorized: invalid credentials");
    signavio:Client mockSignavio = createMockSignavioClient(authError, mockEmptyCasesResponse);
    email:SmtpClient mockSmtp = createMockSmtpClient(());

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is IntegrationErrorResponse, msg = "Expected an ERROR response");
    if result is IntegrationErrorResponse {
        test:assertEquals(result.status, "ERROR", msg = "Status should be ERROR");
        test:assertEquals(result.errorCode, "SIGNAVIO_AUTH_ERROR", msg = "Error code should indicate an auth failure");
    }
}

@test:Config {}
function testSignavioApiUnavailable() returns error? {
    error apiError = error("connection refused");
    signavio:Client mockSignavio = createMockSignavioClient("mock-access-token", apiError);
    email:SmtpClient mockSmtp = createMockSmtpClient(());

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is IntegrationErrorResponse, msg = "Expected an ERROR response");
    if result is IntegrationErrorResponse {
        test:assertEquals(result.status, "ERROR", msg = "Status should be ERROR");
        test:assertEquals(result.errorCode, "SIGNAVIO_API_UNAVAILABLE", msg = "Error code should indicate the Signavio API was unavailable after retries were exhausted");
    }
}

@test:Config {}
function testSignavioRequestTimeout() returns error? {
    error timeoutError = error("Request timed out while waiting for a response");
    signavio:Client mockSignavio = createMockSignavioClient("mock-access-token", timeoutError);
    email:SmtpClient mockSmtp = createMockSmtpClient(());

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is IntegrationErrorResponse, msg = "Expected an ERROR response");
    if result is IntegrationErrorResponse {
        test:assertEquals(result.status, "ERROR", msg = "Status should be ERROR");
        test:assertEquals(result.errorCode, "SIGNAVIO_TIMEOUT", msg = "Error code should indicate a Signavio request timeout after retries were exhausted");
    }
}

@test:Config {}
function testNoMatchingProcessInstances() returns error? {
    signavio:Client mockSignavio = createMockSignavioClient("mock-access-token", mockEmptyCasesResponse);
    email:SmtpClient mockSmtp = createMockSmtpClient(());

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is NoActionResponse, msg = "Expected a NOT_REQUIRED response");
    if result is NoActionResponse {
        test:assertEquals(result.status, "SUCCESS", msg = "Status should be SUCCESS");
        test:assertEquals(result.notificationStatus, "NOT_REQUIRED", msg = "Notification should not be required when no cases are returned");
    }
}

@test:Config {}
function testEmailDeliveryFailure() returns error? {
    signavio:Client mockSignavio = createMockSignavioClient("mock-access-token", mockDelayedCasesResponse);
    email:Error smtpError = error("SMTP connection failed");
    email:SmtpClient mockSmtp = createMockSmtpClient(smtpError);

    IntegrationResult result = runMonitoringCycle(mockSignavio, mockSmtp);

    test:assertTrue(result is PartialSuccessResponse, msg = "Expected a PARTIAL_SUCCESS response");
    if result is PartialSuccessResponse {
        test:assertEquals(result.status, "PARTIAL_SUCCESS", msg = "Status should be PARTIAL_SUCCESS");
        test:assertEquals(result.processInstance, "P2P-2026-000458", msg = "Process instance id should still be reported");
        test:assertEquals(result.signavioStatus, "SUCCESS", msg = "Signavio retrieval should have succeeded");
        test:assertEquals(result.notificationStatus, "FAILED", msg = "Notification status should be FAILED");
        test:assertEquals(result.'error, "SMTP connection failed", msg = "Error message should describe the SMTP failure");
    }
}

// --- Business rule and email construction unit tests ---

@test:Config {}
function testRequiresNotificationWhenThresholdExceeded() {
    ProcessDelayInfo delayedInfo = {
        processName: "Purchase-to-Pay",
        processInstanceId: "P2P-2026-000458",
        purchaseRequisitionId: "PR-100458",
        processStatus: "Delayed",
        currentActivity: "Manager Approval",
        activityStatus: "Waiting",
        expectedApprovalHours: 24,
        actualWaitingHours: 31,
        delayHours: 7,
        responsibleDepartment: "Procurement",
        responsibleManagerName: "John Perera",
        responsibleManagerEmail: "john.perera@example.com",
        priority: "High",
        detectedAt: "2026-09-02T10:00:00+05:30"
    };
    boolean notificationRequired = requiresNotification(delayedInfo);
    test:assertTrue(notificationRequired, msg = "Notification should be required when actual waiting time exceeds the threshold");
}

@test:Config {}
function testRequiresNotificationWhenWithinThreshold() {
    ProcessDelayInfo onTimeInfo = {
        processName: "Purchase-to-Pay",
        processInstanceId: "P2P-2026-000459",
        purchaseRequisitionId: "PR-100459",
        processStatus: "On Track",
        currentActivity: "Manager Approval",
        activityStatus: "Waiting",
        expectedApprovalHours: 24,
        actualWaitingHours: 10,
        delayHours: 0,
        responsibleDepartment: "Procurement",
        responsibleManagerName: "Jane Silva",
        responsibleManagerEmail: "jane.silva@example.com",
        priority: "Normal",
        detectedAt: "2026-09-02T10:00:00+05:30"
    };
    boolean notificationRequired = requiresNotification(onTimeInfo);
    test:assertTrue(!notificationRequired, msg = "Notification should not be required when within the approval threshold");
}

@test:Config {}
function testBuildEmailSubject() {
    ProcessDelayInfo delayedInfo = {
        processName: "Purchase-to-Pay",
        processInstanceId: "P2P-2026-000458",
        purchaseRequisitionId: "PR-100458",
        processStatus: "Delayed",
        currentActivity: "Manager Approval",
        activityStatus: "Waiting",
        expectedApprovalHours: 24,
        actualWaitingHours: 31,
        delayHours: 7,
        responsibleDepartment: "Procurement",
        responsibleManagerName: "John Perera",
        responsibleManagerEmail: "john.perera@example.com",
        priority: "High",
        detectedAt: "2026-09-02T10:00:00+05:30"
    };
    string subject = buildEmailSubject(delayedInfo);
    test:assertTrue(subject.includes("PR-100458"), msg = "Subject should include the purchase requisition id");
    test:assertTrue(subject.startsWith("URGENT: Purchase-to-Pay Approval Delayed"), msg = "Subject should start with the urgent delay prefix");
}

@test:Config {}
function testBuildEmailBodyContainsKeyDetails() {
    ProcessDelayInfo delayedInfo = {
        processName: "Purchase-to-Pay",
        processInstanceId: "P2P-2026-000458",
        purchaseRequisitionId: "PR-100458",
        processStatus: "Delayed",
        currentActivity: "Manager Approval",
        activityStatus: "Waiting",
        expectedApprovalHours: 24,
        actualWaitingHours: 31,
        delayHours: 7,
        responsibleDepartment: "Procurement",
        responsibleManagerName: "John Perera",
        responsibleManagerEmail: "john.perera@example.com",
        priority: "High",
        detectedAt: "2026-09-02T10:00:00+05:30"
    };
    string body = buildEmailBody(delayedInfo);
    test:assertTrue(body.includes("Dear John,"), msg = "Body should greet the manager by first name");
    test:assertTrue(body.includes("P2P-2026-000458"), msg = "Body should include the process instance id");
    test:assertTrue(body.includes("PR-100458"), msg = "Body should include the purchase requisition id");
    test:assertTrue(body.includes("Actual Waiting Time: 31 hours"), msg = "Body should include the actual waiting time");
    test:assertTrue(body.includes("Delay: 7 hours"), msg = "Body should include the computed delay");
}
