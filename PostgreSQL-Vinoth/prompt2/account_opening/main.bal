
import ballerina/http;
import ballerina/log;

service /accounts on new http:Listener(servicePort) {
    resource function post apply(@http:Payload AccountApplication app)
            returns http:Accepted|http:InternalServerError {
        error? persistResult = persistApplication(app);
        if persistResult is error {
            log:printError(string `Failed to persist application ${app.applicationId}`, 'error = persistResult);
            return <http:InternalServerError>{body: "Failed to persist application"};
        }

        boolean isLowRiskPartnerCountry = lowRiskPartnerCountryCodes.indexOf(app.countryCode) is int;
        if !isLowRiskPartnerCountry {
            AmlRiskResult|error riskResult = evaluateAmlRiskWithRetry(app);
            if riskResult is error {
                error? dlqResult = deadLetterApplication(app, riskResult.message());
                if dlqResult is error {
                    log:printError(string `Failed to dead-letter application ${app.applicationId}`,
                            'error = dlqResult);
                }
                log:printError(string `AML risk evaluation failed for ${app.applicationId}`, 'error = riskResult);
                return <http:InternalServerError>{body: "AML risk evaluation failed"};
            }

            if riskResult.isFlagged {
                error? flaggedResult = persistFlaggedApplication(app, riskResult);
                if flaggedResult is error {
                    log:printError(string `Failed to persist flagged application ${app.applicationId}`,
                            'error = flaggedResult);
                    return <http:InternalServerError>{body: "Failed to persist flagged application"};
                }
                return <http:Accepted>{body: string `Application ${app.applicationId} flagged for manual review`};
            }
        }

        error? result = verifyIdentity(app);
        if result is error {
            log:printError(string `Identity check failed for ${app.applicationId}`, 'error = result);
            return <http:InternalServerError>{body: "Identity verification failed"};
        }
        return <http:Accepted>{body: string `Application ${app.applicationId} received`};
    }
}