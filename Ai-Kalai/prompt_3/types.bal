// Urgency levels returned by the triage agent.
public type UrgencyLevel "emergency"|"urgent"|"routine";

// Appointment types recommended by the triage agent.
public type AppointmentType "in_person"|"teleconsult";

// Strongly typed patient payload accepted by the triage HTTP endpoint.
public type PatientPayload record {|
    string patientId;
    int age;
    string symptomDescription;
    string symptomDuration;
    boolean hasFever;
    boolean hasChestPain;
    boolean hasBreathingDifficulty;
|};

// Structured triage response produced by the symptom triage agent.
public type TriageResult record {|
    string patientId;
    UrgencyLevel urgencyLevel;
    string recommendedDepartment;
    AppointmentType appointmentType;
    string matchedProtocol;
    string triageNotes;
|};

// Follow-up question submitted by a patient about their earlier triage result.
public type FollowupRequest record {|
    string question;
|};

// Agent's answer to a patient's follow-up question.
public type FollowupResponse record {|
    string patientId;
    string answer;
|};

// Error payload returned when a patient's triage session has expired.
public type SessionExpiredError record {|
    string 'error;
    string patientId;
|};
