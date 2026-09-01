// Registry of live WebSocket connections for /tickets/live and the broadcast
// helper used by the HTTP resources whenever a ticket is created or updated.

import ballerina/log;
import ballerina/websocket;

public enum TicketEventType {
    TICKET_CREATED = "TICKET_CREATED",
    TICKET_UPDATED = "TICKET_UPDATED"
}

public type TicketEvent record {|
    TicketEventType eventType;
    Ticket ticket;
|};

isolated map<websocket:Caller> ticketSubscribers = {};

isolated function registerTicketSubscriber(websocket:Caller caller) {
    lock {
        ticketSubscribers[caller.getConnectionId()] = caller;
    }
}

isolated function deregisterTicketSubscriber(websocket:Caller caller) {
    lock {
        _ = ticketSubscribers.removeIfHasKey(caller.getConnectionId());
    }
}

// Sends the given ticket event to every currently connected agent.
isolated function broadcastTicketEvent(TicketEventType eventType, Ticket ticket) {
    lock {
        TicketEvent ticketEvent = {eventType, ticket: ticket.clone()};
        string[] staleConnectionIds = [];
        foreach websocket:Caller activeCaller in ticketSubscribers {
            if !activeCaller.isOpen() {
                staleConnectionIds.push(activeCaller.getConnectionId());
                continue;
            }
            websocket:Error? sendResult = activeCaller->writeMessage(ticketEvent);
            if sendResult is websocket:Error {
                log:printWarn("failed to push ticket event to subscriber",
                    connectionId = activeCaller.getConnectionId(), 'error = sendResult);
            }
        }
        foreach string staleConnectionId in staleConnectionIds {
            _ = ticketSubscribers.removeIfHasKey(staleConnectionId);
        }
    }
}
