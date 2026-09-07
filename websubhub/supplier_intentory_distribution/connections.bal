import ballerina/websubhub;

final websubhub:PublisherClient publisherClient = check new (hubUrl);
