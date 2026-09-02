import ballerina/email;
import ballerina/http;
import ballerina/test;
import ballerinax/sap.jco;

// ============================================================================
// End-to-end tests for the SAP ECC Sales Order Retrieval integration.
//
// The SAP JCo client (`sapEccClient`) and the SMTP client (`smtpClient`) are
// replaced with mocks so the tests exercise the full HTTP -> SAP JCo -> BAPI
// -> transform -> SMTP flow without making any real SAP RFC calls or sending
// real emails.
//
// Scenarios covered:
//   1. Full success - SAP returns the order, email is sent.
//   2. SAP business error - BAPI RETURN.TYPE = E (e.g. order does not exist).
//   3. SAP connection error - SAP JCo execute fails with a connection error.
//   4. Partial success - SAP succeeds but the SMTP send fails.
//   5. Validation error - empty sales order number in the request.
// ============================================================================

const string TEST_SALES_ORDER = "5000012345";
final http:Client testClient = check new ("http://localhost:8080/sap/salesorders");

BapiReturn successReturn = {
    TYPE: "S",
    MESSAGE: "Sales order retrieved successfully"
};

BapiReturn businessErrorReturn = {
    TYPE: "E",
    MESSAGE: "Sales order 5000012345 does not exist"
};

SapOrderHeader mockHeader = {
    DOC_NUMBER: TEST_SALES_ORDER,
    DOC_TYPE: "OR",
    SALES_ORG: "1000",
    DISTR_CHAN: "10",
    DIVISION: "00",
    SOLD_TO: "10000045",
    CUST_NAME: "ABC Manufacturing",
    DOC_DATE: "2026-09-02",
    CURRENCY: "USD",
    NET_VALUE: 12500.00d
};

SapOrderItem[] mockItems = [
    {
        ITM_NUMBER: "000010",
        MATERIAL: "MAT-10001",
        SHORT_TEXT: "Industrial Controller",
        REQ_QTY: 5,
        SALES_UNIT: "EA",
        NET_VALUE: 7500.00d
    },
    {
        ITM_NUMBER: "000020",
        MATERIAL: "MAT-10002",
        SHORT_TEXT: "Communication Module",
        REQ_QTY: 10,
        SALES_UNIT: "EA",
        NET_VALUE: 5000.00d
    }
];

BapiSalesOrderGetDetailOutput successBapiOutput = {
    RETURN: successReturn,
    ORDER_HEADER: mockHeader,
    ORDER_ITEMS: mockItems
};

BapiSalesOrderGetDetailOutput businessErrorBapiOutput = {
    RETURN: businessErrorReturn,
    ORDER_HEADER: {},
    ORDER_ITEMS: []
};

# Resets the SAP JCo client and SMTP client to fresh mocks before each test so
# stubs from one test do not leak into another.
function mockSapClient() {
    sapEccClient = test:mock(jco:Client);
}

function mockSmtpClient() {
    smtpClient = test:mock(email:SmtpClient);
}

@test:Config {}
function testSuccessfulSalesOrderRetrievalAndEmail() returns error? {
    mockSapClient();
    mockSmtpClient();

    test:prepare(sapEccClient).when("execute").thenReturn(successBapiOutput);
    test:prepare(smtpClient).when("sendMessage").doNothing();

    SalesOrderRequest request = {salesOrder: TEST_SALES_ORDER};
    SuccessResponse response = check testClient->/retrieve.post(request);

    test:assertEquals(response.status, "SUCCESS", msg = "Overall status should be SUCCESS");
    test:assertEquals(response.salesOrder, TEST_SALES_ORDER, msg = "Sales order number mismatch");
    test:assertEquals(response.sapSystem, "SAP ECC", msg = "SAP system should be SAP ECC");
    test:assertEquals(response.bapi, "BAPI_SALESORDER_GETDETAIL", msg = "BAPI name mismatch");
    test:assertEquals(response.sapStatus, "SUCCESS", msg = "SAP status should be SUCCESS");
    test:assertEquals(response.emailStatus, "SENT", msg = "Email status should be SENT");
    test:assertEquals(response.recipient, "orders@example.com", msg = "Recipient mismatch");
}

@test:Config {}
function testSapBusinessErrorDoesNotSendEmail() returns error? {
    mockSapClient();
    mockSmtpClient();

    test:prepare(sapEccClient).when("execute").thenReturn(businessErrorBapiOutput);
    test:prepare(smtpClient).when("sendMessage").doNothing();

    SalesOrderRequest request = {salesOrder: TEST_SALES_ORDER};
    SapBusinessErrorResponse response = check testClient->/retrieve.post(request);

    test:assertEquals(response.status, "ERROR", msg = "Overall status should be ERROR");
    test:assertEquals(response.salesOrder, TEST_SALES_ORDER, msg = "Sales order number mismatch");
    test:assertEquals(response.sapStatus, "FAILED", msg = "SAP status should be FAILED");
    test:assertEquals(response.errorCode, "SAP_BAPI_ERROR", msg = "Error code mismatch");
    test:assertEquals(response.message, "Sales order 5000012345 does not exist", msg = "Error message mismatch");
}

@test:Config {}
function testSapConnectionFailure() returns error? {
    mockSapClient();
    mockSmtpClient();

    jco:Error connectionError = error("Unable to reach SAP application server");
    test:prepare(sapEccClient).when("execute").thenReturn(connectionError);

    SalesOrderRequest request = {salesOrder: TEST_SALES_ORDER};
    SapConnectionErrorResponse response = check testClient->/retrieve.post(request);

    test:assertEquals(response.status, "ERROR", msg = "Overall status should be ERROR");
    test:assertEquals(response.errorCode, "SAP_CONNECTION_ERROR", msg = "Error code mismatch");
    test:assertEquals(response.message, "Unable to connect to SAP ECC", msg = "Error message mismatch");
}

@test:Config {}
function testEmailFailureAfterSuccessfulSapRetrieval() returns error? {
    mockSapClient();
    mockSmtpClient();

    test:prepare(sapEccClient).when("execute").thenReturn(successBapiOutput);
    email:Error smtpError = error email:Error("Unable to connect to SMTP server");
    test:prepare(smtpClient).when("sendMessage").thenReturn(smtpError);

    SalesOrderRequest request = {salesOrder: TEST_SALES_ORDER};
    PartialSuccessResponse response = check testClient->/retrieve.post(request);

    test:assertEquals(response.status, "PARTIAL_SUCCESS", msg = "Overall status should be PARTIAL_SUCCESS");
    test:assertEquals(response.salesOrder, TEST_SALES_ORDER, msg = "Sales order number mismatch");
    test:assertEquals(response.sapStatus, "SUCCESS", msg = "SAP status should be SUCCESS");
    test:assertEquals(response.emailStatus, "FAILED", msg = "Email status should be FAILED");
    test:assertEquals(response.errorCode, "SMTP_ERROR", msg = "Error code mismatch");
    test:assertEquals(response.message, "Unable to send notification email", msg = "Error message mismatch");
}

@test:Config {}
function testValidationErrorForBlankSalesOrder() returns error? {
    mockSapClient();
    mockSmtpClient();

    SalesOrderRequest request = {salesOrder: "   "};
    GenericErrorResponse response = check testClient->/retrieve.post(request);

    test:assertEquals(response.status, "ERROR", msg = "Overall status should be ERROR");
    test:assertEquals(response.errorCode, "INVALID_REQUEST", msg = "Error code mismatch");
    test:assertEquals(response.message, "salesOrder is required", msg = "Error message mismatch");
}
