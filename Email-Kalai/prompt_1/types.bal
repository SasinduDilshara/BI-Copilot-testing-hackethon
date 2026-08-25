// Request payload representing an order confirmation request.
type OrderConfirmationRequest record {|
    string orderId;
    string customerEmail;
    string customerName;
    string productName;
    int quantity;
    decimal unitPrice;
    decimal totalAmount;
    string shippingAddress;
|};

// Response returned after attempting to send the order confirmation email.
type OrderConfirmationResponse record {|
    string orderId;
    "sent"|"failed" status;
    string errorMessage?;
|};
