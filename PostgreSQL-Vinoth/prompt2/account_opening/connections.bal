
import ballerina/http;

final http:Client identityClient = check new (identityApiUrl,
    timeout = 12,
    retryConfig = {count: 2, interval: 3}
);