import ballerina/ai;
import ballerina/http;

service /triage on new http:Listener(8080) {

    // Accepts a patient payload, invokes the symptom triage agent, and returns a
    // strongly typed structured triage response.
    resource function post assess(@http:Payload PatientPayload patientPayload) returns TriageResult|http:InternalServerError {
        ai:Context context = new;
        context.set("hasFever", patientPayload.hasFever);
        context.set("hasChestPain", patientPayload.hasChestPain);
        context.set("hasBreathingDifficulty", patientPayload.hasBreathingDifficulty);

        string triageQuery = string `Assess the following patient and return the triage decision.
Patient ID: ${patientPayload.patientId}
Age: ${patientPayload.age}
Symptom description: ${patientPayload.symptomDescription}
Symptom duration: ${patientPayload.symptomDuration}`;

        TriageResult|error triageResult = symptomTriageAgent.run(triageQuery, sessionId = patientPayload.patientId, context = context);
        if triageResult is error {
            return <http:InternalServerError>{body: "Failed to obtain a triage decision: " + triageResult.message()};
        }

        // Hard safety rule: chest pain or breathing difficulty always forces emergency,
        // regardless of the agent's decision.
        if patientPayload.hasChestPain || patientPayload.hasBreathingDifficulty {
            triageResult.urgencyLevel = "emergency";
        }

        return triageResult;
    }
}
