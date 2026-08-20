import ballerina/ai;
import ballerina/log;
import ballerina/math.vector;

// A small in-memory knowledge base used by the support-article search tool.
final readonly & SupportArticle[] knowledgeBaseArticles = [
    {
        articleId: "KB-1001",
        title: "How to update your billing information",
        category: "billing",
        content: "To update your billing information, go to Account Settings > Billing, " +
            "select 'Update Payment Method', and enter your new card details. Changes take " +
            "effect immediately and apply to the next billing cycle."
    },
    {
        articleId: "KB-1002",
        title: "Understanding duplicate charges and refunds",
        category: "billing",
        content: "Duplicate charges are usually caused by a delayed payment confirmation. " +
            "If you see two charges for the same invoice, they are automatically reconciled " +
            "within 3-5 business days. If not, contact support with the invoice number to " +
            "request a manual refund."
    },
    {
        articleId: "KB-2001",
        title: "Troubleshooting login and connectivity issues",
        category: "technical",
        content: "If you are unable to log in or the application is unresponsive, clear your " +
            "browser cache, verify your internet connection, and confirm the service status " +
            "page shows no ongoing incidents. Persistent issues should be escalated with logs."
    },
    {
        articleId: "KB-2002",
        title: "Resolving API integration errors",
        category: "technical",
        content: "API errors such as 401 or 403 usually indicate an expired or invalid access " +
            "token. Regenerate your API key from the Developer Console and ensure the " +
            "Authorization header uses the 'Bearer' scheme."
    },
    {
        articleId: "KB-3001",
        title: "Resetting your account password",
        category: "account",
        content: "To reset your password, click 'Forgot Password' on the login page and follow " +
            "the link sent to your registered email. The link expires after 30 minutes."
    },
    {
        articleId: "KB-3002",
        title: "Managing account access and permissions",
        category: "account",
        content: "Account administrators can manage user roles and permissions from the " +
            "'Team Management' section. Only administrators can invite or remove members."
    },
    {
        articleId: "KB-9001",
        title: "General contact and escalation guidelines",
        category: "other",
        content: "For requests that do not fall under billing, technical, or account issues, " +
            "please provide as much detail as possible so the request can be routed to the " +
            "correct department."
    }
];

// Lazily computed, cached embeddings for the knowledge base articles, used for
// embedding-based similarity retrieval. Guarded by a lock since agent tool invocations may
// run concurrently.
isolated EmbeddedSupportArticle[] embeddedKnowledgeBaseArticles = [];

# Returns the cached article embeddings, computing and caching them on first use.
#
# + embeddingProvider - the embedding provider used to embed each article
# + return - the embedded articles, or an error if embedding generation fails
isolated function getEmbeddedKnowledgeBaseArticles(ai:Wso2EmbeddingProvider embeddingProvider)
    returns EmbeddedSupportArticle[]|error {
    lock {
        if embeddedKnowledgeBaseArticles.length() > 0 {
            return embeddedKnowledgeBaseArticles.clone();
        }
    }

    EmbeddedSupportArticle[] computedEmbeddings = [];
    foreach SupportArticle article in knowledgeBaseArticles {
        ai:Chunk articleChunk = {'type: "text", content: article.title + ". " + article.content};
        ai:Vector|ai:SparseVector|ai:HybridVector|ai:Error embedding = embeddingProvider->embed(articleChunk);
        if embedding is ai:Error {
            return error("Failed to generate embedding for article " + article.articleId, embedding);
        }
        if !(embedding is ai:Vector) {
            return error("Embedding provider returned an unsupported embedding type for article " +
                article.articleId);
        }
        computedEmbeddings.push({article, embedding});
    }

    lock {
        embeddedKnowledgeBaseArticles = computedEmbeddings.clone();
    }
    return computedEmbeddings;
}

# Searches the support knowledge base using embedding-based (semantic) similarity between the
# ticket description and the knowledge base articles.
#
# + category - the ticket category (billing, technical, account, or other)
# + description - the ticket description used to find semantically similar content
# + return - the best matching support article, an error describing why semantic search is
# unavailable, or an error if no article could be matched
isolated function searchSupportArticlesByEmbedding(string category, string description)
    returns SupportArticleSearchResult|error {
    ai:Wso2EmbeddingProvider embeddingProvider;
    lock {
        ai:Wso2EmbeddingProvider|error providerResult = supportArticleEmbeddingProvider;
        if providerResult is error {
            log:printWarn(embeddingProviderUnavailableWarning, providerResult);
            return error("Embedding-based retrieval is unavailable: the default embedding " +
                "provider could not be initialized.", providerResult);
        }
        embeddingProvider = providerResult;
    }

    EmbeddedSupportArticle[] embeddedArticles = check getEmbeddedKnowledgeBaseArticles(embeddingProvider);

    ai:Chunk queryChunk = {'type: "text", content: "Category: " + category + ". " + description};
    ai:Vector|ai:SparseVector|ai:HybridVector|ai:Error queryEmbedding = embeddingProvider->embed(queryChunk);
    if queryEmbedding is ai:Error {
        return error("Failed to generate embedding for the query", queryEmbedding);
    }
    if !(queryEmbedding is ai:Vector) {
        return error("Embedding provider returned an unsupported embedding type for the query");
    }

    EmbeddedSupportArticle? bestMatch = ();
    float bestSimilarity = -1.0;
    foreach EmbeddedSupportArticle embeddedArticle in embeddedArticles {
        float similarity = vector:cosineSimilarity(queryEmbedding, embeddedArticle.embedding);
        if similarity > bestSimilarity {
            bestSimilarity = similarity;
            bestMatch = embeddedArticle;
        }
    }

    if bestMatch is () {
        return error("No matching support article was found using embedding-based retrieval");
    }

    SupportArticle matchedArticle = bestMatch.article;
    return {
        articleId: matchedArticle.articleId,
        title: matchedArticle.title,
        content: matchedArticle.content
    };
}

# Finds the most relevant support article for a ticket using embedding-based (semantic)
# similarity search. This is the preferred retrieval tool. If the installed environment does
# not have a working embedding provider, it reports the limitation so the caller can fall back
# to the keyword-based searchSupportArticles tool.
#
# + category - the ticket category (billing, technical, account, or other)
# + description - the ticket description used to find semantically similar content
# + return - the best matching support article, or an error explaining that semantic search is
# unavailable and that the searchSupportArticles tool should be used instead
@ai:AgentTool
isolated function findRelevantSupportArticle(string category, string description) returns SupportArticleSearchResult|error {
    SupportArticleSearchResult|error result = searchSupportArticlesByEmbedding(category, description);
    if result is error {
        log:printWarn("Embedding-based support article search failed, keyword search should be used instead",
                result);
        return error("Semantic search is unavailable (" + result.message() +
            "). Use the searchSupportArticles tool instead.");
    }
    return result;
}

# Searches the support knowledge base using the ticket category and description to find the
# most relevant article.
#
# + category - the ticket category (billing, technical, account, or other)
# + description - the ticket description used to match relevant content
# + return - the best matching support article, or an error if none is found
@ai:AgentTool
isolated function searchSupportArticles(string category, string description) returns SupportArticleSearchResult|error {
    string normalizedDescription = description.toLowerAscii();

    SupportArticle[] categoryMatches = from SupportArticle article in knowledgeBaseArticles
        where article.category == category.toLowerAscii()
        select article;

    SupportArticle[] candidates = categoryMatches.length() > 0 ? categoryMatches : knowledgeBaseArticles;

    SupportArticle? bestMatch = ();
    int bestScore = -1;
    foreach SupportArticle article in candidates {
        string[] keywords = re `\s+`.split(article.title.toLowerAscii());
        int score = 0;
        foreach string keyword in keywords {
            boolean containsKeyword = normalizedDescription.includes(keyword);
            if containsKeyword {
                score += 1;
            }
        }
        if score > bestScore {
            bestScore = score;
            bestMatch = article;
        }
    }

    if bestMatch is () {
        return error("No matching support article was found");
    }

    SupportArticle matchedArticle = bestMatch;
    return {
        articleId: matchedArticle.articleId,
        title: matchedArticle.title,
        content: matchedArticle.content
    };
}

# Invokes the supportTicketAgent to triage a support ticket and returns a strongly typed result.
#
# + ticket - the support ticket to triage
# + return - the structured triage result, or an error if triage or parsing fails
function triageSupportTicket(SupportTicket ticket) returns TicketTriageResult|error {
    string triageQuery = "Triage the following support ticket and respond with ONLY a " +
        "single valid JSON object (no markdown, no extra text) that matches exactly this shape: " +
        "{\"category\": \"billing\"|\"technical\"|\"account\"|\"other\", \"urgency\": <integer 1-5>, " +
        "\"summary\": \"<short summary>\", \"suggestedReply\": \"<suggested customer reply>\", " +
        "\"confidence\": <number 0.0-1.0>, \"referencedArticleId\": \"<article id if used, otherwise omit>\", " +
        "\"referencedArticleTitle\": \"<article title if used, otherwise omit>\"}." + "\n\n" +
        "Ticket ID: " + ticket.id + "\n" +
        "Subject: " + ticket.subject + "\n" +
        "Description: " + ticket.description + "\n" +
        "Priority: " + ticket.priority + "\n" +
        "Language: " + ticket.language;

    string agentAnswer = check supportTicketAgent.run(triageQuery, sessionId = ticket.id);
    string jsonAnswer = extractJsonObject(agentAnswer);
    TicketTriageResult triageResult = check jsonAnswer.fromJsonStringWithType(TicketTriageResult);
    return triageResult;
}

# Answers a follow-up question about a previously triaged ticket, using the ticket ID as the
# conversation (session) key so the agent recalls the earlier triage conversation for that
# specific ticket. Conversations for different ticket IDs are kept isolated since each uses a
# distinct sessionId.
#
# + ticketId - the ID of the ticket the follow-up question relates to
# + question - the follow-up question to ask the agent
# + return - the agent's answer, or an error if the agent invocation fails
function answerFollowUpQuestion(string ticketId, string question) returns string|error {
    string agentAnswer = check supportTicketAgent.run(question, sessionId = ticketId);
    return agentAnswer;
}

# Extracts the JSON object substring from a raw text response, stripping any surrounding
# markdown code fences or extraneous text.
#
# + rawText - the raw text possibly containing a JSON object
# + return - the extracted JSON object string
function extractJsonObject(string rawText) returns string {
    int? startIndex = rawText.indexOf("{");
    int? endIndex = rawText.lastIndexOf("}");
    if startIndex is int && endIndex is int && endIndex >= startIndex {
        return rawText.substring(startIndex, endIndex + 1);
    }
    return rawText;
}
