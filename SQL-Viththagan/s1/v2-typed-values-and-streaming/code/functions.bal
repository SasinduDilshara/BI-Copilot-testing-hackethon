import ballerina/sql;

// Creates the orders table and seeds it with sample data if not already present.
function initializeDatabase() returns error? {
    _ = check dbClient->execute(`CREATE TABLE IF NOT EXISTS orders (
                                    order_id INT AUTO_INCREMENT,
                                    customer_name VARCHAR(255),
                                    status VARCHAR(50),
                                    order_date DATE,
                                    amount DECIMAL(10,2),
                                    PRIMARY KEY (order_id)
                                )`);

    int existingCount = check dbClient->queryRow(`SELECT COUNT(*) FROM orders`);
    if existingCount > 0 {
        return;
    }

    sql:ParameterizedQuery[] seedData = [
        `INSERT INTO orders (customer_name, status, order_date, amount)
            VALUES ('Alice Johnson', 'PENDING', '2024-01-05', 120.50)`,
        `INSERT INTO orders (customer_name, status, order_date, amount)
            VALUES ('Bob Smith', 'SHIPPED', '2024-02-10', 75.00)`,
        `INSERT INTO orders (customer_name, status, order_date, amount)
            VALUES ('Alice Johnson', 'DELIVERED', '2024-03-15', 220.99)`,
        `INSERT INTO orders (customer_name, status, order_date, amount)
            VALUES ('Carol White', 'CANCELLED', '2024-01-20', 50.25)`,
        `INSERT INTO orders (customer_name, status, order_date, amount)
            VALUES ('Bob Smith', 'PENDING', '2024-04-01', 310.10)`
    ];
    _ = check dbClient->batchExecute(seedData);
}

// Builds the parameterized SELECT query for orders by dynamically composing
// optional filters as bound parameters, without concatenating raw values.
// Each value is bound using the sql:TypedValue subtype matching its exact JDBC
// column type so the driver does not have to infer the SQL type.
function buildOrdersQuery(string? customerName, string? status, string? fromDate, string? toDate)
        returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `SELECT order_id, customer_name, status, order_date, amount FROM orders`;
    sql:ParameterizedQuery[] conditions = [];

    if customerName is string {
        sql:VarcharValue customerNameValue = new (customerName);
        conditions.push(`customer_name = ${customerNameValue}`);
    }
    if status is string {
        sql:VarcharValue statusValue = new (status);
        conditions.push(`status = ${statusValue}`);
    }
    if fromDate is string {
        sql:DateValue fromDateValue = new (fromDate);
        conditions.push(`order_date >= ${fromDateValue}`);
    }
    if toDate is string {
        sql:DateValue toDateValue = new (toDate);
        conditions.push(`order_date <= ${toDateValue}`);
    }

    if conditions.length() == 0 {
        return query;
    }

    sql:ParameterizedQuery whereClause = ` WHERE `;
    foreach int i in 0 ..< conditions.length() {
        if i > 0 {
            whereClause = sql:queryConcat(whereClause, ` AND `);
        }
        whereClause = sql:queryConcat(whereClause, conditions[i]);
    }

    return sql:queryConcat(query, whereClause);
}

// Executes the given orders query against the database and streams the
// result set row by row from the JDBC cursor, rather than having the driver
// materialize the full result set upfront. The underlying stream is always
// closed - whether iteration completes normally or fails partway through.
function fetchOrders(sql:ParameterizedQuery ordersQuery) returns Order[]|error {
    stream<Order, sql:Error?> orderStream = dbClient->query(ordersQuery);
    Order[] orders = [];

    error? iterationError = from Order 'order in orderStream
        do {
            orders.push('order);
        };

    check orderStream.close();

    if iterationError is error {
        return iterationError;
    }
    return orders;
}

// Fetches a single order by its identifier. Returns () when no matching row
// exists so callers can translate that into a clean 404 response.
function getOrderById(int orderId) returns Order|error? {
    sql:IntegerValue orderIdValue = new (orderId);
    sql:ParameterizedQuery orderQuery = `SELECT order_id, customer_name, status, order_date, amount
                                            FROM orders WHERE order_id = ${orderIdValue}`;
    Order|sql:Error result = dbClient->queryRow(orderQuery);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return result;
}
