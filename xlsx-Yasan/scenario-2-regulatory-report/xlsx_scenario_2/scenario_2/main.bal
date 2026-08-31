import ballerina/http;

configurable int servicePort = 9090;

service /reports on new http:Listener(servicePort) {

    # Generates the monthly Suspicious Transaction Summary report as an .xlsx workbook.
    #
    # + request - the report generation request containing the month and output path
    # + return - a success response with report details, a bad request for invalid input,
    # or an internal server error if generation fails
    resource function post generate(GenerateReportRequest request)
            returns GenerateReportResponse|http:BadRequest|http:InternalServerError {

        string month = request.month;
        string outputPath = request.outputPath;

        if !isValidMonth(month) {
            ErrorMessage errorMessage = {message: string `Invalid month '${month}'. Expected format is yyyy-MM, e.g. 2026-08.`};
            return <http:BadRequest>{body: errorMessage};
        }

        TransactionAlert[]|error result = generateSuspiciousTransactionReport(month, outputPath);
        if result is error {
            ErrorMessage errorMessage = {message: string `Failed to generate report: ${result.message()}`};
            return <http:InternalServerError>{body: errorMessage};
        }

        return {
            message: "Suspicious Transaction Summary report generated successfully.",
            outputPath: outputPath,
            month: month,
            totalAlerts: result.length()
        };
    }
}
