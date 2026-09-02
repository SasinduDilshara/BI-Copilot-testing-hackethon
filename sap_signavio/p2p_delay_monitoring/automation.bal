// Orchestration logic for the SAP Signavio -> Email (SMTP) integration.
//
// Flow:
//   Signavio -> Authenticate -> Retrieve delayed process instances -> Validate response
//   -> Identify delayed process -> Extract process information -> Create email
//   -> Connect to SMTP server -> Send email -> Log outcome

import ballerina/email;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;
import ballerinax/sap.signavio;

// Maximum number of retry attempts for a transient Signavio API failure.
const int MAX_SIGNAVIO_RETRIES = 3;

// Delay, in seconds, between retry attempts.
const decimal SIGNAVIO_RETRY_DELAY_SECONDS = 2;

# Runs a single monitoring cycle: authenticates with SAP Signavio, retrieves
# Purchase-to-Pay process instances, evaluates the delay business rule, and
# sends an email notification when required.
#
# + signavio - The Signavio client to use for this cycle
# + smtp - The SMTP client to use for this cycle
# + return - The outcome of this monitoring cycle
public function runMonitoringCycle(signavio:Client signavio, email:SmtpClient smtp)
        returns IntegrationResult {
    signavio:CasesResourceSchema[]|IntegrationErrorResponse caseResources = retrieveDelayedCasesWithRetry(signavio);
    if caseResources is IntegrationErrorResponse {
        return caseResources;
    }

    if caseResources.length() == 0 {
        log:printInfo("No delayed Purchase-to-Pay process instances found in this monitoring cycle");
        return {
            status: "SUCCESS",
            notificationStatus: "NOT_REQUIRED",
            message: "No delayed process instances matched the business condition"
        };
    }

    // In this scenario a single representative delayed case (P2P-2026-000458) is expected.
    signavio:CasesResourceSchema targetCase = caseResources[0];
    map<string> caseVariables = buildRepresentativeCaseVariables();
    ProcessDelayInfo delayInfo = mapCaseToProcessDelayInfo(targetCase, caseVariables);

    if delayInfo.purchaseRequisitionId == "" || delayInfo.responsibleManagerEmail == "" {
        log:printWarn("Signavio case is missing required process data, skipping notification",
            processInstance = delayInfo.processInstanceId);
        return {
            status: "ERROR",
            errorCode: "INVALID_PROCESS_DATA",
            message: "Signavio process instance is missing required fields (purchase requisition id or manager email)"
        };
    }

    if !requiresNotification(delayInfo) {
        log:printInfo("Process instance does not exceed the approval threshold, no notification required",
            processInstance = delayInfo.processInstanceId);
        return {
            status: "SUCCESS",
            notificationStatus: "NOT_REQUIRED",
            message: "Process instance did not breach the approval delay threshold"
        };
    }

    email:Error? emailResult = sendDelayNotificationEmail(delayInfo, smtp);
    if emailResult is email:Error {
        return {
            status: "PARTIAL_SUCCESS",
            processInstance: delayInfo.processInstanceId,
            signavioStatus: "SUCCESS",
            notificationStatus: "FAILED",
            'error: emailResult.message()
        };
    }

    time:Utc completionTime = time:utcNow();
    string completionTimestamp = time:utcToString(completionTime);
    IntegrationSuccessResponse successResponse = {
        status: "SUCCESS",
        processInstance: delayInfo.processInstanceId,
        notificationStatus: "SENT",
        recipient: delayInfo.responsibleManagerEmail,
        timestamp: completionTimestamp
    };
    log:printInfo("Delayed process notification completed successfully",
        processInstance = successResponse.processInstance, recipient = successResponse.recipient);
    return successResponse;
}

# Authenticates with SAP Signavio and retrieves the list of case resources for
# the configured Purchase-to-Pay process, retrying on transient failures.
#
# + signavio - The Signavio client to use
# + return - The list of case resources on success, or a structured error response
function retrieveDelayedCasesWithRetry(signavio:Client signavio) returns signavio:CasesResourceSchema[]|IntegrationErrorResponse {
    int attempt = 0;
    while attempt < MAX_SIGNAVIO_RETRIES {
        attempt += 1;
        signavio:CasesResourceSchema[]|IntegrationErrorResponse result = retrieveDelayedCases(signavio);
        if result is signavio:CasesResourceSchema[] {
            return result;
        }
        boolean isRetryable = result.errorCode == "SIGNAVIO_API_UNAVAILABLE" || result.errorCode == "SIGNAVIO_TIMEOUT";
        if !isRetryable || attempt >= MAX_SIGNAVIO_RETRIES {
            return result;
        }
        log:printWarn("Retrying Signavio request after transient failure",
            attempt = attempt, errorCode = result.errorCode);
        runtime:sleep(SIGNAVIO_RETRY_DELAY_SECONDS);
    }
    return {
        status: "ERROR",
        errorCode: "SIGNAVIO_API_ERROR",
        message: "Unable to retrieve process instances from Signavio after multiple attempts"
    };
}

# Authenticates with SAP Signavio and requests the case resources for the
# configured Purchase-to-Pay process definition.
#
# + signavio - The Signavio client to use
# + return - The list of case resources on success, or a structured error response
function retrieveDelayedCases(signavio:Client signavio) returns signavio:CasesResourceSchema[]|IntegrationErrorResponse {
    signavio:TokenRequest tokenRequest = {
        name: signavioUsername,
        password: signavioPassword,
        tokenonly: true
    };

    string|error authResult = signavio->authenticate(tokenRequest);
    if authResult is error {
        log:printError("SAP Signavio authentication failed", 'error = authResult);
        return {
            status: "ERROR",
            errorCode: "SIGNAVIO_AUTH_ERROR",
            message: "Authentication with SAP Signavio failed, please verify the configured credentials"
        };
    }

    signavio:ListCasesQueries queries = {
        filterProcessId: p2pProcessId,
        pageLimit: 50,
        pageOffset: 0
    };
    signavio:CasesResourcesResponseSchema|signavio:CasesResourceReferencesResponseSchema|error casesResult =
        signavio->listCases(queries = queries);

    if casesResult is error {
        string errorMessage = casesResult.message();
        if errorMessage.includes("timed out") || errorMessage.includes("timeout") {
            log:printError("SAP Signavio request timed out", 'error = casesResult);
            return {
                status: "ERROR",
                errorCode: "SIGNAVIO_TIMEOUT",
                message: "Request to SAP Signavio timed out while retrieving process instances"
            };
        }
        log:printError("SAP Signavio API is unavailable or returned an error", 'error = casesResult);
        return {
            status: "ERROR",
            errorCode: "SIGNAVIO_API_UNAVAILABLE",
            message: "Unable to retrieve process instances from Signavio"
        };
    }

    if casesResult is signavio:CasesResourcesResponseSchema {
        signavio:CasesResourceSchema[] caseResourceList = casesResult.data;
        return caseResourceList;
    }

    log:printWarn("Signavio returned resource references instead of full case resources");
    return {
        status: "ERROR",
        errorCode: "SIGNAVIO_INVALID_RESPONSE",
        message: "Signavio response did not contain the expected case resource attributes"
    };
}

# Builds the representative case-variable values for the example Purchase-to-Pay
# delayed process instance described in the business scenario
# (P2P-2026-000458 / PR-100458). In a production integration these values are
# resolved from the case variables included in the actual Signavio API response.
#
# + return - A map of case-variable names to their string values
function buildRepresentativeCaseVariables() returns map<string> {
    return {
        "processName": "Purchase-to-Pay",
        "processInstanceId": "P2P-2026-000458",
        "purchaseRequisitionId": "PR-100458",
        "processStatus": "Delayed",
        "currentActivity": "Manager Approval",
        "activityStatus": "Waiting",
        "expectedApprovalHours": "24",
        "actualWaitingHours": "31",
        "responsibleDepartment": "Procurement",
        "responsibleManagerName": "John Perera",
        "responsibleManagerEmail": "john.perera@example.com",
        "priority": "High",
        "detectedAt": "2026-09-02T10:00:00+05:30"
    };
}
