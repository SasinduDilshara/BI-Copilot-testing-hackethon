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

        // Start/refresh the session's activity window so follow-up questions can be asked
        // about this triage result within the configured timeout.
        touchSession(payload.patientId);

        return triageResult;
    }

    # Accepts a patient's follow-up question about their earlier triage result and answers it
    # using the same agent session, so the agent recalls the prior triage context for that patient.
    #
    # + patientId - the patient ID that identifies the triage session
    # + followupRequest - the patient's follow-up question
    # + return - the agent's answer, a Gone response if the session has expired, or an error response
    resource function post sessions/[string patientId]/followup(@http:Payload FollowupRequest followupRequest)
            returns FollowupResponse|http:Gone|http:InternalServerError {
        boolean sessionExpired = isSessionExpired(patientId);
        if sessionExpired {
            return <http:Gone>{
                body: <SessionExpiredError>{'error: "Session expired", patientId}
            };
        }

        string|error answer = symptomTriageAgent.run(followupRequest.question, sessionId = patientId);
        if answer is error {
            return <http:InternalServerError>{
                body: {message: "Failed to answer follow-up question: " + answer.message()}
            };
        }

        touchSession(patientId);

        return {patientId, answer};
    }
}
