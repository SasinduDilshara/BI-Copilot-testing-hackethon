import ballerina/http;
import ballerina/log;

// Mock SAP Commerce Web Services API used only for local testing of the integration.
// Replicates the OCC v2 "get order" endpoint: GET /occ/v2/{baseSiteId}/orders/{code}
service /occ/v2 on new http:Listener(mockSapCommercePort) {

    resource function get [string baseSiteId]/orders/[string code]() returns json {
        log:printInfo("Mock SAP Commerce received getOrder request", baseSiteId = baseSiteId, code = code);

        if code == "ORD-404" {
            return {
                "errors": [
                    {"type": "NotFoundError", "message": "Order not found"}
                ]
            };
        }

        return {
            "code": code,
            "status": "CONFIRMED",
            "statusDisplay": "Confirmed",
            "created": "2026-09-04T06:30:00+0000",
            "guid": "9a8b7c6d-1234-5678-9abc-def012345678",
            "totalPrice": {
                "value": 149.97,
                "currencyIso": "USD",
                "formattedValue": "$149.97"
            },
            "orgCustomer": {
                "uid": "jane.doe@example.com",
                "firstName": "Jane",
                "lastName": "Doe",
                "email": "jane.doe@example.com",
                "name": "Jane Doe"
            },
            "sapCustomerEmail": "jane.doe@example.com",
            "deliveryAddress": {
                "firstName": "Jane",
                "lastName": "Doe",
                "line1": "221B Baker Street",
                "line2": "Apt 4",
                "town": "London",
                "postalCode": "NW1 6XE",
                "titleCode": "mrs",
                "country": {
                    "isocode": "GB",
                    "name": "United Kingdom"
                }
            },
            "entries": [
                {
                    "entryNumber": 1,
                    "quantity": 2,
                    "product": {
                        "code": "SKU-1001",
                        "name": "Wireless Mouse"
                    },
                    "basePrice": {
                        "value": 29.99,
                        "currencyIso": "USD",
                        "formattedValue": "$29.99"
                    },
                    "totalPrice": {
                        "value": 59.98,
                        "currencyIso": "USD",
                        "formattedValue": "$59.98"
                    }
                },
                {
                    "entryNumber": 2,
                    "quantity": 1,
                    "product": {
                        "code": "SKU-2002",
                        "name": "Mechanical Keyboard"
                    },
                    "basePrice": {
                        "value": 89.99,
                        "currencyIso": "USD",
                        "formattedValue": "$89.99"
                    },
                    "totalPrice": {
                        "value": 89.99,
                        "currencyIso": "USD",
                        "formattedValue": "$89.99"
                    }
                }
            ]
        };
    }
}
