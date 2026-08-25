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
