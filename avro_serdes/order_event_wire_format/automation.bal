import ballerina/http;

# HTTP service exposing the CustomerProfile schema compatibility validation workflow.
# This workflow is strictly read-only: it looks up the active schema, validates a candidate against it,
# and records the decision in the validation history. It never registers a schema and never changes the
# active schema version.
service /schema\-registry on new http:Listener(httpListenerPort) {

    # Evaluates whether a candidate `CustomerProfile` Avro schema is compatible with the currently active
    # schema. A validation decision is recorded regardless of the outcome. This operation is read-only: it
    # never registers the candidate schema and never changes the active schema version.
    #
    # + request - The compatibility validation request containing the candidate schema
    # + return - `200 OK` with the decision when compatible, `409 Conflict` with the decision when
    # incompatible, or `500 Internal Server Error` when the validation could not be evaluated
    resource function post validations(@http:Payload CompatibilityValidationRequest request)
            returns http:Ok|http:Conflict|http:InternalServerError {
        CompatibilityValidationRecord|ValidationOperationError result =
            validateCustomerProfileSchemaCompatibility(request.candidateSchema);

        if result is ValidationOperationError {
            http:InternalServerError errorResponse = {
                body: {
                    message: "failed to evaluate schema compatibility",
                    detail: result.message()
                }
            };
            return errorResponse;
        }

        if result.outcome == "INCOMPATIBLE" {
            http:Conflict conflictResponse = {body: result};
            return conflictResponse;
        }

        http:Ok okResponse = {body: result};
        return okResponse;
    }

    # Returns the validation history of all recorded schema compatibility decisions.
    #
    # + return - The list of recorded `CompatibilityValidationRecord` entries
    resource function get validations() returns CompatibilityValidationRecord[] {
        return getCompatibilityValidationHistory();
    }

    # Returns the currently active `CustomerProfile` Avro schema.
    #
    # + return - The active Avro schema in JSON `string` format
    resource function get schemas/active() returns string {
        return getActiveCustomerProfileSchema();
    }
}
