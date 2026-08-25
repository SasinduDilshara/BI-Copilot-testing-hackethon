import ballerina/ai;

// Emergency keywords that, when present in a symptom description, indicate a potential emergency.
final string[] & readonly emergencyKeywords = [
    "chest pain",
    "difficulty breathing",
    "shortness of breath",
    "severe bleeding",
    "unconscious",
    "unresponsive",
    "stroke",
    "seizure",
    "severe pain",
    "choking",
    "heart attack",
    "not breathing"
];

// Groups all symptom assessment tools used by the symptom triage agent.
// Reads hasFever, hasChestPain, and hasBreathingDifficulty from the shared ai:Context
// instead of requiring them as explicit tool parameters.
public isolated class EmergencyAssessmentToolKit {
    *ai:BaseToolKit;

    # Detects emergency keywords in the symptom description and flags critical vital signs
    # (fever, chest pain, breathing difficulty) held in the shared context.
    #
    # + context - shared agent context containing hasFever, hasChestPain, hasBreathingDifficulty
    # + symptomDescription - free text description of the patient's symptoms
    # + return - a summary describing which emergency indicators were detected
    @ai:AgentTool
    isolated function detectEmergencyKeywords(ai:Context context, string symptomDescription) returns string|error {
        string lowerCaseDescription = symptomDescription.toLowerAscii();
        string[] matchedKeywords = from string keyword in emergencyKeywords
            where lowerCaseDescription.includes(keyword)
            select keyword;

        boolean hasFever = check context.getWithType("hasFever");
        boolean hasChestPain = check context.getWithType("hasChestPain");
        boolean hasBreathingDifficulty = check context.getWithType("hasBreathingDifficulty");

        boolean criticalVitalsPresent = hasChestPain || hasBreathingDifficulty;
        string matchedKeywordsText = matchedKeywords.length() > 0 ? string:'join(", ", ...matchedKeywords) : "none";

        return string `Matched emergency keywords: ${matchedKeywordsText}. ` +
            string `Fever present: ${hasFever}. Chest pain present: ${hasChestPain}. ` +
            string `Breathing difficulty present: ${hasBreathingDifficulty}. ` +
            string `Critical vitals flagged: ${criticalVitalsPresent}.`;
    }

    # Maps the reported symptom duration to a suggested urgency level.
    #
    # + symptomDuration - free text description of how long the symptoms have persisted (e.g. "2 hours", "3 days")
    # + return - suggested urgency level derived purely from the duration text
    @ai:AgentTool
    isolated function mapDurationToUrgency(string symptomDuration) returns string {
        string lowerCaseDuration = symptomDuration.toLowerAscii();

        if lowerCaseDuration.includes("minute") || lowerCaseDuration.includes("hour") {
            return "Duration suggests an acute onset - consider emergency or urgent triage.";
        }

        if lowerCaseDuration.includes("day") {
            return "Duration suggests a short-term condition - consider urgent triage.";
        }

        if lowerCaseDuration.includes("week") || lowerCaseDuration.includes("month") || lowerCaseDuration.includes("year") {
            return "Duration suggests a long-standing condition - consider routine triage.";
        }

        return "Duration is unclear - assess using other clinical indicators.";
    }

    public isolated function getTools() returns ai:ToolConfig[] =>
        ai:getToolConfigs([self.detectEmergencyKeywords, self.mapDurationToUrgency]);
}
