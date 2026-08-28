import ballerina/log;
import ballerinax/solace;

# Consumes disruption events (DELAY and CANCELLATION flight events) from the durable queue
# `AIRLINE.OPS.DISRUPTIONS` with guaranteed delivery and client acknowledgement.
@solace:ServiceConfig {
    queueName: disruptionsQueueName,
    ackMode: solace:CLIENT_ACK,
    messageSelector: "eventType = 'DELAY' OR eventType = 'CANCELLATION'",
    transportWindowSize: disruptionsTransportWindowSize
}
service on disruptionsListener {

    # Invoked for every disruption event delivered from the disruptions queue. The message is
    # acknowledged only after the disruption has been fully processed, and negatively acknowledged
    # otherwise depending on whether the failure is transient or permanent.
    #
    # + message - The disruption event message, with the payload data-bound into `FlightEvent`
    # + caller - Handle used to acknowledge or negatively acknowledge the message
    # + return - A `solace:Error` if acknowledgement/negative-acknowledgement itself fails
    remote function onMessage(DisruptionEventMessage message, solace:Caller caller) returns solace:Error? {
        FlightEvent flightEvent = message.payload;

        TransientProcessingError|PermanentProcessingError? processingResult = processDisruptionEvent(flightEvent);

        if processingResult is TransientProcessingError {
            log:printWarn("Transient failure while processing disruption event, requeuing",
                    eventId = flightEvent.eventId, 'error = processingResult);
            check caller->nack(message, requeue = true);
            return;
        }

        if processingResult is PermanentProcessingError {
            log:printError("Permanent failure while processing disruption event, not requeuing",
                    eventId = flightEvent.eventId, 'error = processingResult);
            check caller->nack(message, requeue = false);
            return;
        }

        check caller->ack(message);
        log:printInfo("Disruption event processed and acknowledged", eventId = flightEvent.eventId);
    }

    # Invoked when a delivered message cannot be dispatched to `onMessage`, most commonly because the
    # underlying guaranteed consumer flow is disrupted. The flow-down and inactive-flow conditions are
    # handled explicitly with distinct log messages and recovery behaviour.
    #
    # + err - The failure that prevented dispatch
    remote function onError(solace:Error err) returns solace:Error? {
        if err is solace:FlowDownError {
            log:printError("Disruptions consumer flow is down; the underlying connection was lost " +
                    "and the flow will be re-established once connectivity is restored", 'error = err);
            return;
        }

        if err is solace:InactiveFlowError {
            log:printWarn("Disruptions consumer flow is inactive; another instance in the client " +
                    "cluster is likely active and this instance will remain on standby", 'error = err);
            return;
        }

        log:printError("Unexpected error while consuming disruption events", 'error = err);
    }
}
