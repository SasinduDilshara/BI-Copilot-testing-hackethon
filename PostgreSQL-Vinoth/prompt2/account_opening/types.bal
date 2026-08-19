
public type AccountApplication record {|
    string applicationId;
    string customerId;
    string countryCode;
    string fullName;
    string dateOfBirth;
|};

public type IdentityCheckRequest record {|
    string applicationId;
    string fullName;
    string dateOfBirth;
    string countryCode;
|};