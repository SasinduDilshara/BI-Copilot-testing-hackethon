import ballerinax/sap.s4hana.api_sales_order_srv;

// Creates a sales order in SAP S/4HANA using the api_sales_order connector's Create Order
// operation and returns the SAP response converted to JSON.
function createSapSalesOrder(SalesOrderRequest salesOrderRequest) returns json|error {
    api_sales_order_srv:CreateA_SalesOrder createSalesOrderPayload = mapToSapSalesOrderRequest(salesOrderRequest);
    api_sales_order_srv:A_SalesOrderWrapper createSalesOrderResult = check sapSalesOrderClient->createA_SalesOrder(createSalesOrderPayload);
    return createSalesOrderResult.toJson();
}
