import ballerina/ai;

// Toolkit that exposes the external sanctions-check REST API as a callable tool
// for the orderFraudAgent. It wraps the GET /country/{countryCode} endpoint,
// which returns the sanction status for a given country.
public isolated class SanctionsCheckToolKit {
    *ai:BaseToolKit;

    # Checks whether a given country is currently under sanctions.
    #
    # + countryCode - ISO country code of the shipping country to check
    # + return - the sanction status of the country, or an error if the check fails
    @ai:AgentTool
    isolated function checkCountrySanctionStatus(string countryCode) returns SanctionStatus|error {
        SanctionStatus status = check sanctionsCheckClient->/country/[countryCode];
        return status;
    }

    public isolated function getTools() returns ai:ToolConfig[] =>
        ai:getToolConfigs([self.checkCountrySanctionStatus]);
}

final SanctionsCheckToolKit sanctionsCheckToolKit = new;

final ai:SystemPrompt orderFraudAgentSystemPrompt = {
    role: "Senior Fraud Analyst",
    instructions: string `You are a senior fraud analyst assistant for an e-commerce platform.
    Analyse each order provided to you and determine whether it is anomalous or potentially
    fraudulent. Consider the order amount, item count, shipping country, and payment method.

    Use the available sanctions check tool to verify whether the shipping country is currently
    under sanctions, and factor that result into your risk assessment.

    Provide a risk score from 0 to 100, a clear explanation for a human fraud analyst, and a
    suggested action of either releasing the order, holding it for manual review, or escalating
    it to the fraud team when the risk is high (for example, when the shipping country is
    sanctioned or the order shows strong signs of fraud).`
};

final ai:Wso2ModelProvider orderFraudAgentModel = check ai:getDefaultModelProvider();

final ai:Agent orderFraudAgent = check new (
    systemPrompt = orderFraudAgentSystemPrompt,
    model = orderFraudAgentModel,
    tools = [sanctionsCheckToolKit]
);
