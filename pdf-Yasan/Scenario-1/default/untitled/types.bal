import ballerina/http;

// Invoice request/response types

type InvoiceLine record {|
    string description;
    int qty;
    decimal unitPrice;
|};

type InvoiceRequest record {|
    string invoiceNo;
    string customer;
    string issuedOn;
    InvoiceLine[] lines;
|};

// Document extraction response types

type ExtractedPage record {|
    int page;
    string text;
|};

type ExtractResponse record {|
    int pageCount;
    ExtractedPage[] pages;
|};

// Document search response types

type SearchMatch record {|
    int page;
    string snippet;
|};

type SearchResponse record {|
    string query;
    SearchMatch[] matches;
|};

// Error response type

type ErrorDetails record {|
    string message;
|};

type BadRequestError record {|
    *http:BadRequest;
    ErrorDetails body;
|};

type NotFoundError record {|
    *http:NotFound;
    ErrorDetails body;
|};
