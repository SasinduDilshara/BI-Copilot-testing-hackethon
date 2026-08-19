import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;

// Fetches the order row using primary-first, replica-fallback strategy.
function fetchOrderWithFailover(int orderId) returns Order|sql:NoRowsError|sql:Error {
    sql:ParameterizedQuery orderQuery = `SELECT order_id AS orderId, customer_id AS customerId,
        order_status AS orderStatus, total_amount AS totalAmount, created_at AS createdAt
        FROM orders WHERE order_id = ${orderId}`;

    sql:Error lastError = error sql:Error("No database clients configured");
    foreach mysql:Client dbClient in orderedDbClients {
        Order|sql:Error result = dbClient->queryRow(orderQuery);
        if result is Order {
            return result;
        }
        if result is sql:NoRowsError {
            return result;
        }
        lastError = result;
        log:printWarn("Database client unavailable, attempting next data source", 'error = result);
    }
    return lastError;
}

// Fetches the customer row using primary-first, replica-fallback strategy.
function fetchCustomerWithFailover(int customerId) returns Customer|sql:NoRowsError|sql:Error {
    sql:ParameterizedQuery customerQuery = `SELECT customer_id AS customerId, first_name AS firstName,
        last_name AS lastName, email AS email, phone AS phone
        FROM customers WHERE customer_id = ${customerId}`;

    sql:Error lastError = error sql:Error("No database clients configured");
    foreach mysql:Client dbClient in orderedDbClients {
        Customer|sql:Error result = dbClient->queryRow(customerQuery);
        if result is Customer {
            return result;
        }
        if result is sql:NoRowsError {
            return result;
        }
        lastError = result;
        log:printWarn("Database client unavailable, attempting next data source", 'error = result);
    }
    return lastError;
}

// Fetches the order line items using primary-first, replica-fallback strategy.
function fetchOrderItemsWithFailover(int orderId) returns OrderItem[]|sql:Error {
    sql:ParameterizedQuery itemsQuery = `SELECT order_item_id AS orderItemId, product_id AS productId,
        product_name AS productName, quantity AS quantity, unit_price AS unitPrice,
        line_total AS lineTotal
        FROM order_items WHERE order_id = ${orderId}`;

    sql:Error lastError = error sql:Error("No database clients configured");
    foreach mysql:Client dbClient in orderedDbClients {
        stream<OrderItem, sql:Error?> itemStream = dbClient->query(itemsQuery);
        OrderItem[]|sql:Error items = from OrderItem item in itemStream
            select item;
        check itemStream.close();
        if items is OrderItem[] {
            return items;
        }
        lastError = items;
        log:printWarn("Database client unavailable, attempting next data source", 'error = items);
    }
    return lastError;
}

// Composes the full order details (order, customer, and line items) for the
// given order identifier.
function getOrderDetails(int orderId) returns OrderDetails|sql:NoRowsError|sql:Error {
    Order orderRecord = check fetchOrderWithFailover(orderId);
    Customer customer = check fetchCustomerWithFailover(orderRecord.customerId);
    OrderItem[] lineItems = check fetchOrderItemsWithFailover(orderId);

    OrderDetails orderDetails = {
        orderId: orderRecord.orderId,
        orderStatus: orderRecord.orderStatus,
        totalAmount: orderRecord.totalAmount,
        createdAt: orderRecord.createdAt,
        customer,
        lineItems
    };
    return orderDetails;
}
