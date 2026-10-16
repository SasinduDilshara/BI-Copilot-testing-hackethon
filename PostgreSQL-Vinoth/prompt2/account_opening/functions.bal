
import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/sql;

const int maxDbRetryAttempts = 2;
const decimal dbRetryBaseDelay = 0.3;

function verifyIdentity(AccountApplication app) returns error? {
    IdentityCheckRequest req = {
        applicationId: app.applicationId,
        fullName: app.fullName,
        dateOfBirth: app.dateOfBirth,
        countryCode: app.countryCode
    };
    http:Response _ = check identityClient->post("/verify", req,
        {"Authorization": "Bearer " + identityApiKey});
}

function persistApplication(AccountApplication app) returns error? {
    sql:ParameterizedQuery query = `INSERT INTO applications
        (application_id, customer_id, country_code, full_name, date_of_birth)
        VALUES (${app.applicationId}, ${app.customerId}, ${app.countryCode},
                 ${app.fullName}, ${app.dateOfBirth})`;
    sql:ExecutionResult _ = check dbClient->execute(query);
}

function persistFlaggedApplication(AccountApplication app, AmlRiskResult riskResult) returns error? {
    sql:ParameterizedQuery query = `INSERT INTO flagged_applications
        (application_id, customer_id, country_code, full_name, date_of_birth, risk_score, is_flagged)
        VALUES (${app.applicationId}, ${app.customerId}, ${app.countryCode},
                 ${app.fullName}, ${app.dateOfBirth}, ${riskResult.riskScore}, ${riskResult.isFlagged})`;
    sql:ExecutionResult _ = check dbClient->execute(query);
}

function deadLetterApplication(AccountApplication app, string reason) returns error? {
    sql:ParameterizedQuery query = `INSERT INTO applications_dlq
        (application_id, customer_id, country_code, full_name, date_of_birth, failure_reason)
        VALUES (${app.applicationId}, ${app.customerId}, ${app.countryCode},
                 ${app.fullName}, ${app.dateOfBirth}, ${reason})`;
    sql:ExecutionResult _ = check dbClient->execute(query);
}

function evaluateAmlRisk(AccountApplication app) returns AmlRiskResult|error {
    sql:InOutParameter riskScoreParam = new (0);
    sql:InOutParameter isFlaggedParam = new (false);

    sql:ParameterizedCallQuery callQuery = `call evaluate_aml_risk(${app.customerId}, ${app.countryCode},
        ${riskScoreParam}, ${isFlaggedParam})`;
    sql:ProcedureCallResult callResult = check dbClient->call(callQuery);
    check callResult.close();

    int riskScore = check riskScoreParam.get(int);
    boolean isFlagged = check isFlaggedParam.get(boolean);
    return {riskScore, isFlagged};
}

function evaluateAmlRiskWithRetry(AccountApplication app) returns AmlRiskResult|error {
    int attempt = 0;
    while true {
        AmlRiskResult|error result = evaluateAmlRisk(app);
        if result is AmlRiskResult {
            return result;
        }
        if attempt >= maxDbRetryAttempts {
            return result;
        }
        decimal delay = dbRetryBaseDelay * (2 ^ attempt);
        log:printWarn(string `AML risk evaluation failed for ${app.applicationId}, retrying in ${delay}s`,
                'error = result);
        runtime:sleep(delay);
        attempt += 1;
    }
}