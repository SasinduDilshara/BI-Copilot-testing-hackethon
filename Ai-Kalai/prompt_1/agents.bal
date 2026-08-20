import ballerina/ai;

// Minimum agent confidence (0.0-1.0) required to automatically recommend a final category.
// Triage results below this threshold are marked as needs_review instead.
configurable decimal confidenceThreshold = 0.6;

final ai:ModelProvider supportTicketModel = check ai:getDefaultModelProvider();

// The installed ballerina/ai module does not ship a built-in, zero-infrastructure
// ai:VectorStore implementation (concrete stores such as Milvus, Pinecone, Weaviate, and
// PGVector are separate connectors that require external vector database infrastructure),
// so ai:VectorKnowledgeBase cannot be used here. Embedding generation itself, however, is
// supported via ai:getDefaultEmbeddingProvider(). Embedding-based retrieval below is therefore
// implemented manually over the small in-memory knowledge base: articles are embedded once
// using the default embedding provider and ranked using cosine similarity
// (ballerina/math.vector) against the embedded query. If the embedding provider is
// unavailable at runtime, this falls back to the typed keyword search tool.
final ai:Wso2EmbeddingProvider|error supportArticleEmbeddingProvider = ai:getDefaultEmbeddingProvider();

final ai:SystemPrompt supportTicketAgentSystemPrompt = {
    role: "Enterprise Customer Support Triage Assistant",
    instructions: "You are an enterprise customer-support triage assistant. For every " +
        "support ticket you receive, you must:" + "\n" +
        "1. Classify the ticket into exactly one category: \"billing\", \"technical\", \"account\", or \"other\"." + "\n" +
        "2. Determine the urgency of the ticket as an integer from 1 (lowest) to 5 (highest)." + "\n" +
        "3. Generate a short, clear summary of the ticket." + "\n" +
        "4. Generate a polite, helpful suggested reply to send to the customer." + "\n" +
        "5. Provide a confidence value between 0.0 and 1.0 reflecting how confident you are in " +
        "the classification." + "\n" +
        "6. When you need more information to classify the ticket accurately or to craft a " +
        "better reply, call the findRelevantSupportArticle tool using the ticket category and " +
        "description to retrieve the most relevant knowledge base article using semantic " +
        "(meaning-based) search. If that tool reports that semantic search is unavailable, call " +
        "the searchSupportArticles tool instead, which performs keyword-based search. If you use " +
        "an article, incorporate its guidance into the suggested reply and report its article ID " +
        "and title." + "\n" +
        "Always respond truthfully and only with information relevant to the ticket."
};

// Conversation memory keyed by sessionId. Each triage/follow-up call passes the ticket ID as
// the sessionId (see triageSupportTicket and answerFollowUpQuestion in functions.bal), so
// conversation history for one ticket never leaks into another ticket's conversation.
final ai:Memory supportTicketAgentMemory = check new ai:ShortTermMemory(check new ai:InMemoryShortTermMemoryStore(20));

final ai:Agent supportTicketAgent = check new (
    systemPrompt = supportTicketAgentSystemPrompt,
    model = supportTicketModel,
    tools = [findRelevantSupportArticle, searchSupportArticles],
    memory = supportTicketAgentMemory
);

// Logged lazily (on first use, see functions.bal) rather than in a module init() function,
// to avoid any module-level initialization ordering issues.
final string embeddingProviderUnavailableWarning = "Embedding-based support article retrieval is unavailable: " +
    "the default embedding provider could not be initialized. Falling back to the typed keyword search tool " +
    "(searchSupportArticles).";
