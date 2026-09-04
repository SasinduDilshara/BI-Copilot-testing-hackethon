import ballerina/http;

// HTTP API that receives a sales order payload and creates a sales order in SAP S/4HANA.
service /SalesOrder on new http:Listener(8080) {

    # Creates a sales order in SAP S/4HANA.
    #
    # + salesOrderRequest - the sales order payload
    # + return - the SAP sales order creation response
    resource function post .(@http:Payload SalesOrderRequest salesOrderRequest) returns json|http:InternalServerError {
        json|error result = createSapSalesOrder(salesOrderRequest);
        if result is error {
            return <http:InternalServerError>{
                body: {message: result.message()}
            };
        }
        return result;
    }
}
