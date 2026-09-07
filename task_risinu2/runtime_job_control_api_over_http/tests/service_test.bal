import ballerina/http;
import ballerina/test;

final http:Client testClient = check new ("http://localhost:9090");

// Creating a job should return a generated identifier and the job should then appear in the list.
@test:Config {}
function testCreateJobAppearsInList() returns error? {
    JobRequest jobRequest = {intervalSeconds: 5, message: "heartbeat"};
    JobScheduledResponse createResponse = check testClient->/jobs.post(jobRequest);
    test:assertEquals(createResponse.status, "SCHEDULED", msg = "Newly created job should be scheduled");

    JobInfo[] jobInfoList = check testClient->/jobs.get();
    JobInfo[] matchingJobs = from JobInfo jobInfo in jobInfoList
        where jobInfo.jobId == createResponse.jobId
        select jobInfo;
    test:assertEquals(matchingJobs.length(), 1, msg = "Created job should appear exactly once in the list");
    test:assertEquals(matchingJobs[0].status, RUNNING, msg = "Newly created job should be RUNNING");
    test:assertEquals(matchingJobs[0].intervalSeconds, 5d, msg = "Job interval should match what was requested");
    test:assertEquals(matchingJobs[0].message, "heartbeat", msg = "Job message should match what was requested");
}

// Cancelling a job should remove it from the set of active jobs returned by the list.
@test:Config {}
function testCancelJobRemovesItFromActiveList() returns error? {
    JobRequest jobRequest = {intervalSeconds: 10, message: "cancel-me"};
    JobScheduledResponse createResponse = check testClient->/jobs.post(jobRequest);

    http:Response cancelResponse = check testClient->/jobs/[createResponse.jobId].delete();
    test:assertEquals(cancelResponse.statusCode, 200, msg = "Cancelling an active job should succeed");
    json cancelJson = check cancelResponse.getJsonPayload();
    JobActionResponse cancelBody = check cancelJson.cloneWithType(JobActionResponse);
    test:assertEquals(cancelBody.status, "CANCELLED", msg = "Cancel response should report CANCELLED status");

    JobInfo[] jobInfoList = check testClient->/jobs.get();
    JobInfo[] activeMatches = from JobInfo jobInfo in jobInfoList
        where jobInfo.jobId == createResponse.jobId && jobInfo.status == RUNNING
        select jobInfo;
    test:assertEquals(activeMatches.length(), 0, msg = "Cancelled job should no longer be reported as RUNNING");
}

// Cancelling a job that is already cancelled (or was never scheduled) should return 404.
@test:Config {dependsOn: [testCancelJobRemovesItFromActiveList]}
function testCancelUnknownJobReturnsNotFound() returns error? {
    http:Response cancelResponse = check testClient->/jobs/["job-does-not-exist"].delete();
    test:assertEquals(cancelResponse.statusCode, 404, msg = "Cancelling an unknown job should return 404");
}

// The maintenance switch should suspend the service and later restore it, and the status
// endpoint should reflect each transition.
@test:Config {}
function testMaintenanceSuspendAndRestore() returns error? {
    MaintenanceStatusResponse initialStatus = check testClient->/maintenance.get();
    test:assertEquals(initialStatus.state, ACTIVE, msg = "Service should start in the ACTIVE state");

    MaintenanceStatusResponse suspendResponse = check testClient->/maintenance/suspend.post({});
    test:assertEquals(suspendResponse.state, SUSPENDED, msg = "Suspend call should report SUSPENDED state");

    MaintenanceStatusResponse duringMaintenance = check testClient->/maintenance.get();
    test:assertEquals(duringMaintenance.state, SUSPENDED, msg = "Status check should report SUSPENDED while in maintenance");

    MaintenanceStatusResponse restoreResponse = check testClient->/maintenance/restore.post({});
    test:assertEquals(restoreResponse.state, ACTIVE, msg = "Restore call should report ACTIVE state");

    MaintenanceStatusResponse finalStatus = check testClient->/maintenance.get();
    test:assertEquals(finalStatus.state, ACTIVE, msg = "Status check should report ACTIVE after restoring");
}

// A non-positive interval should be rejected with a 400 and a readable message, and nothing
// should be scheduled.
@test:Config {}
function testCreateJobWithInvalidIntervalReturnsBadRequest() returns error? {
    JobRequest jobRequest = {intervalSeconds: 0, message: "bad-interval"};
    http:Response createResponse = check testClient->/jobs.post(jobRequest);
    test:assertEquals(createResponse.statusCode, 400, msg = "Non-positive interval should be rejected with 400");
    json errorJson = check createResponse.getJsonPayload();
    ErrorResponse errorBody = check errorJson.cloneWithType(ErrorResponse);
    test:assertEquals(errorBody.message, "Interval must be a positive number of seconds",
            msg = "Error message should explain the invalid interval");
}
