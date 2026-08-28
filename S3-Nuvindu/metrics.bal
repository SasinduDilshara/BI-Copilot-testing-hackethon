import ballerina/log;
import ballerina/observe;

// Operational metrics for the S3 event consumer, so the operations team can monitor the
// integration's health via the configured metrics reporter (e.g. Prometheus), in addition to
// the structured logs. These are only populated when observability is enabled at runtime
// (`--observability-included` build flag and `[b7a.observability.metrics] enabled=true` in
// Config.toml); see the deployment notes for details.
final observe:Counter messagesProcessedCounter = new ("s3_events_messages_processed_total",
        desc = "Number of S3 event notification messages processed successfully");
final observe:Counter processingFailuresCounter = new ("s3_events_processing_failures_total",
        desc = "Number of S3 event notification messages that failed processing and were left for retry");
final observe:Counter messagesSentToDlqCounter = new ("s3_events_messages_sent_to_dlq_total",
        desc = "Number of messages that reached the maximum receive count and were moved to the dead-letter queue");

// Registers the metrics with the global metrics registry so they are picked up by the
// configured metrics reporter. Safe to call once at startup.
function initializeMetrics() {
    error? processedRegisterResult = messagesProcessedCounter.register();
    if processedRegisterResult is error {
        log:printWarn("Failed to register messagesProcessedCounter metric", processedRegisterResult);
    }
    error? failuresRegisterResult = processingFailuresCounter.register();
    if failuresRegisterResult is error {
        log:printWarn("Failed to register processingFailuresCounter metric", failuresRegisterResult);
    }
    error? dlqRegisterResult = messagesSentToDlqCounter.register();
    if dlqRegisterResult is error {
        log:printWarn("Failed to register messagesSentToDlqCounter metric", dlqRegisterResult);
    }
}
