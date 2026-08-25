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

// Known fraud pattern documents used to build a retrieval-augmented knowledge
// base that the orderFraudAgent can reason over alongside each order's details.
final ai:TextDocument[] fraudPatternDocuments = [
    {
        'type: "text",
        content: "Bulk crypto orders: Multiple high-value orders paid via crypto within a short " +
            "time window, often from the same customer or device, are a strong indicator of fraud. " +
            "Fraudsters favour crypto payments because they are difficult to reverse and hard to trace, " +
            "making bulk crypto purchases of high-value or easily resold items a major red flag.",
        metadata: {fileName: "bulk-crypto-orders.txt"}
    },
    {
        'type: "text",
        content: "Sanctioned country shipping: Orders shipping to countries under active trade or " +
            "financial sanctions should be treated as high risk. Shipping to a sanctioned destination " +
            "may indicate an attempt to circumvent export controls or launder funds, and typically " +
            "warrants holding the order or escalating it to the fraud team for manual review.",
        metadata: {fileName: "sanctioned-country-shipping.txt"}
    },
    {
        'type: "text",
        content: "Account takeover signals: A sudden change in shipping address, contact details, or " +
            "payment method shortly before placing a large order, combined with a login from an unusual " +
            "location or device, suggests the account may have been compromised. Account takeover often " +
            "precedes fraudulent high-value purchases using stolen payment credentials.",
        metadata: {fileName: "account-takeover-signals.txt"}
    },
    {
        'type: "text",
        content: "Triangulation fraud: In this scheme, a fraudster sets up a storefront, takes orders " +
            "and payment from genuine customers, then uses stolen payment card details to purchase the " +
            "same items from a legitimate retailer for shipment directly to the customer. Indicators " +
            "include mismatched billing information, shipping to a third-party name different from the " +
            "billing name, and orders placed using card details that do not match the account holder.",
        metadata: {fileName: "triangulation-fraud.txt"}
    },
    {
        'type: "text",
        content: "Mismatched billing and shipping details: Orders where the billing address, shipping " +
            "address, and account holder name differ significantly, especially across countries or " +
            "regions, are commonly associated with stolen card usage. This pattern is especially " +
            "suspicious when combined with expedited shipping or high order values.",
        metadata: {fileName: "mismatched-billing-shipping.txt"}
    },
    {
        'type: "text",
        content: "High-velocity repeat orders: A burst of multiple orders placed in quick succession " +
            "from the same customer, card, or device, particularly for high-value or easily resold " +
            "goods, indicates possible card testing or automated fraud. Card testing typically involves " +
            "many small or moderate orders in rapid succession to validate stolen card numbers before " +
            "a larger fraudulent purchase is attempted.",
        metadata: {fileName: "high-velocity-repeat-orders.txt"}
    }
];

final ai:GenericRecursiveChunker fraudPatternChunker = new (maxChunkSize = 200, maxOverlapSize = 40);

final ai:VectorKnowledgeBase fraudPatternKnowledgeBase = check new (
    check new ai:InMemoryVectorStore(),
    check ai:getDefaultEmbeddingProvider()
);

// Chunks and ingests the known fraud pattern documents into the in-memory
// vector knowledge base so they can be retrieved during order analysis.
function initializeFraudPatternKnowledgeBase() returns error? {
    ai:Chunk[] fraudPatternChunks = [];
    foreach ai:TextDocument fraudPatternDocument in fraudPatternDocuments {
        ai:Chunk[] documentChunks = check fraudPatternChunker.chunk(fraudPatternDocument);
        fraudPatternChunks.push(...documentChunks);
    }
    check fraudPatternKnowledgeBase.ingest(fraudPatternChunks);
}

final error? fraudPatternKnowledgeBaseInitResult = initializeFraudPatternKnowledgeBase();

final ai:SystemPrompt orderFraudAgentSystemPrompt = {
    role: "Senior Fraud Analyst",
    instructions: string `You are a senior fraud analyst assistant for an e-commerce platform.
    Analyse each order provided to you and determine whether it is anomalous or potentially
    fraudulent. Consider the order amount, item count, shipping country, and payment method.

    Along with each order, you will be given relevant known fraud pattern descriptions retrieved
    from a fraud pattern knowledge base (such as bulk crypto orders, sanctioned country shipping,
    account takeover signals, and triangulation fraud). Reason over both the order details and
    these retrieved fraud patterns to decide whether the order matches any known fraud pattern.

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
