import ballerina/http;
import ballerina/log;

listener http:Listener jobControlListener = new (9090);

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
}
