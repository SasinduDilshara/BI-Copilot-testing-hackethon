// Data mapping: transforms a raw SAP Signavio "case" (process instance) resource
// into the domain-level ProcessDelayInfo record used by this integration.
//
// NOTE: SAP Signavio Process Intelligence models custom process attributes
// (purchase requisition id, responsible manager, approval hours, etc.) as
// case variables attached to a case resource. The exact variable names below
// (processName, purchaseRequisitionId, expectedApprovalHours, ...) are
// REPRESENTATIVE/EXAMPLE variable names configured for the Purchase-to-Pay
// process in this company's Signavio workspace, not a fixed/official schema.

import ballerinax/sap.signavio;

# Extracts a human readable process instance identifier from a Signavio case
# resource. Falls back to the raw case id timestamp field when a dedicated
# business identifier is not present.
#
# + caseResource - The raw case resource returned by Signavio `listCases`
# + return - The resolved process instance identifier
function extractProcessInstanceId(signavio:CasesResourceSchema caseResource) returns string {
    string? caseIdDate = caseResource.id.date;
    if caseIdDate is string {
        return caseIdDate;
    }
    return "";
}

# Maps a single Signavio cases resource entry together with its resolved
# case-variable values into a ProcessDelayInfo record.
#
# + caseResource - The raw case resource returned by Signavio `listCases`
# + caseVariables - Resolved case variable name/value pairs for this case
# + return - The mapped process delay information
function mapCaseToProcessDelayInfo(signavio:CasesResourceSchema caseResource, map<string> caseVariables)
        returns ProcessDelayInfo => {
    processName: caseVariables.hasKey("processName") ? caseVariables.get("processName") : "Purchase-to-Pay",
    processInstanceId: extractProcessInstanceId(caseResource),
    purchaseRequisitionId: caseVariables.hasKey("purchaseRequisitionId") ? caseVariables.get("purchaseRequisitionId") : "",
    processStatus: caseVariables.hasKey("processStatus") ? caseVariables.get("processStatus") : "Delayed",
    currentActivity: caseVariables.hasKey("currentActivity") ? caseVariables.get("currentActivity") : "Manager Approval",
    activityStatus: caseVariables.hasKey("activityStatus") ? caseVariables.get("activityStatus") : "Waiting",
    expectedApprovalHours: caseVariables.hasKey("expectedApprovalHours") ?
        checkpanic decimal:fromString(caseVariables.get("expectedApprovalHours")) : 24,
    actualWaitingHours: caseVariables.hasKey("actualWaitingHours") ?
        checkpanic decimal:fromString(caseVariables.get("actualWaitingHours")) : 0,
    delayHours: caseVariables.hasKey("actualWaitingHours") && caseVariables.hasKey("expectedApprovalHours") ?
        checkpanic decimal:fromString(caseVariables.get("actualWaitingHours")) -
            checkpanic decimal:fromString(caseVariables.get("expectedApprovalHours")) : 0,
    responsibleDepartment: caseVariables.hasKey("responsibleDepartment") ? caseVariables.get("responsibleDepartment") : "Procurement",
    responsibleManagerName: caseVariables.hasKey("responsibleManagerName") ? caseVariables.get("responsibleManagerName") : "",
    responsibleManagerEmail: caseVariables.hasKey("responsibleManagerEmail") ? caseVariables.get("responsibleManagerEmail") : "",
    priority: caseVariables.hasKey("priority") ? caseVariables.get("priority") : "Normal",
    detectedAt: caseVariables.hasKey("detectedAt") ? caseVariables.get("detectedAt") : ""
};
