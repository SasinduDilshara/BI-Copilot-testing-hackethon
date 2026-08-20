import ballerina/http;
import ballerina/sql;
import ballerina/time;

listener http:Listener orderServiceListener = new (8080);

service /orders on orderServiceListener {

    // Retrieves an order along with its customer details and line items.
    resource function get [int orderId]() returns OrderDetails|http:NotFound|http:InternalServerError {
        OrderDetails|sql:NoRowsError|sql:Error|time:Error result = getOrderDetails(orderId);

        if result is OrderDetails {
            return result;
        }

        if result is sql:NoRowsError {
            ErrorDetails notFoundDetails = {
                message: string `Order with id ${orderId} was not found`,
                timestamp: time:utcToString(time:utcNow()),
                path: string `/orders/${orderId}`
            };
            return <http:NotFound>{body: notFoundDetails};
        }

        ErrorDetails errorDetails = {
            message: "Unable to retrieve order details at this time",
            timestamp: time:utcToString(time:utcNow()),
            path: string `/orders/${orderId}`
        };
        return <http:InternalServerError>{body: errorDetails};
    }
}
