import ballerina/http;
import ballerina/mcp;

configurable int serverPort = 9090;
configurable string assistantOrigin = ?;

listener mcp:Listener mcpListener = check new (serverPort);

@mcp:StreamableHttpServiceConfig {
    info: {
        name: "Deployment Ops MCP Server",
        version: "1.0.0"
    },
    sessionMode: mcp:STATEFUL,
    httpConfig: {
        cors: {
            allowOrigins: [assistantOrigin]
        }
    },
    options: {
        instructions: string `This server exposes deployment-ops tools for a support assistant.
Use getServiceStatus and listRecentDeployments freely to inspect state; they are read-only.
Use restartService only when a restart is genuinely needed, and confirm the serviceName and
environment with the user first, since it changes the running state of the service.
Use startMaintenanceWindow to open a maintenance window before performing invasive operations
on a service, and use getMaintenanceWindow to check whether one is already open for the current
conversation before opening another.`
    }
}
service mcp:StreamableHttpService /mcp on mcpListener {

    # [Read-only] Get the current deployment status of a service. This tool does not modify any state.
    #
    # + serviceName - The name of the service to check
    # + return - The current status of the service, or an error if the service is not found
    @mcp:Tool {
        description: "Read-only. Gets the current deployment status of a service. Does not modify any state."
    }
    remote function getServiceStatus(string serviceName) returns ServiceStatus|error {
        return findServiceStatus(serviceName);
    }

    # [Read-only] List the most recent deployments for a given environment. This tool does not modify any state.
    #
    # + environment - The environment to list deployments for (e.g. production, staging)
    # + count - The maximum number of recent deployments to return
    # + return - An array of recent deployment records, or an error if the input is invalid
    @mcp:Tool {
        description: "Read-only. Lists the most recent deployments for a given environment. Does not modify any state."
    }
    remote function listRecentDeployments(string environment, int count) returns DeploymentRecord[]|error {
        return findRecentDeployments(environment, count);
    }

    # [Destructive, idempotent, not read-only] Restart a service in a given environment. This tool changes the
    # running state of the service; calling it again with the same arguments has the same end effect (the service
    # ends up restarted) and does not cause additional side effects beyond that. The caller's request id and tenant
    # are read from the transport headers and recorded in the audit log.
    #
    # + serviceName - The name of the service to restart
    # + environment - The environment in which to restart the service
    # + headers - The inbound transport headers, used to read the request id and tenant for audit logging
    # + return - The result of the restart operation, or an error if the service is not found
    @mcp:Tool {
        description: "Not read-only, destructive, idempotent. Restarts a service in a given environment. This changes the running state of the service. Calling it again with the same arguments produces the same end state and causes no additional side effects."
    }
    remote function restartService(string serviceName, string environment, http:Headers headers)
            returns RestartResult|error {
        AuditContext auditContext = extractAuditContext(headers);
        return triggerServiceRestart(serviceName, environment, auditContext);
    }

    # [Not read-only] Open a maintenance window for a service and store it against the current session so it can be
    # read back later in the same conversation.
    #
    # + session - The client session the maintenance window is stored against
    # + serviceName - The name of the service to place under maintenance
    # + environment - The environment the maintenance window applies to
    # + reason - The reason for opening the maintenance window
    # + durationMinutes - The duration of the maintenance window in minutes
    # + return - The maintenance window that was opened, or an error if the input is invalid
    @mcp:Tool {
        description: "Not read-only. Opens a maintenance window for a service in an environment and stores it on the current session for later retrieval within the same conversation."
    }
    remote function startMaintenanceWindow(mcp:Session session, string serviceName, string environment,
            string reason, int durationMinutes) returns MaintenanceWindow|error {
        return openMaintenanceWindow(session, serviceName, environment, reason, durationMinutes);
    }

    # [Read-only] Read back the maintenance window previously opened on the current session, if any.
    #
    # + session - The client session to read the maintenance window from
    # + return - The maintenance window stored on the session, or an error if none has been opened
    @mcp:Tool {
        description: "Read-only. Reads back the maintenance window previously opened on the current session, if any. Does not modify any state."
    }
    remote function getMaintenanceWindow(mcp:Session session) returns MaintenanceWindow|error {
        return readMaintenanceWindow(session);
    }
}
