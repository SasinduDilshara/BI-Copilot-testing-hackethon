import ballerina/http;
import ballerina/sql;

configurable int servicePort = 8080;

listener http:Listener orderListener = new (servicePort);

function init() returns error? {
    check initializeDatabase();
}

service /reporting on orderListener {

    # Returns orders matching the given optional filters.
    #
    # + customerName - Optional customer name filter
    # + status - Optional order status filter
    # + fromDate - Optional inclusive start date filter (YYYY-MM-DD)
    # + toDate - Optional inclusive end date filter (YYYY-MM-DD)
    # + return - Matching orders, or an error response
    resource function get orders(string? customerName = (), string? status = (),
            string? fromDate = (), string? toDate = ())
            returns Order[]|http:InternalServerError {
        sql:ParameterizedQuery ordersQuery = buildOrdersQuery(customerName, status, fromDate, toDate);
        stream<Order, sql:Error?> orderStream = dbClient->query(ordersQuery);

        Order[]|error orders = from Order 'order in orderStream
            select 'order;

        if orders is error {
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve orders: " + orders.message()}
            };
        }
        return orders;
    }
}
