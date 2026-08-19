import ballerina/http;

final http:Client adjudicationClient = check new (adjudicationApiUrl,
    timeout = 15,
    retryConfig = {count: 2, interval: 3}
);
