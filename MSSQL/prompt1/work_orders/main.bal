import ballerina/http;
import ballerina/log;

service /workorders on new http:Listener(8080) {

    // Receives technician work-order completion events from the field-service
    // mobile app and persists them via a local transaction against the
    // work-order database, queuing a compensating decrement-stock message for
    // the inventory service.
    resource function post complete(@http:Payload WorkOrderCompletionEvent event)
            returns CompletionAccepted|CompletionIncidentReported|CompletionDeadLettered|http:InternalServerError {
        CompletionPersisted|CompletionReportedAsIncident|CompletionSentToDlq|error outcome =
            processWorkOrderCompletion(event);

        if outcome is CompletionPersisted {
            return {workOrderId: event.workOrderId, status: "COMPLETED"};
        } else if outcome is CompletionReportedAsIncident {
            return {
                workOrderId: event.workOrderId,
                status: "INCIDENT_REPORTED",
                reason: outcome.cause.message()
            };
        } else if outcome is CompletionSentToDlq {
            return <CompletionDeadLettered>{
                workOrderId: event.workOrderId,
                status: "DEAD_LETTERED",
                reason: outcome.cause.message()
            };
        } else {
            error processingError = <error>outcome;
            log:printError("Failed to persist work-order completion, and failed to report incident or dead-letter it",
                    workOrderId = event.workOrderId, 'error = processingError);
            return <http:InternalServerError>{
                body: {
                    workOrderId: event.workOrderId,
                    message: "Failed to persist work-order completion event"
                }
            };
        }
    }
}
