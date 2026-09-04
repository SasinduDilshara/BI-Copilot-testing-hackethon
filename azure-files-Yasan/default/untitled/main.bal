import ballerina/log;
import ballerinax/azure.storage.files;

@files:ServiceConfig {
    fileNamePattern: "^INV-\\d+\\.csv$"
}
service files:Service /inbound on invoiceShareListener {

    @files:FunctionConfig {
        afterProcess: {moveTo: "/processed"},
        afterError: {moveTo: "/error"}
    }
    remote function onFileCsv(stream<InvoiceLine, error?> content, files:FileInfo fileInfo, files:Caller caller) returns error? {
        string fileName = fileInfo.name;

        InvoiceParseResult parseResult = check parseInvoiceFile(fileName, content);
        InvoiceFileError? fileError = parseResult.fileError;
        if fileError is InvoiceFileError {
            log:printError("invoice file processing failed",
                    fileName = fileError.fileName,
                    lineNo = fileError.lineNo,
                    reason = fileError.reason);
            return error(fileError.reason);
        }

        InvoiceFileSummary summary = buildInvoiceSummary(fileName, parseResult.lines);
        log:printInfo("invoice file processed", summary = summary);
        return;
    }

    remote function onError(files:Error err, files:Caller caller) returns error? {
        log:printError("invoice share polling error", 'error = err);
        return;
    }
}
