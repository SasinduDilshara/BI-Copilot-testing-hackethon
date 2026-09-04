import ballerinax/sap.s4hana.api_sales_order_srv;

// Maps a single sales order item from the HTTP request to the SAP connector item structure.
function mapToSapSalesOrderItem(SalesOrderItem salesOrderItem) returns api_sales_order_srv:CreateA_SalesOrderItem => {
    SalesOrderItem: "",
    Material: salesOrderItem.material,
    RequestedQuantity: salesOrderItem.requestedQuantity,
    RequestedQuantityUnit: salesOrderItem.requestedQuantityUnit
};

// Maps a single sales order partner from the HTTP request to the SAP connector partner structure.
function mapToSapSalesOrderPartner(SalesOrderPartner salesOrderPartner) returns api_sales_order_srv:CreateA_SalesOrderHeaderPartner => {
    PartnerFunction: salesOrderPartner.partnerFunction,
    Customer: salesOrderPartner.customer
};

// Maps the HTTP sales order request payload to the SAP S/4HANA Create Sales Order request structure.
function mapToSapSalesOrderRequest(SalesOrderRequest salesOrderRequest) returns api_sales_order_srv:CreateA_SalesOrder => {
    SalesOrder: "",
    SalesOrderType: salesOrderRequest.salesOrderType,
    SalesOrganization: salesOrderRequest.salesOrganization,
    DistributionChannel: salesOrderRequest.distributionChannel,
    OrganizationDivision: salesOrderRequest.organizationDivision,
    SoldToParty: salesOrderRequest.soldToParty,
    TransactionCurrency: salesOrderRequest.transactionCurrency,
    to_Partner: {
        results: from SalesOrderPartner salesOrderPartner in salesOrderRequest.partners
            select mapToSapSalesOrderPartner(salesOrderPartner)
    },
    to_Item: {
        results: from SalesOrderItem salesOrderItem in salesOrderRequest.items
            select mapToSapSalesOrderItem(salesOrderItem)
    }
};
