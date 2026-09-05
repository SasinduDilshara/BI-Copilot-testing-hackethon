import ballerina/http;
import ballerina/log;

listener http:Listener jobControlListener = new (9090);

function init() {
    initializeSchedulerWorkerPool();
}

service /jobs on jobControlListener {

    // Accepts a job definition, validates it, schedules the recurring background job,
    // and returns an identifier the caller can use to refer to the job.
    resource function post .(@http:Payload JobRequest jobRequest)
            returns JobScheduledResponse|http:BadRequest|http:InternalServerError {

        error? validationError = validateJobRequest(jobRequest);
        if validationError is error {
            return <http:BadRequest>{
                body: {message: validationError.message()}
            };
        }

        string|error jobId = scheduleBackgroundJob(jobRequest);
        if jobId is error {
            log:printError("Failed to schedule background job", 'error = jobId);
            return <http:InternalServerError>{
                body: {message: "Failed to schedule the job"}
            };
        }

        return {
            jobId: jobId,
            status: "SCHEDULED"
        };
    }

    // Lists every job currently tracked by the service, regardless of its lifecycle status.
    resource function get .() returns JobInfo[] {
        return listJobs();
    }

    // Temporarily halts a running job so it stops firing until it is resumed.
    resource function post [string jobId]/pause() returns JobActionResponse|http:NotFound|http:InternalServerError {
        JobStatus? currentStatus = getJobStatus(jobId);
        if currentStatus is () || currentStatus == CANCELLED || currentStatus == COMPLETED {
            return <http:NotFound>{
                body: {message: string `Job ${jobId} is not currently scheduled`}
            };
        }

        error? pauseResult = pauseJob(jobId);
        if pauseResult is error {
            log:printError(string `Failed to pause job ${jobId}`, 'error = pauseResult);
            return <http:InternalServerError>{
                body: {message: "Failed to pause the job"}
            };
        }

        return {jobId, status: "PAUSED"};
    }

    // Resumes a previously paused job so it continues firing on its original schedule.
    resource function post [string jobId]/resume() returns JobActionResponse|http:NotFound|http:InternalServerError {
        JobStatus? currentStatus = getJobStatus(jobId);
        if currentStatus is () || currentStatus == CANCELLED || currentStatus == COMPLETED {
            return <http:NotFound>{
                body: {message: string `Job ${jobId} is not currently scheduled`}
            };
        }

        error? resumeResult = resumeJob(jobId);
        if resumeResult is error {
            log:printError(string `Failed to resume job ${jobId}`, 'error = resumeResult);
            return <http:InternalServerError>{
                body: {message: "Failed to resume the job"}
            };
        }

        return {jobId, status: "RUNNING"};
    }

    // Permanently cancels a job so it will never fire again.
    resource function delete [string jobId]() returns JobActionResponse|http:NotFound|http:InternalServerError {
        JobStatus? currentStatus = getJobStatus(jobId);
        if currentStatus is () || currentStatus == CANCELLED || currentStatus == COMPLETED {
            return <http:NotFound>{
                body: {message: string `Job ${jobId} is not currently scheduled`}
            };
        }

        error? cancelResult = cancelJob(jobId);
        if cancelResult is error {
            log:printError(string `Failed to cancel job ${jobId}`, 'error = cancelResult);
            return <http:InternalServerError>{
                body: {message: "Failed to cancel the job"}
            };
        }

        return {jobId, status: "CANCELLED"};
    }
}
