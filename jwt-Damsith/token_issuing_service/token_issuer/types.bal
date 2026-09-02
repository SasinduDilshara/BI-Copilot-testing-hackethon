// Request payload sent by a driver's mobile app to authenticate.
public type LoginRequest record {|
    string username;
    string password;
|};

// Result returned by the existing credentials store after validating a driver's
// username/password. Includes the driver identity, depot assignment, and permissions
// that get embedded into the issued token.
public type DriverAuthResult record {|
    string driverId;
    string depotId;
    string[] permissions;
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
