import ballerina/ai;
import ballerina/lang.regexp;

// Keywords that indicate a potential emergency when found in the symptom description.
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
    "can't breathe",
    "cannot breathe",
    "heart attack",
    "choking"
];

// Groups all symptom assessment tools used by the symptom triage agent.
public isolated class EmergencyAssessmentToolKit {
    *ai:BaseToolKit;

    // Detects emergency keywords in the symptom description and factors in the shared
    // context values (hasFever, hasChestPain, hasBreathingDifficulty) set for the run.
    @ai:AgentTool
    public isolated function detectEmergencyKeywords(ai:Context context, string symptomDescription) returns string[]|error {
        string[] matchedKeywords = [];
        string lowerCaseDescription = symptomDescription.toLowerAscii();
        foreach string keyword in emergencyKeywords {
            if lowerCaseDescription.includes(keyword) {
                matchedKeywords.push(keyword);
            }
        }

        boolean hasChestPain = check context.getWithType("hasChestPain");
        boolean hasBreathingDifficulty = check context.getWithType("hasBreathingDifficulty");
        if hasChestPain {
            matchedKeywords.push("flag:hasChestPain");
        }
        if hasBreathingDifficulty {
            matchedKeywords.push("flag:hasBreathingDifficulty");
        }
        return matchedKeywords;
    }

    // Maps the reported symptom duration to a suggested urgency level, taking the shared
    // context values (hasFever, hasChestPain, hasBreathingDifficulty) into account.
    @ai:AgentTool
    public isolated function mapDurationToUrgency(ai:Context context, string symptomDuration) returns string|error {
        boolean hasFever = check context.getWithType("hasFever");
        boolean hasChestPain = check context.getWithType("hasChestPain");
        boolean hasBreathingDifficulty = check context.getWithType("hasBreathingDifficulty");

        if hasChestPain || hasBreathingDifficulty {
            return "emergency";
        }

        string:RegExp hoursPattern = re `([0-9]+)\s*hour`;
        string:RegExp daysPattern = re `([0-9]+)\s*day`;
        string:RegExp weeksPattern = re `([0-9]+)\s*week`;
        string lowerCaseDuration = symptomDuration.toLowerAscii();

        regexp:Groups? hoursMatch = hoursPattern.findGroups(lowerCaseDuration);
        if hoursMatch is regexp:Groups {
            regexp:Span? valueSpan = hoursMatch[1];
            if valueSpan is regexp:Span {
                int hours = check int:fromString(valueSpan.substring());
                if hasFever && hours <= 24 {
                    return "urgent";
                }
                return hours <= 6 ? "urgent" : "routine";
            }
        }

        regexp:Groups? daysMatch = daysPattern.findGroups(lowerCaseDuration);
        if daysMatch is regexp:Groups {
            regexp:Span? valueSpan = daysMatch[1];
            if valueSpan is regexp:Span {
                int days = check int:fromString(valueSpan.substring());
                if hasFever && days <= 3 {
                    return "urgent";
                }
                return days <= 1 ? "urgent" : "routine";
            }
        }

        regexp:Groups? weeksMatch = weeksPattern.findGroups(lowerCaseDuration);
        if weeksMatch is regexp:Groups {
            return "routine";
        }

        return hasFever ? "urgent" : "routine";
    }

    public isolated function getTools() returns ai:ToolConfig[] =>
        ai:getToolConfigs([self.detectEmergencyKeywords, self.mapDurationToUrgency]);
}
