import ballerina/log;
import ballerina/smb;

@smb:ServiceConfig {
    path: "/inbound"
}
service "orderIntake" on orderIntakeListener {

    // Raw rows are bound here (instead of an OrderLine[] record array) because the CSV header
    // names ('Order ID', 'SKU', 'Quantity', 'Unit Price') do not match the OrderLine field
    // identifiers, so the module's header-to-field record binding cannot be used directly.
    @smb:FunctionConfig {
        afterProcess: {moveTo: "/archive"},
        afterError: {moveTo: "/error"}
    }
    remote function onFileCsv(string[][] content, smb:FileInfo fileInfo, smb:Caller caller) returns error? {
        if content.length() == 0 {
            return error(string `${fileInfo.name} has no header row`);
        }

        string[] header = content[0];
        if header != expectedOrderHeader {
            return error(string `${fileInfo.name} has an unexpected header: ${header.toString()}`);
        }

        OrderLine[] orderLines = [];
        foreach int rowIndex in 1 ..< content.length() {
            string[] row = content[rowIndex];
            OrderLine|error orderLine = bindOrderLine(row);
            if orderLine is error {
                log:printError(string `malformed row in ${fileInfo.name} at line ${rowIndex + 1}: ${row.toString()}`,
                        'error = orderLine);
                return error(string `malformed row in ${fileInfo.name} at line ${rowIndex + 1}`, orderLine);
            }
            error? validationError = validateOrderLine(orderLine);
            if validationError is error {
                log:printError(string `invalid row in ${fileInfo.name} at line ${rowIndex + 1}: ${row.toString()}`,
                        'error = validationError);
                return error(string `invalid row in ${fileInfo.name} at line ${rowIndex + 1}`, validationError);
            }
            orderLines.push(orderLine);
        }

        OrderSummary summary = summarizeOrderLines(fileInfo.name, orderLines);
        string summaryPath = string `/processed/${fileInfo.name}.summary.json`;
        check orderIntakeClient->putJson(summaryPath, summary.toJson(), smb:OVERWRITE);

        log:printInfo(string `processed ${fileInfo.name}: ${summary.orderCount} orders, grand total ${summary.grandTotal}`);
    }

    remote function onError(smb:Error err, smb:Caller caller) returns error? {
        log:printError("SMB order intake listener failure", 'error = err);
    }
}
