import ballerina/log;
import ballerina/task;
import ballerina/time;

// Number of concurrent worker threads the scheduler uses to fire due jobs. Sized comfortably
// above the expected dozen or so concurrent jobs so one slow job cannot block others that are
// due at the same instant.
const int SCHEDULER_WORKER_COUNT = 16;

// Tracks metadata for a single managed job, including the underlying scheduler job ID and the
// in-flight guard used to skip an overlapping run instead of queueing it.
type ManagedJob record {|
    task:JobId schedulerJobId;
    JobStatus status;
    decimal intervalSeconds;
    string message;
    boolean busy;
|};

// In-memory registry of every job the ops team has ever scheduled, keyed by the string job ID
// handed back to the caller. Guarded by a lock since HTTP requests and job executions can touch
// it concurrently.
final map<ManagedJob> jobRegistry = {};

// Monotonically increasing counter used to generate unique, readable job identifiers.
int nextJobSequence = 1;

// Whether the service is currently suspended for maintenance, in which case every tracked job
// has been paused at the scheduler level.
MaintenanceState maintenanceState = ACTIVE;

// Ensures the scheduler has enough worker threads for jobs to genuinely run side by side.
function initializeSchedulerWorkerPool() {
    task:Error? result = task:configureWorkerPool(SCHEDULER_WORKER_COUNT);
    if result is task:Error {
        log:printError("Failed to configure scheduler worker pool, using default", 'error = result);
    }
}

// Background job that logs the configured message with a timestamp each time it fires.
// Any failure while doing this work is caught here so the scheduler keeps firing the job
// on its next turn instead of the job being terminated. If a previous run of the same job is
// still in flight when the next trigger arrives, that turn is skipped and noted rather than
// queued behind the running one.
class MessageLoggerJob {
    *task:Job;

    private final string jobId;
    private final string message;

    isolated function init(string jobId, string message) {
        self.jobId = jobId;
        self.message = message;
    }

    public function execute() {
        boolean canRun = markBusyIfFree(self.jobId);
        if !canRun {
            log:printWarn(string `Skipped a turn for job ${self.jobId} because the previous run is still in progress`);
            return;
        }

        error? result = self.logMessage();
        if result is error {
            log:printError("Job execution failed, will retry on next trigger", 'error = result);
        }

        markFree(self.jobId);
    }

    private function logMessage() returns error? {
        time:Utc currentUtc = time:utcNow();
        string timestamp = check time:utcToString(currentUtc);
        log:printInfo(string `[${timestamp}] ${self.message}`);
    }
}

// Atomically checks whether the given job is free to run and, if so, marks it busy.
// Returns false when a previous run is still in progress, signalling the caller to skip.
function markBusyIfFree(string jobId) returns boolean {
    lock {
        ManagedJob? managedJob = jobRegistry[jobId];
        if managedJob is () {
            return false;
        }
        if managedJob.busy {
            return false;
        }
        managedJob.busy = true;
        return true;
    }
}

// Marks the job as no longer busy, allowing its next due trigger to run.
function markFree(string jobId) {
    lock {
        ManagedJob? managedJob = jobRegistry[jobId];
        if managedJob is () {
            return;
        }
        managedJob.busy = false;
    }
}

// Validates the incoming job request, returning a descriptive error when invalid.
function validateJobRequest(JobRequest jobRequest) returns error? {
    if jobRequest.intervalSeconds <= 0d {
        return error("Interval must be a positive number of seconds");
    }
}

// Generates the next unique, human-readable job identifier.
function generateJobId() returns string {
    lock {
        string jobId = "job-" + nextJobSequence.toString();
        nextJobSequence += 1;
        return jobId;
    }
}

// Schedules the recurring background job to run indefinitely, registers its metadata, and
// returns the generated job identifier the caller can use to manage it later.
function scheduleBackgroundJob(JobRequest jobRequest) returns string|error {
    string jobId = generateJobId();
    MessageLoggerJob job = new (jobId, jobRequest.message);
    task:JobId schedulerJobId = check task:scheduleJobRecurByFrequency(
        job,
        jobRequest.intervalSeconds,
        taskPolicy = {
            errorPolicy: task:LOG_AND_CONTINUE
        }
    );

    lock {
        jobRegistry[jobId] = {
            schedulerJobId,
            status: RUNNING,
            intervalSeconds: jobRequest.intervalSeconds,
            message: jobRequest.message,
            busy: false
        };
    }
    return jobId;
}

// Returns metadata for every job that is currently tracked, regardless of its status.
function listJobs() returns JobInfo[] {
    lock {
        JobInfo[] jobInfoList = [];
        foreach [string, ManagedJob] [jobId, managedJob] in jobRegistry.entries() {
            jobInfoList.push({
                jobId,
                status: managedJob.status,
                intervalSeconds: managedJob.intervalSeconds,
                message: managedJob.message
            });
        }
        return jobInfoList.clone();
    }
}

// Looks up the current status of a job, returning () when it is not known to the registry.
function getJobStatus(string jobId) returns JobStatus? {
    lock {
        ManagedJob? managedJob = jobRegistry[jobId];
        if managedJob is () {
            return ();
        }
        return managedJob.status;
    }
}

// Permanently cancels a job so it will never fire again.
function cancelJob(string jobId) returns error? {
    task:JobId schedulerJobId;
    lock {
        ManagedJob? managedJob = jobRegistry[jobId];
        if managedJob is () || managedJob.status != RUNNING {
            return error("Job is not currently active");
        }
        schedulerJobId = managedJob.schedulerJobId;
    }

    check task:unscheduleJob(schedulerJobId);

    lock {
        ManagedJob? managedJob = jobRegistry[jobId];
        if managedJob is ManagedJob {
            managedJob.status = CANCELLED;
        }
    }
}

// Returns the current maintenance state of the service.
function getMaintenanceState() returns MaintenanceState {
    lock {
        return maintenanceState;
    }
}

// Suspends the service for maintenance, pausing every currently running job at the scheduler
// level. Already-cancelled jobs are left untouched. Returns an error if already suspended.
function enterMaintenance() returns error? {
    lock {
        if maintenanceState == SUSPENDED {
            return error("Service is already in maintenance");
        }
    }

    string[] jobIds;
    lock {
        jobIds = jobRegistry.keys().clone();
    }

    foreach string jobId in jobIds {
        task:JobId? schedulerJobId = ();
        lock {
            ManagedJob? managedJob = jobRegistry[jobId];
            if managedJob is ManagedJob && managedJob.status == RUNNING {
                schedulerJobId = managedJob.schedulerJobId;
            }
        }
        if schedulerJobId is task:JobId {
            task:Error? pauseResult = task:pauseJob(schedulerJobId);
            if pauseResult is task:Error {
                log:printError(string `Failed to pause job ${jobId} while entering maintenance`, 'error = pauseResult);
            }
        }
    }

    lock {
        maintenanceState = SUSPENDED;
    }
}

// Brings the service back out of maintenance, resuming every currently running job at the
// scheduler level. Returns an error if not currently suspended.
function exitMaintenance() returns error? {
    lock {
        if maintenanceState == ACTIVE {
            return error("Service is not currently in maintenance");
        }
    }

    string[] jobIds;
    lock {
        jobIds = jobRegistry.keys().clone();
    }

    foreach string jobId in jobIds {
        task:JobId? schedulerJobId = ();
        lock {
            ManagedJob? managedJob = jobRegistry[jobId];
            if managedJob is ManagedJob && managedJob.status == RUNNING {
                schedulerJobId = managedJob.schedulerJobId;
            }
        }
        if schedulerJobId is task:JobId {
            task:Error? resumeResult = task:resumeJob(schedulerJobId);
            if resumeResult is task:Error {
                log:printError(string `Failed to resume job ${jobId} while exiting maintenance`, 'error = resumeResult);
            }
        }
    }

    lock {
        maintenanceState = ACTIVE;
    }
}
