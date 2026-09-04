// Request payload received by the SalesOrder HTTP API.
// Mirrors the sales order creation payload structure used in the SAP S/4HANA
// Sales Order (A2X) API "Create Order" operation.
public type SalesOrderItem record {|
    string material;
    string requestedQuantity;
    string requestedQuantityUnit;
|};

public type SalesOrderPartner record {|
    string partnerFunction;
    string customer;
|};

public type SalesOrderRequest record {|
    string salesOrderType;
    string salesOrganization;
    string distributionChannel;
    string organizationDivision;
    string soldToParty;
    string transactionCurrency;
    SalesOrderPartner[] partners;
    SalesOrderItem[] items;
|};
