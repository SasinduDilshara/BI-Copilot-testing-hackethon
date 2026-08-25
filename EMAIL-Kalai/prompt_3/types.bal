// Request payload for the HR onboarding endpoint.
type OnboardRequest record {|
    string employeeId;
    string fullName;
    string personalEmail;
    string department;
    string startDate;
    string managerEmail;
    string managerName;
    string itTeamEmail;
|};

// Response payload returned after processing an onboarding request.
type OnboardResponse record {|
    string employeeId;
    int emailsSent;
    string status;
    string[] failedRecipients?;
|};

// Response payload returned after checking for the IT provisioning confirmation email.
type ProvisioningCheckResponse record {|
    string employeeId;
    string provisioningStatus;
    string provisioningConfirmation?;
|};

// Strongly typed validation error detail for invalid onboarding requests.
type ValidationErrorDetail record {|
    string 'field;
    string reason;
|};
