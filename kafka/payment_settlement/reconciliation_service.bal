import ballerina/http;

listener http:Listener reconciliationListener = new (reconciliationServicePort);

service /settlement on reconciliationListener {

    // Reports whether the given paymentId is present in the bounded history
    // of the last N settled payments. Returns 404 once the payment has aged
    // out of that retained history (evicted as older than the N most recent
    // settlements), since there is no persistent record of it beyond that.
    resource function get status/[string paymentId]() returns SettlementStatus|http:NotFound {
        int? settledAt = getSettledPaymentTimestamp(paymentId);
        if settledAt is () {
            return {
                body: {message: "No settlement record found for paymentId " + paymentId}
            };
        }
        return {
            paymentId: paymentId,
            settled: true,
            settledAtEpochSeconds: settledAt
        };
    }

    // Reports the monitoring consumer's assigned partitions, the last
    // committed offset per partition, and the current lag, all derived
    // directly from the Kafka consumer's offset APIs.
    resource function get health() returns SettlementHealth|http:InternalServerError {
        SettlementHealth|error health = getSettlementHealth();
        if health is error {
            return {
                body: {message: "Failed to compute settlement health: " + health.message()}
            };
        }
        return health;
    }
}
