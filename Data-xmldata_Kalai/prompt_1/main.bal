import ballerina/data.xmldata;
import ballerina/http;

service /orders on new http:Listener(8090) {

    resource function post process(@http:Payload xml payload) returns http:Response|http:BadRequest {
        string payloadText = payload.toString();
        PurchaseOrder|xmldata:Error purchaseOrder = xmldata:parseString(payloadText);
        if purchaseOrder is xmldata:Error {
            return {
                body: string `Invalid purchase order XML: ${purchaseOrder.message()}`
            };
        }

        decimal totalOrderValue = 0;
        foreach LineItem lineItem in purchaseOrder.lineItems.item {
            totalOrderValue += lineItem.unitPrice * lineItem.quantity;
        }

        ProcessedOrder processedOrder = {
            orderId: purchaseOrder.orderId,
            supplier: purchaseOrder.supplier,
            lineItems: purchaseOrder.lineItems,
            currency: purchaseOrder.currency,
            requestedDeliveryDate: purchaseOrder.requestedDeliveryDate,
            totalOrderValue: totalOrderValue
        };

        xml|xmldata:Error responseXml = xmldata:toXml(processedOrder);
        if responseXml is xmldata:Error {
            return {
                body: string `Failed to construct response XML: ${responseXml.message()}`
            };
        }

        http:Response response = new;
        response.setXmlPayload(responseXml, contentType = "application/xml");
        return response;
    }

    resource function post validate(@http:Payload xml payload) returns http:Ok|http:BadRequest {
        string payloadText = payload.toString();
        string[] errorMessages = [];

        if payloadText.trim().length() == 0 {
            errorMessages.push("XML string must not be empty");
            ValidationResult emptyResult = {
                valid: false,
                orderId: "",
                errorMessages: errorMessages,
                parsedOrder: ()
            };
            http:BadRequest badRequest = {body: emptyResult};
            return badRequest;
        }

        PurchaseOrder|xmldata:Error purchaseOrder = xmldata:parseString(payloadText);
        if purchaseOrder is xmldata:Error {
            errorMessages.push(string `Invalid purchase order XML: ${purchaseOrder.message()}`);
            ValidationResult parseFailureResult = {
                valid: false,
                orderId: "",
                errorMessages: errorMessages,
                parsedOrder: ()
            };
            http:BadRequest badRequest = {body: parseFailureResult};
            return badRequest;
        }

        if !purchaseOrder.orderId.startsWith("PO-") {
            errorMessages.push("orderId must start with 'PO-'");
        }

        string[] allowedCurrencies = ["USD", "EUR", "GBP"];
        if allowedCurrencies.indexOf(purchaseOrder.currency) is () {
            errorMessages.push("currency must be one of \"USD\", \"EUR\", or \"GBP\"");
        }

        foreach LineItem lineItem in purchaseOrder.lineItems.item {
            if lineItem.unitPrice <= 0d {
                errorMessages.push(string `unitPrice must be greater than 0 for item '${lineItem.itemCode}'`);
            }
            int|error quantityAsInt = int:fromString(lineItem.quantity.toString());
            if lineItem.quantity <= 0d || quantityAsInt is error {
                errorMessages.push(string `quantity must be a positive integer for item '${lineItem.itemCode}'`);
            }
        }

        boolean isValid = errorMessages.length() == 0;
        ValidationResult validationResult = {
            valid: isValid,
            orderId: purchaseOrder.orderId,
            errorMessages: errorMessages,
            parsedOrder: isValid ? purchaseOrder : ()
        };

        if !isValid {
            http:BadRequest badRequest = {body: validationResult};
            return badRequest;
        }
        http:Ok ok = {body: validationResult};
        return ok;
    }

    resource function post transform(@http:Payload xml payload) returns http:Ok|http:BadRequest {
        PurchaseOrderSummary|xmldata:Error summary = xmldata:parseAsType(payload, {allowDataProjection: true});
        if summary is xmldata:Error {
            http:BadRequest badRequest = {
                body: string `Failed to extract purchase order summary: ${summary.message()}`
            };
            return badRequest;
        }
        http:Ok ok = {body: summary};
        return ok;
    }

    resource function post from\-json(@http:Payload json payload) returns http:Ok|http:BadRequest {
        xmldata:JsonOptions jsonOptions = {
            attributePrefix: "@",
            textFieldName: "#text"
        };
        xml|xmldata:Error convertedXml = xmldata:fromJson(payload, jsonOptions);
        if convertedXml is xmldata:Error {
            http:BadRequest badRequest = {
                body: string `Failed to convert JSON to XML: ${convertedXml.message()}`
            };
            return badRequest;
        }

        http:Ok ok = {body: convertedXml.toString(), mediaType: "text/plain"};
        return ok;
    }
}
