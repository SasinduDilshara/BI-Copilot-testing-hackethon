configurable string rabbitmqHost = "localhost";
configurable int rabbitmqPort = 5672;
configurable string rabbitmqVhost = "/";
configurable string rabbitmqUsername = ?;
configurable string rabbitmqPassword = ?;

# Additional broker nodes the client can fail over to if the primary (`rabbitmqHost`:`rabbitmqPort`)
# is unreachable. Each entry is a "host:port" pair, e.g. ["broker2.example.com:5672"].
configurable string[] rabbitmqFailoverAddresses = [];

configurable int httpListenerPort = 8080;

# Routing key / queue name that inventory reservation requests are published to.
const string INVENTORY_RESERVE_QUEUE = "inventory.reserve";

# Durable, shared queue that inventory reservation replies are published back to. The reply
# consumer correlates each reply to its originating saga using the message's correlation ID.
const string FULFILMENT_REPLIES_QUEUE = "fulfilment.replies";
