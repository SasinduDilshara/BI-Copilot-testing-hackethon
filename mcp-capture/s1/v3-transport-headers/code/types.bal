# Represents the current status of a deployed service.
#
# + name - Name of the service
# + healthy - Whether the service is currently healthy
# + replicas - Number of running replicas
# + lastDeployedAt - Timestamp of the last deployment in ISO 8601 format
public type ServiceStatus record {|
    string name;
    boolean healthy;
    int replicas;
    string lastDeployedAt;
|};

# Represents a single deployment event for a service.
#
# + serviceName - Name of the service that was deployed
# + environment - Environment the deployment targeted
# + 'version - Version or build identifier that was deployed
# + deployedAt - Timestamp of the deployment in ISO 8601 format
public type DeploymentRecord record {|
    string serviceName;
    string environment;
    string 'version;
    string deployedAt;
|};

# Represents the outcome of a service restart operation.
#
# + serviceName - Name of the service that was restarted
# + environment - Environment the service was restarted in
# + restarted - Whether the restart was successfully triggered
# + message - Human readable outcome message
public type RestartResult record {|
    string serviceName;
    string environment;
    boolean restarted;
    string message;
|};

# Represents the audit metadata derived from the inbound transport headers of a tool call.
#
# + requestId - The caller-supplied request identifier used to correlate audit records
# + tenant - The tenant on whose behalf the call was made
public type AuditContext record {|
    string requestId;
    string tenant;
|};

# Represents a maintenance window opened for a service in a given environment.
#
# + serviceName - Name of the service under maintenance
# + environment - Environment the maintenance window applies to
# + reason - Reason for opening the maintenance window
# + startedAt - Timestamp when the maintenance window was opened, in ISO 8601 format
# + durationMinutes - Duration of the maintenance window in minutes
public type MaintenanceWindow record {|
    string serviceName;
    string environment;
    string reason;
    string startedAt;
    int durationMinutes;
|};
