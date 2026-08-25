import ballerina/mcp;
import ballerina/time;

const string MAINTENANCE_WINDOW_KEY = "maintenanceWindow";

final map<ServiceStatus> serviceStatusStore = {
    "orders-service": {name: "orders-service", healthy: true, replicas: 3, lastDeployedAt: "2026-08-20T10:15:00Z"},
    "payments-service": {name: "payments-service", healthy: false, replicas: 2, lastDeployedAt: "2026-08-18T08:30:00Z"},
    "inventory-service": {name: "inventory-service", healthy: true, replicas: 4, lastDeployedAt: "2026-08-22T14:45:00Z"}
};

final DeploymentRecord[] deploymentHistory = [
    {serviceName: "orders-service", environment: "production", 'version: "1.4.2", deployedAt: "2026-08-20T10:15:00Z"},
    {serviceName: "payments-service", environment: "production", 'version: "2.1.0", deployedAt: "2026-08-18T08:30:00Z"},
    {serviceName: "inventory-service", environment: "staging", 'version: "3.0.1", deployedAt: "2026-08-22T14:45:00Z"},
    {serviceName: "orders-service", environment: "staging", 'version: "1.5.0-rc1", deployedAt: "2026-08-23T09:00:00Z"},
    {serviceName: "payments-service", environment: "staging", 'version: "2.2.0-rc2", deployedAt: "2026-08-21T11:20:00Z"}
];

# Looks up the current status record for the given service name.
#
# + serviceName - Name of the service to look up
# + return - The service status record, or an error if the service is not found
function findServiceStatus(string serviceName) returns ServiceStatus|error {
    if serviceStatusStore.hasKey(serviceName) {
        return serviceStatusStore.get(serviceName);
    }
    return error(string `Service not found: ${serviceName}`);
}

# Retrieves the most recent deployments for the given environment, limited to the requested count.
#
# + environment - Environment to filter deployments by
# + count - Maximum number of deployment records to return
# + return - An array of matching deployment records
function findRecentDeployments(string environment, int count) returns DeploymentRecord[]|error {
    if count <= 0 {
        return error("count must be a positive integer");
    }
    DeploymentRecord[] matching = from DeploymentRecord deployment in deploymentHistory
        where deployment.environment == environment
        select deployment;
    if matching.length() <= count {
        return matching;
    }
    return matching.slice(0, count);
}

# Triggers a restart of the given service in the given environment and updates its recorded status.
#
# + serviceName - Name of the service to restart
# + environment - Environment the service should be restarted in
# + return - The outcome of the restart operation, or an error if the service is not found
function triggerServiceRestart(string serviceName, string environment) returns RestartResult|error {
    if !serviceStatusStore.hasKey(serviceName) {
        return error(string `Service not found: ${serviceName}`);
    }
    ServiceStatus previousStatus = serviceStatusStore.get(serviceName);
    string restartedAt = time:utcToString(time:utcNow());
    ServiceStatus updatedStatus = {
        name: previousStatus.name,
        healthy: true,
        replicas: previousStatus.replicas,
        lastDeployedAt: previousStatus.lastDeployedAt
    };
    serviceStatusStore[serviceName] = updatedStatus;
    return {
        serviceName,
        environment,
        restarted: true,
        message: string `Service '${serviceName}' restarted successfully in '${environment}' at ${restartedAt}`
    };
}

# Opens a maintenance window for the given service and stores it against the calling session.
#
# + session - The client session to store the maintenance window against
# + serviceName - Name of the service to place under maintenance
# + environment - Environment the maintenance window applies to
# + reason - Reason for opening the maintenance window
# + durationMinutes - Duration of the maintenance window in minutes
# + return - The maintenance window that was opened, or an error if the input is invalid
function openMaintenanceWindow(mcp:Session session, string serviceName, string environment, string reason,
        int durationMinutes) returns MaintenanceWindow|error {
    if durationMinutes <= 0 {
        return error("durationMinutes must be a positive integer");
    }
    MaintenanceWindow maintenanceWindow = {
        serviceName,
        environment,
        reason,
        startedAt: time:utcToString(time:utcNow()),
        durationMinutes
    };
    session.set(MAINTENANCE_WINDOW_KEY, maintenanceWindow);
    return maintenanceWindow;
}

# Reads back the maintenance window stored against the calling session, if any.
#
# + session - The client session to read the maintenance window from
# + return - The maintenance window stored on the session, or an error if none has been opened
function readMaintenanceWindow(mcp:Session session) returns MaintenanceWindow|error {
    if !session.hasKey(MAINTENANCE_WINDOW_KEY) {
        return error("No maintenance window has been opened for this session");
    }
    return session.getWithType(MAINTENANCE_WINDOW_KEY, MaintenanceWindow);
}
