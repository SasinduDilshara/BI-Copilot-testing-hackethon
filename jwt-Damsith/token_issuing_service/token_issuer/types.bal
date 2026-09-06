// Request payload sent by a driver's mobile app to authenticate. When a depot manager is
// standing in for a driver (e.g. dispute handling), actingDriverId identifies the driver
// whose session this is, while username/password remain the manager's own credentials.
public type LoginRequest record {|
    string username;
    string password;
    string actingDriverId?;
|};

// Identifies who is actually authenticated: a genuine driver session, or a depot manager
// acting on behalf of a driver.
public type ActorType "DRIVER"|"MANAGER";

// Result returned by the existing credentials store after validating credentials.
// For a plain driver login, driverId/depotId/permissions describe the driver themselves.
// For a manager-assisted login, driverId/depotId describe the driver being acted upon,
// while actorId/actorType/permissions describe the authenticated manager.
public type DriverAuthResult record {|
    string driverId;
    string depotId;
    string[] permissions;
    string actorId;
    ActorType actorType;
|};

// Response returned to the mobile app on successful login.
public type LoginResponse record {|
    string token;
    string tokenType = "Bearer";
    decimal expiresIn;
|};

// Error response body for failed login attempts.
public type ErrorResponse record {|
    string message;
|};
