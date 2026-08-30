import ballerinax/kafka;

// Records a payment as settled in the bounded history used by the status
// endpoint. If the history is already at capacity, the oldest entry is
// evicted first so the underlying storage never grows unbounded.
function recordSettledPayment(string paymentId) {
    settledPaymentHistory.recordSettled(paymentId);
}

// Looks up whether a paymentId is still present in the bounded settled-payment
// history, used by the reconciliation status endpoint. Returns `()` once the
// payment has aged out of the retained history.
function getSettledPaymentTimestamp(string paymentId) returns int? {
    return settledPaymentHistory.getSettledAt(paymentId);
}

// Builds the health snapshot for the monitoring consumer's assigned
// partitions: the last committed offset and the current lag, with the lag
// derived exactly as (end offset - committed offset) using the connector's
// own offset APIs rather than an estimate.
function getSettlementHealth() returns SettlementHealth|error {
    kafka:TopicPartition[] assignedPartitions =
        check settlementMonitoringConsumer->getTopicPartitions(PAYMENTS_AUTHORIZED_TOPIC);
    kafka:PartitionOffset[] endOffsets = check settlementMonitoringConsumer->getEndOffsets(assignedPartitions);

    map<int> endOffsetByPartition = {};
    foreach kafka:PartitionOffset endOffset in endOffsets {
        string partitionKey = endOffset.partition.topic + ":" + endOffset.partition.partition.toString();
        endOffsetByPartition[partitionKey] = endOffset.offset;
    }

    PartitionLag[] partitionLags = [];
    foreach kafka:TopicPartition topicPartition in assignedPartitions {
        kafka:PartitionOffset|error? committedOffsetResult =
            settlementMonitoringConsumer->getCommittedOffset(topicPartition);

        int? committedOffset = ();
        if committedOffsetResult is kafka:PartitionOffset {
            committedOffset = committedOffsetResult.offset;
        }

        string partitionKey = topicPartition.topic + ":" + topicPartition.partition.toString();
        int endOffset = endOffsetByPartition.get(partitionKey);
        int lag = committedOffset is int ? endOffset - committedOffset : endOffset;

        partitionLags.push({
            topic: topicPartition.topic,
            partition: topicPartition.partition,
            committedOffset: committedOffset,
            endOffset: endOffset,
            lag: lag
        });
    }

    return {partitions: partitionLags};
}
