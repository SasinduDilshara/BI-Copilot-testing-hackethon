// Category of a support ticket.
public type TicketCategory "billing"|"technical"|"account"|"other";

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

// Structured triage result produced by the support ticket agent.
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
    TicketCategory category;
    int urgency;
    string summary;
    string suggestedReply;
    decimal confidence;
    string referencedArticleId?;
    string referencedArticleTitle?;
|};
