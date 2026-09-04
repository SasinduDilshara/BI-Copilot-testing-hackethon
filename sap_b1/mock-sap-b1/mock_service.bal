import ballerina/http;
import ballerina/log;

// Mock SAP Business One Service Layer used for end-to-end testing.
// Point the `serviceLayerUrl` configurable of the automation to this listener,
// e.g. http://localhost:8090/b1s/v1
listener http:Listener mockB1Listener = new (8090);

int mockPurchaseRequestDocEntry = 1000;

service /b1s/v1 on mockB1Listener {

    // Emulates the SAP B1 Service Layer session login.
    resource function post Login(@http:Payload json loginPayload) returns http:Ok {
        log:printInfo("Mock SAP B1: Login called", payload = loginPayload);
        http:Ok response = {
            headers: {
                "Set-Cookie": "B1SESSION=mock-session-id; Path=/b1s/v1/; HttpOnly"
            },
            body: {
                "odata.metadata": "https://localhost:8090/b1s/v1/$metadata#SAPB1.Login/@Element",
                "SessionId": "mock-session-id",
                "Version": "1000114",
                "SessionTimeout": 30
            }
        };
        return response;
    }

    // Emulates the SAP B1 Service Layer session logout.
    resource function post Logout() returns http:NoContent {
        log:printInfo("Mock SAP B1: Logout called");
        return http:NO_CONTENT;
    }

    // Emulates the Items collection query used by the inventory connector's listItems operation.
    resource function get Items(string? \$filter = ()) returns json {
        log:printInfo("Mock SAP B1: Items list called", filter = \$filter);

        json[] items = [
            {
                "ItemCode": "A00001",
                "ItemName": "Mock Widget Small",
                "QuantityOnStock": 3,
                "PurchaseItem": "tYES",
                "SalesItem": "tYES",
                "InventoryItem": "tYES"
            },
            {
                "ItemCode": "A00002",
                "ItemName": "Mock Widget Large",
                "QuantityOnStock": 5,
                "PurchaseItem": "tYES",
                "SalesItem": "tYES",
                "InventoryItem": "tYES"
            }
        ];

        json responseBody = {
            "odata.metadata": "https://localhost:8090/b1s/v1/$metadata#Items",
            "value": items
        };
        return responseBody;
    }

    // Emulates creating a Purchase Request document used by the purchasing connector's createPurchaseRequests operation.
    resource function post PurchaseRequests(@http:Payload json purchaseRequestPayload) returns json {
        log:printInfo("Mock SAP B1: Create purchase request called", payload = purchaseRequestPayload);

        mockPurchaseRequestDocEntry += 1;
        int docEntry = mockPurchaseRequestDocEntry;

        map<json> requestFields = <map<json>> purchaseRequestPayload;
        map<json> responseFields = requestFields.clone();
        responseFields["DocEntry"] = docEntry;
        responseFields["DocNum"] = docEntry;
        responseFields["DocumentStatus"] = "bost_Open";

        json responseBody = responseFields;
        return responseBody;
    }
}
