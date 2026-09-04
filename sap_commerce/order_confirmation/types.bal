// Request payload sent by SAP Commerce to WSO2 when a new order is created.
public type OrderNotificationRequest record {|
    string orderId;
|};

// Simplified, safe representation of a product line item extracted from the SAP Commerce order.
public type OrderLineItem record {|
    string productCode;
    string productName;
    int quantity;
    decimal unitPrice;
    string currency;
    decimal totalPrice;
|};

// Simplified, safe representation of the shipping address extracted from the SAP Commerce order.
public type ShippingAddress record {|
    string firstName;
    string lastName;
    string line1;
    string line2;
    string town;
    string postalCode;
    string country;
|};

// Canonical, null-safe representation of the SAP Commerce order used internally for transformation and email generation.
public type OrderSummary record {|
    string orderId;
    string customerName;
    string customerEmail;
    string orderStatus;
    ShippingAddress shippingAddress;
    OrderLineItem[] lineItems;
    decimal totalPrice;
    string currency;
|};

// JSON response returned to SAP Commerce indicating whether the order notification was processed successfully.
public type OrderProcessingResponse record {|
    string orderId;
    string status;
    string message;
|};
