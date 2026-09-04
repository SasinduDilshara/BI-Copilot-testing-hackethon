import ballerina/data.csv;
import ballerina/io;

public type OrderLine record {|
    @csv:Name {value: "Order ID"}
    string orderId;
    @csv:Name {value: "SKU"}
    string sku;
    @csv:Name {value: "Quantity"}
    int qty;
    @csv:Name {value: "Unit Price"}
    decimal unitPrice;
|};

public function main() returns error? {
    // A fully valid CSV file - all rows should bind and pass validation,
    // exactly like the whole-file binding ftp:onFileCsv(OrderLine[], ...) would use internally.
    string validCsv = string `Order ID,SKU,Quantity,Unit Price
ORD-1001,SKU-1,3,9.99
ORD-1002,SKU-2,1,19.50
ORD-1003,SKU-1,2,9.99`;

    io:println("--- Valid file whole-array bind test (simulates onFileCsv(OrderLine[])) ---");
    OrderLine[]|error validOrderLines = csv:parseString(validCsv);
    if validOrderLines is error {
        io:println("UNEXPECTED bind failure: ", validOrderLines.message());
    } else {
        foreach OrderLine orderLine in validOrderLines {
            io:println(orderLine.toString());
        }
        io:println("bound rows: ", validOrderLines.length());
    }

    // A CSV file with a malformed row (non-numeric quantity) at physical line 3.
    string[] headerFields = ["Order ID", "SKU", "Quantity", "Unit Price"];
    string[][] malformedDataRows = [
        ["ORD-2001", "SKU-1", "notanumber", "9.99"],
        ["ORD-2002", "SKU-2", "2", "15.00"]
    ];

    io:println("--- Malformed file row-by-row test (simulates stream<OrderLine, error?> semantics) ---");
    int physicalLine = 2;
    foreach string[] dataRow in malformedDataRows {
        string[][] singleRowCsv = [headerFields, dataRow];
        OrderLine[]|error rowResult = csv:parseList(singleRowCsv, {headerRows: 1});
        if rowResult is error {
            io:println("line ", physicalLine, " -> BIND ERROR: ", rowResult.message());
        } else {
            io:println("line ", physicalLine, " -> ", rowResult[0].toString());
        }
        physicalLine += 1;
    }
}
