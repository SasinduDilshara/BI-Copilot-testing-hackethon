
import ballerina/http;
import ballerina/log;

service /accounts on new http:Listener(servicePort) {
    resource function post apply(@http:Payload AccountApplication app)
            returns http:Accepted|http:InternalServerError {
        error? result = verifyIdentity(app);
        if result is error {
            log:printError(string `Identity check failed for ${app.applicationId}`, 'error = result);
            return <http:InternalServerError>{body: "Identity verification failed"};
        }
        return <http:Accepted>{body: string `Application ${app.applicationId} received`};
    }
}