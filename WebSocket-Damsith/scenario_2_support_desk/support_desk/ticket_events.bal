// Registry of live WebSocket connections for /tickets/live and the broadcast
// helper used by the HTTP resources whenever a ticket is created or updated.
// Each connection tracks the set of queues (ticket assignedTo values) the
// agent currently wants pushed to them, so a ticket event only reaches
// agents who are subscribed to that ticket's queue.

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

// Action a connected agent can send, over the same connection, to change
// which queues are pushed to them without reconnecting.
public enum QueueSubscriptionAction {
    SUBSCRIBE = "SUBSCRIBE",
    UNSUBSCRIBE = "UNSUBSCRIBE",
    REPLACE = "REPLACE"
}

public type QueueSubscriptionUpdate record {|
    QueueSubscriptionAction action;
    string[] queues;
|};

public type QueueSubscriptionAck record {|
    string ackType = "SUBSCRIPTION_ACK";
    string[] subscribedQueues;
|};

type TicketSubscriber record {|
    websocket:Caller caller;
    string[] subscribedQueues;
|};

isolated map<TicketSubscriber> ticketSubscribers = {};

isolated function registerTicketSubscriber(websocket:Caller caller, string[] initialQueues) {
    lock {
        ticketSubscribers[caller.getConnectionId()] = {caller, subscribedQueues: initialQueues.clone()};
    }
}

isolated function deregisterTicketSubscriber(websocket:Caller caller) {
    lock {
        _ = ticketSubscribers.removeIfHasKey(caller.getConnectionId());
    }
}

// Applies a subscription change sent by an agent over an existing connection
// and returns the resulting queue set so the caller can be acknowledged.
//
// requestedQueues is made readonly only so it can legally cross into the
// lock (isolated root) below. Inside the lock, resultingQueues is ALWAYS
// built with a query expression (`from ... select`), never `.clone()`.
// A query expression always constructs a brand-new mutable array, whereas
// `.clone()` on an already-readonly value returns that SAME readonly value
// (a no-op) - if that had been stored as subscribedQueues, a later push()
// on a "cloned" copy of it would panic with InvalidUpdate. The same applies
// to the returned array, which is why it is also produced via a readonly
// clone rather than reusing the mutable resultingQueues reference.
isolated function updateTicketSubscription(websocket:Caller caller, QueueSubscriptionUpdate subscriptionUpdate)
        returns string[] {
    QueueSubscriptionAction action = subscriptionUpdate.action;
    string[] & readonly requestedQueues = subscriptionUpdate.queues.cloneReadOnly();
    lock {
        TicketSubscriber? existingSubscriber = ticketSubscribers[caller.getConnectionId()];
        if existingSubscriber is () {
            return [];
        }
        string[] currentQueues = existingSubscriber.subscribedQueues;
        string[] resultingQueues;
        if action == REPLACE {
            resultingQueues = from string requestedQueue in requestedQueues select requestedQueue;
        } else if action == SUBSCRIBE {
            resultingQueues = from string existingQueue in currentQueues select existingQueue;
            foreach string requestedQueue in requestedQueues {
                if resultingQueues.indexOf(requestedQueue) is () {
                    resultingQueues.push(requestedQueue);
                }
            }
        } else {
            resultingQueues = from string existingQueue in currentQueues
                where requestedQueues.indexOf(existingQueue) is ()
                select existingQueue;
        }
        ticketSubscribers[caller.getConnectionId()] = {caller, subscribedQueues: resultingQueues};
        return resultingQueues.cloneReadOnly();
    }
}

// Sends the given ticket event only to agents currently subscribed to the
// ticket's queue (its assignedTo value).
isolated function broadcastTicketEvent(TicketEventType eventType, Ticket ticket) {
    lock {
        TicketEvent ticketEvent = {eventType, ticket: ticket.clone()};
        string ticketQueue = ticket.assignedTo;
        string[] staleConnectionIds = [];
        foreach TicketSubscriber subscriber in ticketSubscribers {
            websocket:Caller activeCaller = subscriber.caller;
            if !activeCaller.isOpen() {
                staleConnectionIds.push(activeCaller.getConnectionId());
                continue;
            }
            if subscriber.subscribedQueues.indexOf(ticketQueue) is () {
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
