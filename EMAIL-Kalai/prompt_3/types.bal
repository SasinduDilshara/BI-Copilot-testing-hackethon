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
