import ballerinax/nats;

// Publishes a ride request to the subject rides.request.{city}.
function publishRideRequest(RideRequest rideRequest) returns nats:Error? {
    string subject = string `rides.request.${rideRequest.city}`;
    nats:AnydataMessage message = {
        content: rideRequest,
        subject: subject
    };
    check natsClient->publishMessage(message);
}

// Publishes a ride request that falls outside the served cities to rides.rejected,
// annotated with the reason it was rejected.
function publishRejectedRideRequest(RideRequest rideRequest, string reason) returns nats:Error? {
    RejectedRideRequest rejectedRideRequest = {...rideRequest, reason};
    nats:AnydataMessage message = {
        content: rejectedRideRequest,
        subject: "rides.rejected"
    };
    check natsClient->publishMessage(message);
}

// Returns true if the given city is served by this deployment.
function isCityServed(string city) returns boolean {
    return servedCities.indexOf(city) is int;
}
