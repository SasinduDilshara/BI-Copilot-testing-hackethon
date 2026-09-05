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
