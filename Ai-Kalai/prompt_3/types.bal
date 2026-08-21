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
