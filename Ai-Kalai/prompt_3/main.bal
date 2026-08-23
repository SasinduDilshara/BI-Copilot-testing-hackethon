import ballerina/ai;
import ballerina/http;

service /triage on new http:Listener(8080) {

    # Accepts a patient's symptom details and returns a structured clinical triage result.
    #
    # + payload - strongly typed patient payload
    # + return - structured triage result, or an error response
    resource function post assess(@http:Payload PatientPayload payload) returns TriageResult|http:InternalServerError {
        ai:Context context = new;
        context.set("hasFever", payload.hasFever);
        context.set("hasChestPain", payload.hasChestPain);
        context.set("hasBreathingDifficulty", payload.hasBreathingDifficulty);

        string query = string `Assess the following patient and provide a triage result.
        Patient ID: ${payload.patientId}
        Age: ${payload.age}
        Symptom description: ${payload.symptomDescription}
        Symptom duration: ${payload.symptomDuration}`;

        ai:QueryMatch[]|error protocolMatches = clinicalProtocolKnowledgeBase.retrieve(payload.symptomDescription, 2);
        if protocolMatches is error {
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve clinical protocols: " + protocolMatches.message()}
            };
        }

        ai:ChatUserMessage augmentedQuery = ai:augmentUserQuery(protocolMatches, query);

        TriageResult|error triageResult = symptomTriageAgent.run(augmentedQuery.content, sessionId = payload.patientId, context = context);
        if triageResult is error {
            return <http:InternalServerError>{
                body: {message: "Failed to generate triage result: " + triageResult.message()}
            };
        }

        // Hard safety rule: chest pain or breathing difficulty always forces an emergency
        // classification, regardless of what the agent determined.
        if payload.hasChestPain || payload.hasBreathingDifficulty {
            triageResult.urgencyLevel = "emergency";
        }

        return triageResult;
    }
}
