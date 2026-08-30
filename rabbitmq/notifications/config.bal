configurable string rabbitmqHost = "localhost";
configurable int rabbitmqPort = 5672;
configurable string rabbitmqVhost = "/";
configurable string rabbitmqUsername = ?;
configurable string rabbitmqPassword = ?;

configurable int httpListenerPort = 8080;

# Number of unacknowledged messages each destination consumer will prefetch. Each destination
# has its own listener/QoS so one destination's backlog cannot starve another.
configurable int emailPrefetchCount = 10;
configurable int pushPrefetchCount = 20;
configurable int urgentPrefetchCount = 20;

# Maximum number of notifications a single tenant may have dispatched, per destination, within
# `rateLimitWindowSeconds`. Exceeding this causes the message to be requeued (not dropped) so
# it is retried once the tenant's window rolls over.
configurable int tenantRateLimitPerWindow = 100;
configurable decimal rateLimitWindowSeconds = 60;

# Direct exchange that routes each notification to exactly one destination queue based on its
# routing key. Urgency picks the destination: urgent notifications are routed only to
# `notifications.urgent` (routing key "urgent"); everything else is routed to the queue matching
# each selected channel (routing key "email"/"push"), one publish per selected channel.
const string NOTIFICATIONS_EXCHANGE = "notifications.broadcast";

const string NOTIFICATIONS_EMAIL_QUEUE = "notifications.email";
const string NOTIFICATIONS_PUSH_QUEUE = "notifications.push";
const string NOTIFICATIONS_URGENT_QUEUE = "notifications.urgent";

# RabbitMQ queue argument that selects the quorum queue type. Quorum queues are durable,
# Raft-replicated queues (RabbitMQ 3.8+) and are declared with `durable: true`.
const string ARG_QUEUE_TYPE = "x-queue-type";
const string QUEUE_TYPE_QUORUM = "quorum";

# Custom application header carrying the tenant that a notification belongs to, so downstream
# consumers can apply per-tenant handling without deserializing the payload.
const string TENANT_ID_HEADER = "x-tenant-id";

# Custom application header carrying the notificationId, so consumers can track/dedupe
# deliveries without deserializing the payload.
const string NOTIFICATION_ID_HEADER = "x-notification-id";
