import ballerina/time;
import ballerinax/kafka;

// Represents an authorized payment event consumed from the `payments.authorized` Kafka topic.
public type PaymentAuthorized record {|
    string paymentId;
    string orderId;
    string merchantId;
    decimal amount;
    string currency;
|};

// Represents a Kafka consumer record whose value is bound to the `PaymentAuthorized` type.
public type PaymentAuthorizedConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    PaymentAuthorized value;
|};

// Represents a settlement event ready for publishing to the `payments.settlement` topic.
public type PaymentSettlement record {|
    string paymentId;
    string orderId;
    string merchantId;
    decimal amount;
    string currency;
|};

// Reports that a given paymentId was found among the last N settled payments
// retained in memory, along with when it was settled.
public type SettlementStatus record {|
    string paymentId;
    boolean settled;
    int? settledAtEpochSeconds;
|};

// Bounded, insertion-ordered, thread-safe history of settled paymentIds. Once
// the configured capacity is reached, the oldest entry is evicted first. All
// mutable state is encapsulated behind this class's own lock so callers never
// need to reason about locking two related isolated variables together.
public isolated class SettledPaymentHistory {
    private final int capacity;
    private map<int> settledAtByPaymentId = {};
    private string[] insertionOrder = [];

    public isolated function init(int capacity) {
        self.capacity = capacity;
    }

    // Records a payment as settled now, evicting the oldest entry first if
    // the history is already at capacity.
    public isolated function recordSettled(string paymentId) {
        lock {
            int nowEpochSeconds = time:utcNow()[0];
            if !self.settledAtByPaymentId.hasKey(paymentId) {
                self.insertionOrder.push(paymentId);
            }
            self.settledAtByPaymentId[paymentId] = nowEpochSeconds;

            while self.insertionOrder.length() > self.capacity {
                string oldestPaymentId = self.insertionOrder.shift();
                // Only evict from the map if this is still its recorded slot;
                // a later re-settlement of the same paymentId already
                // re-pushed it to the end of the order list, so an earlier
                // stale entry for it must not evict the fresh one.
                boolean stillPending = false;
                foreach string pendingPaymentId in self.insertionOrder {
                    if pendingPaymentId == oldestPaymentId {
                        stillPending = true;
                        break;
                    }
                }
                if !stillPending {
                    _ = self.settledAtByPaymentId.removeIfHasKey(oldestPaymentId);
                }
            }
        }
    }

    // Returns the epoch-second timestamp the paymentId was last settled at,
    // or `()` if it is unknown or has aged out of the retained history.
    public isolated function getSettledAt(string paymentId) returns int? {
        lock {
            return self.settledAtByPaymentId[paymentId];
        }
    }
}

// Lag information for a single assigned partition.
public type PartitionLag record {|
    string topic;
    int partition;
    int? committedOffset;
    int endOffset;
    int lag;
|};

// Health snapshot of the monitoring consumer.
public type SettlementHealth record {|
    PartitionLag[] partitions;
|};
