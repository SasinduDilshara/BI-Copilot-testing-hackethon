// Request payload for the token validation endpoint.
type TokenValidationRequest record {|
    string token;
    string clientId;
    string requestedScope;
|};

// Result of a token validation, either from cache or from the upstream authorization server.
type TokenValidationResult record {|
    boolean valid;
    string clientId;
    string[] allowedScopes;
    int expiresInSeconds;
    boolean cacheHit;
    int cachedAt;
|};

// Details of a token known to the upstream authorization server.
type UpstreamTokenDetails record {|
    string clientId;
    string[] allowedScopes;
    int expiresInSeconds;
|};

// Structured error body returned when a token cannot be validated.
type ValidationErrorDetail record {|
    string message;
    string token;
|};

// Request payload for the token revocation endpoint.
type TokenRevocationRequest record {|
    string token;
    string reason;
|};

// Result of a token revocation attempt.
type TokenRevocationResult record {|
    boolean revoked;
    string reason;
|};
