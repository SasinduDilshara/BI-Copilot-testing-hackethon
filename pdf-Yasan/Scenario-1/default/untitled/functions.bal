// Builds a clean HTML invoice document from the invoice request.
function buildInvoiceHtml(InvoiceRequest invoiceRequest) returns string {
    decimal total = 0;
    string rowsHtml = "";
    foreach InvoiceLine line in invoiceRequest.lines {
        decimal lineTotal = <decimal>line.qty * line.unitPrice;
        total += lineTotal;
        rowsHtml += string `<tr>
            <td>${line.description}</td>
            <td class="numeric">${line.qty}</td>
            <td class="numeric">${line.unitPrice}</td>
            <td class="numeric">${lineTotal}</td>
        </tr>`;
    }

    string html = string `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<style>
    body { font-family: sans-serif; color: #222222; }
    h1 { font-size: 20px; margin-bottom: 4px; }
    .customer { font-size: 14px; margin-bottom: 2px; }
    .issued-on { font-size: 12px; color: #555555; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th, td { border: 1px solid #cccccc; padding: 6px 8px; font-size: 12px; }
    th { background-color: #f2f2f2; text-align: left; }
    td.numeric, th.numeric { text-align: right; }
    tfoot td { font-weight: bold; }
</style>
</head>
<body>
    <h1>Invoice ${invoiceRequest.invoiceNo}</h1>
    <div class="customer">Customer: ${invoiceRequest.customer}</div>
    <div class="issued-on">Issued on: ${invoiceRequest.issuedOn}</div>
    <table>
        <thead>
            <tr>
                <th>Description</th>
                <th class="numeric">Qty</th>
                <th class="numeric">Unit Price</th>
                <th class="numeric">Line Total</th>
            </tr>
        </thead>
        <tbody>
            ${rowsHtml}
        </tbody>
        <tfoot>
            <tr>
                <td colspan="3">Total</td>
                <td class="numeric">${total}</td>
            </tr>
        </tfoot>
    </table>
</body>
</html>`;
    return html;
}
