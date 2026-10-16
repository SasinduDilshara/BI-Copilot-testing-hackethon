import ballerina/mcp;

configurable int serverPort = 9090;

listener mcp:Listener mcpListener = check new (serverPort);

@mcp:ServiceConfig {
    info: {
        name: "Deployment Ops MCP Server",
        version: "1.0.0"
    }
}
service mcp:Service /mcp on mcpListener {

    # Get the current deployment status of a service
    #
    # + serviceName - The name of the service to check
    # + return - The current status of the service, or an error if the service is not found
    remote function getServiceStatus(string serviceName) returns ServiceStatus|error {
        return findServiceStatus(serviceName);
    }

    # List the most recent deployments for a given environment
    #
    # + environment - The environment to list deployments for (e.g. production, staging)
    # + count - The maximum number of recent deployments to return
    # + return - An array of recent deployment records, or an error if the input is invalid
    remote function listRecentDeployments(string environment, int count) returns DeploymentRecord[]|error {
        return findRecentDeployments(environment, count);
    }

    # Restart a service in a given environment
    #
    # + serviceName - The name of the service to restart
    # + environment - The environment in which to restart the service
    # + return - The result of the restart operation, or an error if the service is not found
    remote function restartService(string serviceName, string environment) returns RestartResult|error {
        return triggerServiceRestart(serviceName, environment);
    }
}
