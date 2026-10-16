import ballerina/http;
import ballerina/log;

service /partner on new http:Listener(servicePort) {

    // Calls the partner REST API's resource at the given path and returns its JSON response.
    // The outbound call to partnerApiClient is automatically authenticated with an OAuth2
    // bearer access token obtained via the client-credentials grant.
    resource function get lookup(string path) returns json|http:InternalServerError {
        json|http:ClientError response = partnerApiClient->get(path);
        if response is http:ClientError {
            log:printError("Error calling partner API", 'error = response);
            return <http:InternalServerError>{
                body: {message: "Failed to call partner API"}
            };
        }
        return response;
    }
}
