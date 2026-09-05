// Request payload for both registration and login. The password field is never
// logged, stored in plain form, or echoed back in any response.
public type Credentials record {|
    string username;
    string password;
|};

// Generic success/failure response. Deliberately contains no trace of the
// password or anything derived from it.
public type AuthResult record {|
    string message;
|};

// Internal representation of a stored account. Only the Argon2 hash is kept;
// the plaintext password is never retained.
type Account record {|
    string username;
    string passwordHash;
|};
