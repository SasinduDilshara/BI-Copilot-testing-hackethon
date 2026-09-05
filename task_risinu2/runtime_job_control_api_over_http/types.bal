// Request payload for scheduling a new background job. Jobs run indefinitely until cancelled.
public type JobRequest record {|
    decimal intervalSeconds;
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
    CANCELLED
}

// Metadata describing a currently tracked job, returned when listing jobs.
public type JobInfo record {|
    string jobId;
    JobStatus status;
    decimal intervalSeconds;
    string message;
|};

// Simple confirmation response for the cancel operation.
public type JobActionResponse record {|
    string jobId;
    string status;
|};

// Whether the service is currently accepting job triggers or is suspended for maintenance.
public enum MaintenanceState {
    ACTIVE,
    SUSPENDED
}

// Response describing the current maintenance state of the service.
public type MaintenanceStatusResponse record {|
    MaintenanceState state;
|};
