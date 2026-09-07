import ballerina/file;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/test;

// Name of the well-formed CSV file dropped into the inbox for the test.
const string GOOD_FILE_NAME = "good-order.csv";

// Name of the malformed file dropped into the inbox for the test.
const string BAD_FILE_NAME = "bad-order.csv";

// Sets up a fresh inbox, processed, and quarantine folder structure, then drops one good file
// and one malformed file into the inbox before the sweeper gets a chance to run against it.
// Removes any same-named leftovers from a previous run so the test is repeatable.
@test:BeforeSuite
function setupInboxFiles() returns error? {
    check createDirIfAbsent(inboxFolderPath);
    check createDirIfAbsent(processedFolderPath);
    check createDirIfAbsent(quarantineFolderPath);

    check removeIfPresent(check file:joinPath(inboxFolderPath, GOOD_FILE_NAME));
    check removeIfPresent(check file:joinPath(inboxFolderPath, BAD_FILE_NAME));
    check removeIfPresent(check file:joinPath(processedFolderPath, GOOD_FILE_NAME));
    check removeIfPresent(check file:joinPath(processedFolderPath, BAD_FILE_NAME));
    check removeIfPresent(check file:joinPath(quarantineFolderPath, GOOD_FILE_NAME));
    check removeIfPresent(check file:joinPath(quarantineFolderPath, BAD_FILE_NAME));

    string goodFilePath = check file:joinPath(inboxFolderPath, GOOD_FILE_NAME);
    string[][] goodFileRows = [["orderId", "item", "quantity"], ["1", "widget", "10"], ["2", "gadget", "5"]];
    check io:fileWriteCsv(goodFilePath, goodFileRows);

    // Overlong, invalid, and truncated multi-byte UTF-8 sequences are not valid text, so
    // reading this file as CSV fails outright with a decoding error.
    string badFilePath = check file:joinPath(inboxFolderPath, BAD_FILE_NAME);
    byte[] invalidUtf8Bytes = [
        0xC0, 0xAF, 0xE0, 0x80, 0xAF, 0xF8, 0x88, 0x80, 0x80, 0x80,
        0xFF, 0xFE, 0xC1, 0xBF, 0xED, 0xA0, 0x80, 0xF4, 0x90, 0x80, 0x80
    ];
    check io:fileWriteBytes(badFilePath, invalidUtf8Bytes);
}

// Lets the sweeper run through a couple of sweep cycles, then asserts the good file landed in
// the processed folder, the bad file landed in the quarantine folder, and the running counters
// reflect exactly one success and one failure.
@test:Config {}
function testGoodFileProcessedAndBadFileQuarantined() returns error? {
    // Sweep interval in tests is configured short; wait for a couple of cycles to complete.
    runtime:sleep(6);

    string processedGoodFilePath = check file:joinPath(processedFolderPath, GOOD_FILE_NAME);
    boolean goodFileProcessed = check file:test(processedGoodFilePath, file:EXISTS);
    test:assertTrue(goodFileProcessed, msg = "Good file should have been moved to the processed folder");

    string quarantinedBadFilePath = check file:joinPath(quarantineFolderPath, BAD_FILE_NAME);
    boolean badFileQuarantined = check file:test(quarantinedBadFilePath, file:EXISTS);
    test:assertTrue(badFileQuarantined, msg = "Malformed file should have been moved to the quarantine folder");

    SweepCounters sweepCounters = getSweepCounters();
    test:assertEquals(sweepCounters.processedCount, 1, msg = "Exactly one file should have been processed");
    test:assertEquals(sweepCounters.failedCount, 1, msg = "Exactly one file should have failed");
}

// Creates the given directory if it does not already exist, leaving it untouched otherwise.
function createDirIfAbsent(string dirPath) returns error? {
    boolean dirExists = check file:test(dirPath, file:EXISTS);
    if !dirExists {
        check file:createDir(dirPath, file:RECURSIVE);
    }
}

// Removes the file at the given path if it currently exists, leaving it untouched otherwise.
function removeIfPresent(string filePath) returns error? {
    boolean filePresent = check file:test(filePath, file:EXISTS);
    if filePresent {
        check file:remove(filePath);
    }
}
