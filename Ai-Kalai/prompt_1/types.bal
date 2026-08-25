// Category of a support ticket.
public type TicketCategory "billing"|"technical"|"account"|"other";

// Triage status of a support ticket. "needs_review" indicates the agent's confidence was below
// the configured confidenceThreshold, so no final category is automatically recommended.
public type TicketTriageStatus "completed"|"needs_review";

// Strongly typed support ticket submitted by a customer.
public type SupportTicket record {|
    string id;
    string subject;
    string description;
    string priority;
    string language;
|};

// A single article stored in the support knowledge base.
public type SupportArticle record {|
    string articleId;
    string title;
    string category;
    string content;
|};

// Result returned by the support-article search tool.
public type SupportArticleSearchResult record {|
    string articleId;
    string title;
    string content;
|};

// An article paired with its pre-computed dense embedding vector, used for
// embedding-based similarity retrieval.
type EmbeddedSupportArticle record {|
    SupportArticle article;
    float[] embedding;
|};

// Structured triage result produced by the support ticket agent, as parsed from the agent's
// raw JSON answer. The category here is always the agent's raw classification; whether it is
// surfaced to the caller is decided separately based on the confidenceThreshold.
public type TicketTriageResult record {|
    TicketCategory category;
    int urgency;
    string summary;
    string suggestedReply;
    decimal confidence;
    string referencedArticleId?;
    string referencedArticleTitle?;
|};

// Strongly typed JSON response returned by the support ticket triage endpoint.
public type TicketTriageResponse record {|
    string ticketId;
    TicketTriageStatus status;
    TicketCategory category?;
    int urgency;
    string summary;
    string suggestedReply;
    decimal confidence;
    string referencedArticleId?;
    string referencedArticleTitle?;
|};

// A follow-up question submitted by a customer or agent about a previously triaged ticket.
public type FollowUpQuestionRequest record {|
    string question;
|};

// Strongly typed JSON response containing the answer to a follow-up question about a ticket.
public type FollowUpQuestionResponse record {|
    string ticketId;
    string answer;
|};
