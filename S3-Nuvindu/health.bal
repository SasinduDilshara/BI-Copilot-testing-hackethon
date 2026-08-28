import ballerina/http;

// A minimal HTTP health check endpoint, since the SQS consumer itself has no inbound HTTP
// surface. This allows the deployment environment (e.g. an AWS load balancer target group,
// ECS/Kubernetes liveness or readiness probe) to verify that the service process is up and
// responsive after deployment.
listener http:Listener healthCheckListener = new (healthCheckPort);

service /health on healthCheckListener {

    resource function get .() returns http:Ok {
        return {
            body: {status: "UP"}
        };
    }
}
