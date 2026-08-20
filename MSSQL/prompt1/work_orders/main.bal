import ballerina/http;
import ballerina/log;

service /workorders on new http:Listener(8080) {

    // Receives technician work-order completion events from the field-service
    // mobile app and persists them via a distributed transaction across the
    // work-order and parts-inventory databases.
    resource function post complete(@http:Payload WorkOrderCompletionEvent event)
            returns CompletionAccepted|CompletionDeadLettered|http:InternalServerError {
        CompletionPersisted|CompletionSentToDlq|error outcome = processWorkOrderCompletion(event);

        if outcome is CompletionPersisted {
            return {workOrderId: event.workOrderId, status: "COMPLETED"};
        }

        if outcome is CompletionSentToDlq {
            return {
                workOrderId: event.workOrderId,
                status: "DEAD_LETTERED",
                reason: outcome.cause.message()
            };
        }

        log:printError("Failed to persist work-order completion, and failed to dead-letter it",
                workOrderId = event.workOrderId, 'error = outcome);
        return <http:InternalServerError>{
            body: {
                workOrderId: event.workOrderId,
                message: "Failed to persist work-order completion event"
            }
        };
    }
}
