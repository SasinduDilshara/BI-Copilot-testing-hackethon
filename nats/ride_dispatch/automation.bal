import ballerina/time;

public function main() returns error? {
    RideRequest rideRequest = {
        rideId: "ride-1001",
        riderId: "rider-501",
        city: "colombo",
        pickupLat: 6.9271,
        pickupLng: 79.8612,
        requestedAt: time:utcToString(time:utcNow())
    };
    check publishRideRequest(rideRequest);
}
