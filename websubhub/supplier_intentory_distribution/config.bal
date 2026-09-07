// Configuration values for the supplier inventory WebSub hub and publisher.

configurable string hubUrl = ?;
configurable string topicUrl = ?;
configurable int hubPort = ?;
configurable int publisherPort = ?;
configurable int leaseSeconds = ?;
configurable string[] allowedCallbackHosts = ?;
configurable string subscriptionSecret = ?;
