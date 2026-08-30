import ballerina/test;

// Builds a valid authorized payment event used as the baseline for tests.
function buildValidPaymentAuthorized(string paymentId) returns PaymentAuthorized => {
    paymentId: paymentId,
    orderId: "ORD-2001",
    merchantId: "MERCH-77",
    amount: 249.50d,
    currency: "USD"
};

@test:Config {}
function testRecordSettledPaymentIsRetrievable() {
    string paymentId = "PAY-HISTORY-1";
    recordSettledPayment(paymentId);
    int? settledAt = getSettledPaymentTimestamp(paymentId);
    test:assertTrue(settledAt is int, msg = "A recorded settlement should be retrievable by paymentId");
}

@test:Config {}
function testGetSettledPaymentTimestampReturnsNilForUnknownPayment() {
    int? settledAt = getSettledPaymentTimestamp("PAY-NEVER-SEEN");
    test:assertTrue(settledAt is (), msg = "An unknown paymentId should not have a settlement record");
}

@test:Config {}
function testSettledPaymentHistoryEvictsOldestBeyondConfiguredSize() {
    string oldestPaymentId = "PAY-EVICT-0";
    int totalToInsert = settledPaymentsHistorySize + 1;
    int index = 0;
    while index < totalToInsert {
        recordSettledPayment("PAY-EVICT-" + index.toString());
        index += 1;
    }
    string newestPaymentId = "PAY-EVICT-" + (totalToInsert - 1).toString();

    int? oldestEntry = getSettledPaymentTimestamp(oldestPaymentId);
    int? newestEntry = getSettledPaymentTimestamp(newestPaymentId);
    test:assertTrue(oldestEntry is (),
            msg = "The oldest settlement should have been evicted once the history exceeded its configured size");
    test:assertTrue(newestEntry is int, msg = "The newest settlement should still be present in the history");
}

@test:Config {}
function testToPaymentSettlementMapsAllFieldsFromEvent() {
    PaymentAuthorized paymentAuthorized = buildValidPaymentAuthorized("PAY-3001");
    PaymentSettlement paymentSettlement = toPaymentSettlement(paymentAuthorized);
    test:assertEquals(paymentSettlement.paymentId, paymentAuthorized.paymentId,
            msg = "paymentId should be carried over");
    test:assertEquals(paymentSettlement.orderId, paymentAuthorized.orderId, msg = "orderId should be carried over");
    test:assertEquals(paymentSettlement.merchantId, paymentAuthorized.merchantId,
            msg = "merchantId should be carried over");
    test:assertEquals(paymentSettlement.amount, paymentAuthorized.amount, msg = "amount should be carried over");
    test:assertEquals(paymentSettlement.currency, paymentAuthorized.currency,
            msg = "currency should be carried over");
}
