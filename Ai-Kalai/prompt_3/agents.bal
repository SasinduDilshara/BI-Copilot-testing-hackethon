import ballerina/ai;

// System prompt defining the agent as a clinical triage assistant.
final ai:SystemPrompt triageSystemPrompt = {
    role: "Clinical Triage Assistant",
    instructions: string `You are a clinical triage assistant. Given a patient's reported symptoms,
    use the available tools to assess emergency indicators and the urgency implied by symptom duration.
    Based on the tool results and the patient details, determine the overall triage outcome.

    Always respond with the following fields:
    - patientId: the identifier of the patient
    - urgencyLevel: one of "emergency", "urgent", or "routine"
    - recommendedDepartment: the hospital department best suited to treat the patient
    - appointmentType: one of "in_person" or "teleconsult"
    - matchedProtocol: the name of the clinical protocol that matches the presented symptoms
    - triageNotes: a short clinical explanation supporting the triage decision`
};

// Toolkit that groups all symptom assessment tools available to the triage agent.
final EmergencyAssessmentToolKit emergencyAssessmentToolKit = new;

// Conversation memory store keyed by session ID (the patient ID), retaining up to 20 messages
// per session so that different patients' conversations remain isolated from one another.
final ai:ShortTermMemory triageMemory = check new (check new ai:InMemoryShortTermMemoryStore(20));

// AI agent that performs clinical symptom triage using the registered assessment toolkit.
// Sessions are keyed by patient ID (passed as sessionId on each `run` call), which keeps each
// patient's triage conversation and follow-up context isolated from other patients.
final ai:Agent symptomTriageAgent = check new (
    systemPrompt = triageSystemPrompt,
    model = triageModel,
    tools = [emergencyAssessmentToolKit],
    memory = triageMemory
);
