import ballerinax/java.jms;

// Registers a pending transfer awaiting correlation, tracks its outcome once the core-banking
// system replies, and matches inbound replies against transfers that are still pending.
isolated class PendingTransferRegistry {
    private final map<PendingTransfer> pendingTransfers = {};

    isolated function register(string transferId) {
        lock {
            self.pendingTransfers[transferId] = {
                transferId,
                status: "PENDING",
                coreStatus: (),
                coreMessage: ()
            };
        }
    }

    // Attempts to correlate an inbound reply to a pending transfer. Returns true only when a
    // matching pending transfer was found and updated, false if the reply is unmatched.
    isolated function correlate(string transferId, string coreStatus, string? coreMessage) returns boolean {
        lock {
            if !self.pendingTransfers.hasKey(transferId) {
                return false;
            }
            PendingTransferStatus resolvedStatus = coreStatus == "SUCCESS" ? "COMPLETED" : "FAILED";
            self.pendingTransfers[transferId] = {
                transferId,
                status: resolvedStatus,
                coreStatus,
                coreMessage
            };
            return true;
        }
    }

    isolated function get(string transferId) returns PendingTransfer? {
        lock {
            return self.pendingTransfers[transferId].clone();
        }
    }
}

final PendingTransferRegistry pendingTransferRegistry = new;

// Sends the transfer request to the core-banking system as a JMS text message.
function sendTransferRequest(TransferRequest transferRequest) returns error? {
    pendingTransferRegistry.register(transferRequest.transferId);

    string payload = transferRequest.toJsonString();
    jms:TextMessage textMessage = {
        content: payload,
        correlationId: transferRequest.transferId,
        jmsType: "CORE_TRANSFER"
    };

    check coreTransferRequestProducer->send(textMessage);
}
