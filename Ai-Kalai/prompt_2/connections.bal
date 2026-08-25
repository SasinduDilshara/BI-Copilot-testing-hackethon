import ballerina/http;

configurable string sanctionsApiUrl = "http://sanctions-api.internal";

final http:Client sanctionsCheckClient = check new (sanctionsApiUrl);
