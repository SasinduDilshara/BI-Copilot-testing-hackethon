import ballerina/http;

# HTTP service exposing the CustomerProfile schema promotion workflow.
service /schema\-registry on new http:Listener(httpListenerPort) {

    # Evaluates a candidate `CustomerProfile` Avro schema and promotes it only when compatible with the
    # currently active schema. An audit decision is recorded regardless of the outcome. Incompatible
    # candidates are rejected without registering the schema or changing the active version.
    #
    # + request - The promotion request containing the candidate schema
    # + return - `200 OK` with the decision when approved, `409 Conflict` with the decision when rejected,
    # or `500 Internal Server Error` when the promotion could not be evaluated
    resource function post promotions(@http:Payload PromotionRequest request) returns http:Ok|http:Conflict|http:InternalServerError {
        PromotionDecision|PromotionError result = promoteCustomerProfileSchema(request.candidateSchema);

        if result is PromotionError {
            http:InternalServerError errorResponse = {
                body: {
                    message: "failed to evaluate schema promotion",
                    detail: result.message()
                }
            };
            return errorResponse;
        }

        if result.outcome == "REJECTED" {
            http:Conflict conflictResponse = {body: result};
            return conflictResponse;
        }

        http:Ok okResponse = {body: result};
        return okResponse;
    }

    # Returns the audit log of all recorded schema promotion decisions.
    #
    # + return - The list of recorded `PromotionDecision` records
    resource function get promotions() returns PromotionDecision[] {
        return getPromotionAuditLog();
    }

    # Returns the currently active `CustomerProfile` Avro schema.
    #
    # + return - The active Avro schema in JSON `string` format
    resource function get schemas/active() returns string {
        return getActiveCustomerProfileSchema();
    }
}
