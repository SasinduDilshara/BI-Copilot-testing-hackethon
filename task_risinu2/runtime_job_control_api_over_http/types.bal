// Request payload for scheduling a new background job.
public type JobRequest record {|
    decimal intervalSeconds;
    int repeatCount;
    string message;
|};

// Response returned when a job has been successfully scheduled.
public type JobScheduledResponse record {|
    string jobId;
    string status;
|};

// Generic error response body used for both validation and internal errors.
public type ErrorResponse record {|
    string message;
|};

// Lifecycle status of a managed background job.
public enum JobStatus {
    RUNNING,
    PAUSED,
    CANCELLED,
    COMPLETED
}

// Metadata describing a currently tracked job, returned when listing jobs.
public type JobInfo record {|
    string jobId;
    JobStatus status;
    decimal intervalSeconds;
    int repeatCount;
    string message;
|};

// Simple confirmation response for pause/resume/cancel operations.
public type JobActionResponse record {|
    string jobId;
    string status;
|};
