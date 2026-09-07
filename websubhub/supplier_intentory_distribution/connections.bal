import ballerina/http;
import ballerina/websubhub;

final websubhub:PublisherClient publisherClient = check new (hubUrl);

// Shared HTTP listener for the publisher-side stock update endpoint and the admin views.
listener http:Listener publisherListener = new (publisherPort);
