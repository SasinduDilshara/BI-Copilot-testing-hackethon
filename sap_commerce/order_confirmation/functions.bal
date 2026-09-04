import ballerina/email;
import ballerina/log;
import ballerinax/sap.commerce.webservices as sapcommerce;

// Resolves the display name of the customer, falling back to the email or a generic label
// when the name fields are not present in the SAP Commerce response.
function resolveCustomerName(sapcommerce:User? customer) returns string {
    if customer is () {
        return "Valued Customer";
    }
    string? firstName = customer?.firstName;
    string? lastName = customer?.lastName;
    if firstName is string && lastName is string {
        return firstName + " " + lastName;
    }
    string? name = customer?.name;
    if name is string {
        return name;
    }
    string? email = customer?.email;
    if email is string {
        return email;
    }
    return "Valued Customer";
}

// Resolves the customer email address, preferring the SAP customer email and falling back
// to the customer profile email when required.
function resolveCustomerEmail(sapcommerce:Order sapOrder) returns string? {
    string? sapCustomerEmail = sapOrder.sapCustomerEmail;
    if sapCustomerEmail is string && sapCustomerEmail.trim().length() > 0 {
        return sapCustomerEmail;
    }
    sapcommerce:User? customer = sapOrder.orgCustomer;
    if customer is sapcommerce:User {
        return customer?.email;
    }
    return ();
}

// Maps a SAP Commerce delivery address into the internal, null-safe shipping address representation.
function mapShippingAddress(sapcommerce:Address? deliveryAddress) returns ShippingAddress => {
    firstName: deliveryAddress is sapcommerce:Address ? deliveryAddress.firstName : "",
    lastName: deliveryAddress is sapcommerce:Address ? deliveryAddress.lastName : "",
    line1: deliveryAddress is sapcommerce:Address ? deliveryAddress.line1 : "",
    line2: deliveryAddress?.line2 ?: "",
    town: deliveryAddress is sapcommerce:Address ? deliveryAddress.town : "",
    postalCode: deliveryAddress is sapcommerce:Address ? deliveryAddress.postalCode : "",
    country: deliveryAddress?.country?.name ?: (deliveryAddress?.country?.isocode ?: "")
};

// Maps a single SAP Commerce order entry into an internal, null-safe order line item.
function mapOrderLineItem(sapcommerce:OrderEntry orderEntry) returns OrderLineItem {
    sapcommerce:Product? product = orderEntry.product;
    string productCode = product?.code ?: "UNKNOWN";
    string productName = product?.name ?: productCode;
    int quantity = orderEntry.quantity ?: 0;
    sapcommerce:Price? basePrice = orderEntry.basePrice;
    decimal unitPrice = basePrice?.value ?: 0d;
    string currency = basePrice?.currencyIso ?: "";
    sapcommerce:Price? totalPriceValue = orderEntry.totalPrice;
    decimal totalPrice = totalPriceValue?.value ?: (unitPrice * <decimal>quantity);
    return {
        productCode,
        productName,
        quantity,
        unitPrice,
        currency,
        totalPrice
    };
}

// Transforms the complete SAP Commerce order response into the internal, null-safe order summary
// used for building the confirmation email.
function toOrderSummary(sapcommerce:Order sapOrder) returns OrderSummary|error {
    string? orderCode = sapOrder.code;
    if orderCode is () {
        return error("SAP Commerce order response is missing the order code");
    }

    string? customerEmail = resolveCustomerEmail(sapOrder);
    if customerEmail is () {
        return error("SAP Commerce order response is missing the customer email");
    }

    sapcommerce:OrderEntry[] entries = sapOrder.entries ?: [];
    OrderLineItem[] lineItems = from sapcommerce:OrderEntry orderEntry in entries
        select mapOrderLineItem(orderEntry);

    sapcommerce:Price? totalPriceValue = sapOrder.totalPrice;
    decimal totalPrice = totalPriceValue?.value ?: 0d;
    string currency = totalPriceValue?.currencyIso ?: "";

    return {
        orderId: orderCode,
        customerName: resolveCustomerName(sapOrder.orgCustomer),
        customerEmail,
        orderStatus: sapOrder.status ?: "UNKNOWN",
        shippingAddress: mapShippingAddress(sapOrder.deliveryAddress),
        lineItems,
        totalPrice,
        currency
    };
}

// Retrieves the complete order details for the given order id from SAP Commerce.
function fetchOrderDetails(string orderId) returns sapcommerce:Order|error {
    sapcommerce:Order|xml|error result = sapCommerceClient->getOrder(sapCommerceBaseSiteId, orderId);
    if result is error {
        log:printError("Failed to retrieve order details from SAP Commerce", 'error = result, orderId = orderId);
        return result;
    }
    if result is xml {
        return error("Unexpected XML response received from SAP Commerce for order " + orderId);
    }
    return result;
}

// Builds the plain-text body of the order confirmation email from the order summary.
function buildOrderConfirmationEmailBody(OrderSummary orderSummary) returns string {
    string itemLines = "";
    foreach OrderLineItem lineItem in orderSummary.lineItems {
        itemLines += string `  - ${lineItem.productName} (${lineItem.productCode}) x${lineItem.quantity} @ ${lineItem.unitPrice} ${lineItem.currency} = ${lineItem.totalPrice} ${lineItem.currency}` + "\n";
    }

    ShippingAddress shippingAddress = orderSummary.shippingAddress;
    string addressBlock = string `${shippingAddress.firstName} ${shippingAddress.lastName}
${shippingAddress.line1}${shippingAddress.line2.length() > 0 ? " " + shippingAddress.line2 : ""}
${shippingAddress.town} ${shippingAddress.postalCode}
${shippingAddress.country}`;

    string body = string `Dear ${orderSummary.customerName},

Thank you for your order! Here are your order details:

Order Number: ${orderSummary.orderId}
Order Status: ${orderSummary.orderStatus}

Ordered Products:
${itemLines}
Total Amount: ${orderSummary.totalPrice} ${orderSummary.currency}

Shipping Address:
${addressBlock}

Thank you for shopping with us!
`;
    return body;
}

// Sends the order confirmation email to the customer using the transformed order summary.
function sendOrderConfirmationEmail(OrderSummary orderSummary) returns error? {
    string emailBody = buildOrderConfirmationEmailBody(orderSummary);
    email:Message confirmationEmail = {
        to: [orderSummary.customerEmail],
        subject: string `Order Confirmation - ${orderSummary.orderId}`,
        body: emailBody,
        'from: smtpSenderEmail
    };

    email:Error? sendResult = smtpClient->sendMessage(confirmationEmail);
    if sendResult is email:Error {
        log:printError("Failed to send order confirmation email", 'error = sendResult, orderId = orderSummary.orderId, customerEmail = orderSummary.customerEmail);
        return sendResult;
    }
    log:printInfo("Order confirmation email sent successfully", orderId = orderSummary.orderId, customerEmail = orderSummary.customerEmail);
    return ();
}
