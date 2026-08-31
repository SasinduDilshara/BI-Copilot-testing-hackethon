import ballerina/http;

service /expenses on new http:Listener(8085) {

    # Receives the raw bytes of an uploaded .xlsx expense report workbook, binds what parses, and
    # returns which rows were accepted and which were rejected.
    #
    # + request - The inbound HTTP request carrying the raw workbook bytes
    # + return - The upload response (200, partial or full acceptance), a typed 422 error when the
    # sheet's own TOTAL does not match the accepted sum, or a 500 error for structural failures
    # (invalid workbook, missing sheet, missing reporting period)
    resource function post upload(http:Request request) returns ExpenseUploadResponse|http:UnprocessableEntity|http:InternalServerError {
        byte[]|http:ClientError workbookBytes = request.getBinaryPayload();
        if workbookBytes is http:ClientError {
            return <http:InternalServerError>{body: {message: "Request body could not be read as binary data."}};
        }

        ExpenseUploadResponse|ExpenseTotalMismatchError|error result = processExpenseWorkbook(workbookBytes);
        if result is ExpenseTotalMismatchError {
            ExpenseTotalMismatchDetails mismatchDetails = result.detail();
            ExpenseTotalMismatchPayload mismatchPayload = {
                message: "Upload rejected due to a TOTAL mismatch",
                reason: result.message(),
                sheetTotalAmountUsd: mismatchDetails.sheetTotalAmountUsd,
                computedTotalAmountUsd: mismatchDetails.computedTotalAmountUsd
            };
            return <http:UnprocessableEntity>{body: mismatchPayload};
        }
        if result is error {
            return <http:InternalServerError>{body: {message: result.message()}};
        }

        return result;
    }
}
