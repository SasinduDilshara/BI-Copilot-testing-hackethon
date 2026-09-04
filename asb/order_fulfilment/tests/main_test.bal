import ballerina/http;
import ballerina/test;

final http:Client testOrdersClient = check new (string `http://localhost:${httpPort}/orders`);

@test:Config {}
function testSubmitFulfilmentCommandAccepted() returns error? {
    FulfilmentCommand command = {
        orderId: "ORD-1001",
        customerId: "CUST-1",
        items: [
            {sku: "SKU-1", quantity: 2}
        ],
        requestedAt: "2026-09-03T12:00:00Z"
    };

    http:Response response = check testOrdersClient->/fulfilCommands.post(command);

    test:assertEquals(response.statusCode, http:STATUS_ACCEPTED, msg = "Unexpected status code in response");

    json responseBody = check response.getJsonPayload();
    FulfilmentCommandAccepted acceptedBody = check responseBody.cloneWithType(FulfilmentCommandAccepted);

    test:assertEquals(acceptedBody.orderId, "ORD-1001", msg = "Unexpected orderId in response");
    test:assertEquals(acceptedBody.message, "Fulfilment command submitted", msg = "Unexpected message in response");
}

@test:Config {}
function testParseFulfilmentCommandFromBytes() returns error? {
    FulfilmentCommand originalCommand = {
        orderId: "ORD-2002",
        customerId: "CUST-2",
        items: [
            {sku: "SKU-9", quantity: 5}
        ],
        requestedAt: "2026-09-03T13:00:00Z"
    };

    byte[] serializedCommand = originalCommand.toJson().toJsonString().toBytes();
    FulfilmentCommand parsedCommand = check parseFulfilmentCommand(serializedCommand);

    test:assertEquals(parsedCommand, originalCommand, msg = "Parsed command does not match the original command");
}
