import ballerina/http;
import ballerinax/rabbitmq;

function init() returns error? {
    check initNotificationsTopology();
}

service /notifications on new http:Listener(httpListenerPort) {

    # Accepts a multi-tenant notification dispatch request and publishes it to the
    # `notifications.broadcast` direct exchange. Urgency picks the destination: an `urgent`
    # notification is published once with routing key "urgent" and reaches only
    # `notifications.urgent`, bypassing its normally selected channels entirely. Any other
    # urgency is published once per selected channel, with routing key "email"/"push", so it
    # reaches only that channel's queue. The tenant ID and notification ID are carried in the
    # message headers so destination consumers can apply per-tenant handling and dedupe
    # redeliveries without deserializing the payload.
    #
    # + notificationRequest - the notification dispatch request payload
    # + return - 202 Accepted with the destinations the notification was routed to, or a 500 if
    # publishing failed
    resource function post .(NotificationRequest notificationRequest)
            returns http:Accepted|http:InternalServerError {
        NotificationChannel[] destinations = resolveDestinations(notificationRequest);

        foreach NotificationChannel destination in destinations {
            rabbitmq:BasicProperties properties = {
                correlationId: notificationRequest.notificationId,
                contentType: "application/json",
                headers: {
                    [TENANT_ID_HEADER]: notificationRequest.tenantId,
                    [NOTIFICATION_ID_HEADER]: notificationRequest.notificationId
                }
            };

            rabbitmq:AnydataMessage notificationMessage = {
                content: notificationRequest,
                routingKey: destination,
                exchange: NOTIFICATIONS_EXCHANGE,
                properties: properties
            };

            rabbitmq:Error? publishResult = rabbitmqClient->publishMessage(notificationMessage);
            if publishResult is rabbitmq:Error {
                ErrorMessage errorMessage = {
                    message: "Failed to publish notification to " + destination + ": " + publishResult.message()
                };
                return <http:InternalServerError>{body: errorMessage};
            }
        }

        NotificationAccepted notificationAccepted = {
            notificationId: notificationRequest.notificationId,
            tenantId: notificationRequest.tenantId,
            routedTo: destinations
        };
        return <http:Accepted>{body: notificationAccepted};
    }

    # Reports the delivery status of a notification: which channels have completed delivery so
    # far, based on the in-memory delivery tracker each channel consumer records into.
    #
    # + notificationId - the notification to look up
    # + return - 200 OK with the recorded per-channel deliveries, or 404 if nothing has been
    # recorded for this notification yet
    resource function get [string notificationId]() returns NotificationStatus|http:NotFound {
        ChannelDelivery[] deliveries = getDeliveries(notificationId);
        if deliveries.length() == 0 {
            ErrorMessage errorMessage = {message: string `No deliveries recorded for notification ${notificationId}`};
            return <http:NotFound>{body: errorMessage};
        }
        return {notificationId, deliveries};
    }
}
