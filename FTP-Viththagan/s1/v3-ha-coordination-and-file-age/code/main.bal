import ballerina/ftp;
import ballerina/log;

// Handles partner order CSV files (orders_*.csv). Malformed rows are skipped
// and logged via the listener's csvFailSafe configuration instead of failing
// the whole file. On success the file is moved to the processed directory; on
// failure it is moved to the error directory instead of being re-picked.
@ftp:ServiceConfig {
    path: ordersDropPath,
    fileNamePattern: "orders_.*\\.csv",
    fileAgeFilter: {
        minAge: minFileAge,
        ageCalculationMode: ftp:LAST_MODIFIED
    }
}
service on orderFileListener {

    @ftp:FunctionConfig {
        afterProcess: {moveTo: processedDirPath},
        afterError: {moveTo: errorDirPath}
    }
    remote function onFileCsv(Order[] contents, ftp:FileInfo fileInfo) returns error? {
        log:printInfo("New partner order file received", fileName = fileInfo.name, path = fileInfo.path);

        foreach Order 'order in contents {
            check processOrder('order);
        }
    }

    remote function onError(ftp:Error ftpError) returns error? {
        log:printError("Error while polling the SFTP drop directory for order files", 'error = ftpError);
    }
}

// Handles partner return CSV files (returns_*.csv). Malformed rows are
// skipped and logged via the listener's csvFailSafe configuration instead of
// failing the whole file. On success the file is moved to the processed
// directory; on failure it is moved to the error directory instead of being
// re-picked.
@ftp:ServiceConfig {
    path: ordersDropPath,
    fileNamePattern: "returns_.*\\.csv",
    fileAgeFilter: {
        minAge: minFileAge,
        ageCalculationMode: ftp:LAST_MODIFIED
    }
}
service on orderFileListener {

    @ftp:FunctionConfig {
        afterProcess: {moveTo: processedDirPath},
        afterError: {moveTo: errorDirPath}
    }
    remote function onFileCsv(Return[] contents, ftp:FileInfo fileInfo) returns error? {
        log:printInfo("New partner return file received", fileName = fileInfo.name, path = fileInfo.path);

        foreach Return partnerReturn in contents {
            check processReturn(partnerReturn);
        }
    }

    remote function onError(ftp:Error ftpError) returns error? {
        log:printError("Error while polling the SFTP drop directory for return files", 'error = ftpError);
    }
}
