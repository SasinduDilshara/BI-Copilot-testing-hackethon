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

    // Permanently cancels a job so it will never fire again.
    resource function delete [string jobId]() returns JobActionResponse|http:NotFound|http:InternalServerError {
        JobStatus? currentStatus = getJobStatus(jobId);
        if currentStatus is () || currentStatus == CANCELLED {
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

service /maintenance on jobControlListener {

    // Reports whether the service is currently active or suspended for maintenance.
    resource function get .() returns MaintenanceStatusResponse {
        return {state: getMaintenanceState()};
    }

    // Suspends every scheduled job so none of them fire while maintenance is in progress.
    resource function post suspend() returns MaintenanceStatusResponse|http:InternalServerError {
        error? result = enterMaintenance();
        if result is error {
            log:printError("Failed to enter maintenance", 'error = result);
            return <http:InternalServerError>{
                body: {message: "Failed to enter maintenance"}
            };
        }
        return {state: SUSPENDED};
    }

    // Brings every scheduled job back so they resume firing on their original schedule.
    resource function post restore() returns MaintenanceStatusResponse|http:InternalServerError {
        error? result = exitMaintenance();
        if result is error {
            log:printError("Failed to exit maintenance", 'error = result);
            return <http:InternalServerError>{
                body: {message: "Failed to exit maintenance"}
            };
        }
        return {state: ACTIVE};
    }
}
