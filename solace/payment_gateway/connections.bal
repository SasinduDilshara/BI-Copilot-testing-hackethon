import ballerinax/solace;

final solace:MessageProducer paymentInstructionProducer = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = {
        username: solaceUsername,
        password: solacePassword
    }
);

// Non-transacted listener for the settlement consumer, consuming from PAYMENTS.INSTRUCTIONS.IN
// with CLIENT_ACK. The message is only acknowledged once the outbound publish (to the settlement
// queue or the DLQ) has completed successfully - see processSettlement in functions.bal. This
// gives at-least-once delivery: a crash between the outbound publish and the ack causes the
// instruction to be redelivered, which is why the delivery-count based redelivery check in
// functions.bal exists (instead of committing to atomicity via a transacted session).
listener solace:Listener settlementListener = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = {
        username: solaceUsername,
        password: solacePassword
    }
);

// Producer used by the settlement consumer to publish onto PAYMENTS.SETTLEMENT.OUT and
// PAYMENTS.INSTRUCTIONS.DLQ before the source message is acknowledged.
final solace:MessageProducer settlementProducer = check new (solaceBrokerUrl,
    messageVpn = solaceVpnName,
    auth = {
        username: solaceUsername,
        password: solacePassword
    }
);
