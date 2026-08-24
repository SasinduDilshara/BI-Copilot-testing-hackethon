// Builds a plain text invoice document for the given order.
function buildInvoiceText(OrderConfirmationRequest orderRequest, string invoiceDate) returns string {
    string invoiceText = string `INVOICE

Invoice Date: ${invoiceDate}
Order ID: ${orderRequest.orderId}

Product: ${orderRequest.productName}
Quantity: ${orderRequest.quantity}
Unit Price: ${orderRequest.unitPrice}
Total Amount: ${orderRequest.totalAmount}

Thank you for your business.`;
    return invoiceText;
}

// Builds the plain text fallback body for the order confirmation email.
function buildPlainTextBody(OrderConfirmationRequest orderRequest) returns string {
    string plainTextBody = string `Order Confirmation

Dear ${orderRequest.customerName},

Thank you for your order. Here are your order details:

Order ID: ${orderRequest.orderId}
Product: ${orderRequest.productName}
Quantity: ${orderRequest.quantity}
Unit Price: ${orderRequest.unitPrice}
Total Amount: ${orderRequest.totalAmount}
Shipping Address: ${orderRequest.shippingAddress}

If you have any questions, please contact support@company.com.

Thank you for shopping with us.`;
    return plainTextBody;
}

// Builds the HTML formatted order confirmation receipt body.
function buildHtmlBody(OrderConfirmationRequest orderRequest) returns string {
    string htmlBody = string `<html>
<head>
<style>
  body { font-family: Arial, sans-serif; color: #333333; }
  .receipt { border: 1px solid #dddddd; border-collapse: collapse; width: 100%; max-width: 600px; }
  .receipt th, .receipt td { border: 1px solid #dddddd; padding: 8px 12px; text-align: left; }
  .receipt th { background-color: #f5f5f5; }
  .header { color: #2c3e50; }
</style>
</head>
<body>
  <h2 class="header">Order Confirmation Receipt</h2>
  <p>Dear ${orderRequest.customerName},</p>
  <p>Thank you for your order. Please find your order details below.</p>
  <table class="receipt">
    <tr><th>Order ID</th><td>${orderRequest.orderId}</td></tr>
    <tr><th>Product</th><td>${orderRequest.productName}</td></tr>
    <tr><th>Quantity</th><td>${orderRequest.quantity}</td></tr>
    <tr><th>Unit Price</th><td>${orderRequest.unitPrice}</td></tr>
    <tr><th>Total Amount</th><td>${orderRequest.totalAmount}</td></tr>
    <tr><th>Shipping Address</th><td>${orderRequest.shippingAddress}</td></tr>
  </table>
  <p>If you have any questions, please contact <a href="mailto:support@company.com">support@company.com</a>.</p>
  <p>Thank you for shopping with us.</p>
</body>
</html>`;
    return htmlBody;
}
