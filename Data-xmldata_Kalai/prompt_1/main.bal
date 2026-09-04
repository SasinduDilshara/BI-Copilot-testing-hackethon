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
}
