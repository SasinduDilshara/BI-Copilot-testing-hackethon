import ballerina/http;
import ballerinax/kafka;
import ballerinax/mssql;
import ballerinax/mssql.driver as _;

// Secure-socket configuration: encryption is enforced and the server
// certificate is validated against the configured truststore instead of
// accepting the driver defaults (trustServerCertificate is left false).
final mssql:Options mssqlSecureOptions = {
    secureSocket: {
        encrypt: true,
        trustServerCertificate: false,
        cert: {
            path: sqlServerTrustStorePath,
            password: sqlServerTrustStorePassword
        }
    }
};

// Client for the work-order database (work_order_completions, outbox, and DLQ
// tables). This is the only database touched directly by this service - no
// distributed/XA transaction is required since parts_inventory is now updated
// asynchronously by the inventory service via a queued message. No fixed port
// is supplied - the named instance is resolved dynamically via SQL Browser.
final mssql:Client workOrdersDbClient = check new (
    host = sqlServerHost,
    user = sqlServerUser,
    password = sqlServerPassword,
    database = workOrdersDatabase,
    instance = sqlServerInstance,
    options = mssqlSecureOptions
);

// Producer used to publish compensating decrement-stock messages to the
// inventory service. enableIdempotence guards against duplicate delivery
// caused by producer-side retries at the Kafka client/broker level.
final kafka:Producer decrementStockProducer = check new (kafkaBootstrapServers, {
    clientId: "work-orders-decrement-stock-producer",
    acks: "all",
    retryCount: 3,
    enableIdempotence: true
});

// Client used to page on-call by calling the existing incidents webhook when
// the work-order completion transaction fails even after retries.
final http:Client incidentsServiceClient = check new (incidentsServiceUrl);
