import ballerina/data.xmldata;

@xmldata:Namespace {
    uri: "http://procurement.company.com/schema"
}
public type PurchaseOrder record {|
    @xmldata:Name {value: "OrderId"}
    string orderId;
    @xmldata:Name {value: "Supplier"}
    Supplier supplier;
    @xmldata:Name {value: "LineItems"}
    LineItems lineItems;
    @xmldata:Name {value: "Currency"}
    string currency;
    @xmldata:Name {value: "RequestedDeliveryDate"}
    string requestedDeliveryDate;
|};

public type Supplier record {|
    @xmldata:Name {value: "SupplierId"}
    string supplierId;
    @xmldata:Name {value: "SupplierName"}
    string supplierName;
    @xmldata:Name {value: "Country"}
    string country;
|};

public type LineItems record {|
    @xmldata:Name {value: "Item"}
    LineItem[] item;
|};

public type LineItem record {|
    @xmldata:Attribute
    string itemCode;
    @xmldata:Attribute
    decimal quantity;
    @xmldata:Name {value: "Description"}
    string description;
    @xmldata:Name {value: "UnitPrice"}
    decimal unitPrice;
|};

@xmldata:Namespace {
    uri: "http://procurement.company.com/schema"
}
public type ProcessedOrder record {|
    @xmldata:Name {value: "OrderId"}
    string orderId;
    @xmldata:Name {value: "Supplier"}
    Supplier supplier;
    @xmldata:Name {value: "LineItems"}
    LineItems lineItems;
    @xmldata:Name {value: "Currency"}
    string currency;
    @xmldata:Name {value: "RequestedDeliveryDate"}
    string requestedDeliveryDate;
    @xmldata:Name {value: "TotalOrderValue"}
    decimal totalOrderValue;
|};
