import ballerina/log;
import ballerinax/azure.storage.files;

@files:ServiceConfig {
    recursive: true,
    minFileAgeSeconds: 10
}
service files:Service /inbound on invoiceShareListener {

    @files:FunctionConfig {
        fileNamePattern: "^INV-\\d+\\.csv$",
        afterProcess: {moveTo: "/processed", preserveSubDirs: true},
        afterError: {moveTo: "/error", preserveSubDirs: true}
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

    @files:FunctionConfig {
        fileNamePattern: "^VENDOR-\\d+\\.json$",
        afterProcess: {moveTo: "/processed", preserveSubDirs: true},
        afterError: {moveTo: "/error", preserveSubDirs: true}
    }
    remote function onFileJson(VendorUpdate content, files:FileInfo fileInfo, files:Caller caller) returns error? {
        string fileName = fileInfo.name;

        int vendorStoreSize = upsertVendor(vendorStore, content);
        log:printInfo("vendor update processed", fileName = fileName, vendorId = content.vendorId, vendorStoreSize = vendorStoreSize);
        return;
    }

    remote function onError(files:Error err, files:Caller caller) returns error? {
        log:printError("invoice share polling error", 'error = err);
        return;
    }
}
