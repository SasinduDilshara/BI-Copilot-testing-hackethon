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
function buildOrdersQuery(string? customerName, string? status, string? fromDate, string? toDate)
        returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `SELECT order_id, customer_name, status, order_date, amount FROM orders`;
    sql:ParameterizedQuery[] conditions = [];

    if customerName is string {
        conditions.push(`customer_name = ${customerName}`);
    }
    if status is string {
        conditions.push(`status = ${status}`);
    }
    if fromDate is string {
        conditions.push(`order_date >= ${fromDate}`);
    }
    if toDate is string {
        conditions.push(`order_date <= ${toDate}`);
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
