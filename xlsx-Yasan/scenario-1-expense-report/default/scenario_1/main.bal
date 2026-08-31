import ballerina/http;

service /expenses on new http:Listener(8085) {

    # Receives the raw bytes of an uploaded .xlsx expense report workbook, validates it, and returns a summary.
    #
    # + request - The inbound HTTP request carrying the raw workbook bytes
    # + return - The upload summary on success, or a typed 400 error identifying the failing row/column/reason
    resource function post upload(http:Request request) returns ExpenseUploadSummary|http:BadRequest|http:InternalServerError {
        byte[]|http:ClientError workbookBytes = request.getBinaryPayload();
        if workbookBytes is http:ClientError {
            ExpenseUploadErrorPayload errorPayload = {
                message: "Failed to read the uploaded file",
                rowNumber: 0,
                column: "",
                reason: "Request body could not be read as binary data."
            };
            return <http:BadRequest>{body: errorPayload};
        }

        ExpenseUploadSummary|ExpenseValidationError result = processExpenseWorkbook(workbookBytes);
        if result is ExpenseValidationError {
            ExpenseValidationErrorDetails errorDetails = result.detail();
            ExpenseUploadErrorPayload errorPayload = {
                message: result.message(),
                rowNumber: errorDetails.rowNumber,
                column: errorDetails.column,
                reason: errorDetails.reason
            };
            return <http:BadRequest>{body: errorPayload};
        }

        return result;
    }
}
