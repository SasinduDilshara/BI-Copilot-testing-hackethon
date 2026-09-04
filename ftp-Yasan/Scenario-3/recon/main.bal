import ballerina/ftp;
import ballerina/io;
import ballerina/data.csv;

type Order record {|
    @csv:Name {value: "Order ID"} string orderId;
    @csv:Name {value: "SKU"} string sku;
    @csv:Name {value: "Quantity"} int qty;
|};

type Shipment record {|
    @csv:Name {value: "Order ID"} string orderId;
    @csv:Name {value: "Shipped"} int shipped;
|};

// Reconciles the day's orders against what actually shipped and reports the
// orders that were SHORT-shipped (fewer units shipped than ordered), plus the
// total shortfall quantity across those orders.
public function main() returns error? {
    ftp:Client recon = check new ({
        protocol: ftp:SFTP,
        host: sftpHost,
        port: sftpPort,
        auth: {credentials: {username: sftpUsername}, privateKey: {path: sftpPrivateKeyPath}}
    });

    Order[] orders = check recon->getCsv("/recon/orders.csv");
    Shipment[] shipments = check recon->getCsv("/recon/shipped.csv");

    map<int> shippedByOrder = {};
    foreach Shipment s in shipments {
        shippedByOrder[s.orderId] = s.shipped;
    }

    int shortShippedCount = 0;
    int totalShortfall = 0;
    foreach Order o in orders {
        int shipped = shippedByOrder[o.orderId] ?: 0;
        if shipped < o.qty {
            shortShippedCount += 1;
            totalShortfall += o.qty - shipped;
            io:println("SHORT: ", o.orderId, " ordered=", o.qty, " shipped=", shipped);
        }
    }
    io:println("Short-shipped orders: ", shortShippedCount, " | Total shortfall: ", totalShortfall);
}
