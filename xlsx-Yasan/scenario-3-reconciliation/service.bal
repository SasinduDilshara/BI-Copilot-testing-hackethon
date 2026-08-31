import ballerina/http;

configurable int servicePort = 8080;

service /reconciliation on new http:Listener(servicePort) {

    # Reconciles an uploaded bank statement workbook against the configured ledger.
    #
    # + request - The inbound HTTP request carrying the statement workbook as raw bytes
    # + return - The reconciliation summary as JSON, or an error response
    resource function post reconcile(http:Request request) returns ReconcileResponse|http:BadRequest|http:InternalServerError {
        byte[]|http:ClientError statementBytes = request.getBinaryPayload();
        if statementBytes is http:ClientError {
            http:BadRequest badRequest = {
                body: string `Could not read the statement workbook from the request body: ${statementBytes.message()}`
            };
            return badRequest;
        }

        string statementLabel = "uploaded-statement.xlsx";
        string|http:HeaderNotFoundError contentDisposition = request.getHeader("Content-Disposition");
        if contentDisposition is string {
            statementLabel = contentDisposition;
        }

        ReconcileResponse|error result = reconcileStatement(statementBytes, statementLabel);
        if result is error {
            http:InternalServerError internalServerError = {
                body: string `Reconciliation failed: ${result.message()}`
            };
            return internalServerError;
        }
        return result;
    }
}
