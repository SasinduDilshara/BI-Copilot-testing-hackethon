// Represents a ride dispatch request published to the NATS subject rides.request.{city}
public type RideRequest record {|
    string rideId;
    string riderId;
    string city;
    decimal pickupLat;
    decimal pickupLng;
    string requestedAt;
|};

// Represents a ride request that was rejected because its city is not served by
// this deployment, published to the NATS subject rides.rejected
public type RejectedRideRequest record {|
    *RideRequest;
    string reason;
|};
