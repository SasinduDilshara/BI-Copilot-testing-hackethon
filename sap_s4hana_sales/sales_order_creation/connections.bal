import ballerinax/sap.s4hana.api_sales_order_srv;

// SAP S/4HANA Sales Order connection.
final api_sales_order_srv:Client sapSalesOrderClient = check new (
    {
        auth: {
            username: sapUsername,
            password: sapPassword
        }
    },
    sapHostname
);
