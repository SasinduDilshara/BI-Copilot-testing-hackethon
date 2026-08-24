// Severity levels for an incident alert.
public type Severity "critical"|"warning"|"info";

# Incoming alert payload for the /alerts/send endpoint.
public type AlertRequest record {|
    string alertId;
    Severity severity;
    string serviceAffected;
    string description;
    string detectedAt;
    string oncallEngineerEmail;
|};

# Response returned after an alert email has been sent.
public type AlertResponse record {|
    string alertId;
    string status;
    string sentAt;
|};
