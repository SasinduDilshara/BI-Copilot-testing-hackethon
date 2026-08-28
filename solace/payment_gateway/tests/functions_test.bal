import ballerina/test;

final PaymentInstruction validPaymentInstruction = {
    instructionId: "INSTR-001",
    debtorIban: "DE89370400440532013000",
    creditorIban: "FR1420041010050500013M02606",
    amount: 100.50d,
    currency: "EUR",
    executionDate: "2026-08-28",
    paymentScheme: "SEPA_CREDIT_TRANSFER"
};

@test:Config {}
function testValidatePaymentInstructionAcceptsValidInstruction() {
    ValidationError? result = validatePaymentInstruction(validPaymentInstruction);
    test:assertTrue(result is (), msg = "A valid payment instruction should not produce a validation error");
}

@test:Config {}
function testValidatePaymentInstructionRejectsEmptyDebtorIban() {
    PaymentInstruction paymentInstruction = {
        instructionId: "INSTR-001",
        debtorIban: "  ",
        creditorIban: "FR1420041010050500013M02606",
        amount: 100.50d,
        currency: "EUR",
        executionDate: "2026-08-28",
        paymentScheme: "SEPA_CREDIT_TRANSFER"
    };
    ValidationError? result = validatePaymentInstruction(paymentInstruction);
    test:assertTrue(result is ValidationError, msg = "An empty debtorIban should produce a validation error");
    if result is ValidationError {
        test:assertEquals(result.message(), "debtorIban must not be empty", msg = "Unexpected validation message");
    }
}

@test:Config {}
function testValidatePaymentInstructionRejectsEmptyCreditorIban() {
    PaymentInstruction paymentInstruction = {
        instructionId: "INSTR-001",
        debtorIban: "DE89370400440532013000",
        creditorIban: "",
        amount: 100.50d,
        currency: "EUR",
        executionDate: "2026-08-28",
        paymentScheme: "SEPA_CREDIT_TRANSFER"
    };
    ValidationError? result = validatePaymentInstruction(paymentInstruction);
    test:assertTrue(result is ValidationError, msg = "An empty creditorIban should produce a validation error");
    if result is ValidationError {
        test:assertEquals(result.message(), "creditorIban must not be empty", msg = "Unexpected validation message");
    }
}

@test:Config {}
function testValidatePaymentInstructionRejectsNonPositiveAmount() {
    PaymentInstruction paymentInstruction = {
        instructionId: "INSTR-001",
        debtorIban: "DE89370400440532013000",
        creditorIban: "FR1420041010050500013M02606",
        amount: 0d,
        currency: "EUR",
        executionDate: "2026-08-28",
        paymentScheme: "SEPA_CREDIT_TRANSFER"
    };
    ValidationError? result = validatePaymentInstruction(paymentInstruction);
    test:assertTrue(result is ValidationError, msg = "A non-positive amount should produce a validation error");
    if result is ValidationError {
        test:assertEquals(result.message(), "amount must be greater than zero", msg = "Unexpected validation message");
    }
}

@test:Config {}
function testValidatePaymentInstructionRejectsEmptyCurrency() {
    PaymentInstruction paymentInstruction = {
        instructionId: "INSTR-001",
        debtorIban: "DE89370400440532013000",
        creditorIban: "FR1420041010050500013M02606",
        amount: 100.50d,
        currency: "",
        executionDate: "2026-08-28",
        paymentScheme: "SEPA_CREDIT_TRANSFER"
    };
    ValidationError? result = validatePaymentInstruction(paymentInstruction);
    test:assertTrue(result is ValidationError, msg = "An empty currency should produce a validation error");
    if result is ValidationError {
        test:assertEquals(result.message(), "currency must not be empty", msg = "Unexpected validation message");
    }
}

@test:Config {}
function testValidatePaymentInstructionRejectsEmptyPaymentScheme() {
    PaymentInstruction paymentInstruction = {
        instructionId: "INSTR-001",
        debtorIban: "DE89370400440532013000",
        creditorIban: "FR1420041010050500013M02606",
        amount: 100.50d,
        currency: "EUR",
        executionDate: "2026-08-28",
        paymentScheme: " "
    };
    ValidationError? result = validatePaymentInstruction(paymentInstruction);
    test:assertTrue(result is ValidationError, msg = "An empty paymentScheme should produce a validation error");
    if result is ValidationError {
        test:assertEquals(result.message(), "paymentScheme must not be empty", msg = "Unexpected validation message");
    }
}

@test:Config {}
function testBuildSettledPaymentInstructionMapsAllFields() {
    SettledPaymentInstruction settledPaymentInstruction = buildSettledPaymentInstruction(validPaymentInstruction);
    test:assertEquals(settledPaymentInstruction.instructionId, validPaymentInstruction.instructionId,
            msg = "instructionId should be carried over");
    test:assertEquals(settledPaymentInstruction.debtorIban, validPaymentInstruction.debtorIban,
            msg = "debtorIban should be carried over");
    test:assertEquals(settledPaymentInstruction.creditorIban, validPaymentInstruction.creditorIban,
            msg = "creditorIban should be carried over");
    test:assertEquals(settledPaymentInstruction.amount, validPaymentInstruction.amount,
            msg = "amount should be carried over");
    test:assertEquals(settledPaymentInstruction.currency, validPaymentInstruction.currency,
            msg = "currency should be carried over");
    test:assertEquals(settledPaymentInstruction.executionDate, validPaymentInstruction.executionDate,
            msg = "executionDate should be carried over");
    test:assertEquals(settledPaymentInstruction.paymentScheme, validPaymentInstruction.paymentScheme,
            msg = "paymentScheme should be carried over");
}

@test:Config {}
function testBuildAuditEntryMapsAllFieldsAndStampsRecordedTime() {
    AuditEntry auditEntry = buildAuditEntry(validPaymentInstruction);
    test:assertEquals(auditEntry.instructionId, validPaymentInstruction.instructionId,
            msg = "instructionId should be carried over");
    test:assertEquals(auditEntry.debtorIban, validPaymentInstruction.debtorIban,
            msg = "debtorIban should be carried over");
    test:assertEquals(auditEntry.creditorIban, validPaymentInstruction.creditorIban,
            msg = "creditorIban should be carried over");
    test:assertEquals(auditEntry.amount, validPaymentInstruction.amount, msg = "amount should be carried over");
    test:assertEquals(auditEntry.currency, validPaymentInstruction.currency,
            msg = "currency should be carried over");
    test:assertEquals(auditEntry.executionDate, validPaymentInstruction.executionDate,
            msg = "executionDate should be carried over");
    test:assertEquals(auditEntry.paymentScheme, validPaymentInstruction.paymentScheme,
            msg = "paymentScheme should be carried over");
    test:assertTrue(auditEntry.recordedTime.trim().length() > 0,
            msg = "recordedTime should be stamped with a non-empty UTC timestamp");
}

@test:Config {}
function testIsRedeliveryFalseWhenDeliveryCountAbsent() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction};
    test:assertFalse(isRedelivery(message), msg = "A message without a deliveryCount should not be a redelivery");
}

@test:Config {}
function testIsRedeliveryFalseOnFirstDelivery() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction, deliveryCount: 1};
    test:assertFalse(isRedelivery(message), msg = "A deliveryCount of 1 should not be a redelivery");
}

@test:Config {}
function testIsRedeliveryTrueWhenDeliveryCountGreaterThanOne() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction, deliveryCount: 2};
    test:assertTrue(isRedelivery(message), msg = "A deliveryCount greater than 1 should be a redelivery");
}

@test:Config {}
function testIsPoisonMessageFalseWhenDeliveryCountAbsent() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction};
    test:assertFalse(isPoisonMessage(message),
            msg = "A message without a deliveryCount should not be treated as poison");
}

@test:Config {}
function testIsPoisonMessageFalseWhenWithinMaxDeliveryCount() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction, deliveryCount: maxDeliveryCount};
    test:assertFalse(isPoisonMessage(message),
            msg = "A deliveryCount equal to maxDeliveryCount should not be treated as poison");
}

@test:Config {}
function testIsPoisonMessageTrueWhenExceedingMaxDeliveryCount() {
    PaymentInstructionMessage message = {payload: validPaymentInstruction, deliveryCount: maxDeliveryCount + 1};
    test:assertTrue(isPoisonMessage(message),
            msg = "A deliveryCount exceeding maxDeliveryCount should be treated as poison");
}
