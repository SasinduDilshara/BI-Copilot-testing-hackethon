import ballerina/http;
import ballerina/pdf;

// Reads the uploaded PDF bytes from the request in-memory and extracts the per-page text content.
function extractPdfPages(http:Request request) returns string[]|BadRequestError {
    byte[]|http:ClientError uploadedBytes = request.getBinaryPayload();
    if uploadedBytes is http:ClientError {
        return {
            body: {
                message: string `Failed to read the uploaded document: ${uploadedBytes.message()}`
            }
        };
    }

    string[]|pdf:Error pages = pdf:extractText(uploadedBytes);
    if pages is pdf:Error {
        return {
            body: {
                message: string `Failed to extract text from the uploaded document: ${pages.message()}`
            }
        };
    }

    return pages;
}

service /documents on new http:Listener(8090) {

    # Builds an HTML invoice from the request payload and converts it to a PDF document.
    #
    # + invoiceRequest - The invoice data used to render the document
    # + return - The generated PDF bytes, or a typed bad request error if the PDF could not be generated
    resource function post invoices/render(InvoiceRequest invoiceRequest) returns http:Response|BadRequestError {
        string invoiceHtml = buildInvoiceHtml(invoiceRequest);
        byte[]|pdf:Error pdfBytes = pdf:parseHtml(invoiceHtml, pageSize = pdf:A4, margins = {
            top: 36,
            right: 36,
            bottom: 36,
            left: 36
        });
        if pdfBytes is pdf:Error {
            return {
                body: {
                    message: string `Failed to generate the invoice PDF: ${pdfBytes.message()}`
                }
            };
        }

        http:Response response = new;
        response.setBinaryPayload(pdfBytes, contentType = "application/pdf");
        return response;
    }

    # Extracts text content from each page of an uploaded PDF document.
    #
    # + request - The inbound request carrying the raw PDF bytes
    # + return - The extracted per-page text content, or a typed bad request error if the PDF could not be processed
    resource function post documents/extract(http:Request request) returns ExtractResponse|BadRequestError {
        string[]|BadRequestError pages = extractPdfPages(request);
        if pages is BadRequestError {
            return pages;
        }

        ExtractedPage[] extractedPages = [];
        foreach int i in 0 ..< pages.length() {
            extractedPages.push({page: i + 1, text: pages[i]});
        }

        return {
            pageCount: pages.length(),
            pages: extractedPages
        };
    }

    # Searches the text content of an uploaded PDF document for a query string.
    #
    # + request - The inbound request carrying the raw PDF bytes
    # + q - The case-insensitive query string to search for
    # + return - The matching pages with surrounding snippets, or a typed bad request error
    resource function post documents/search(http:Request request, string q) returns SearchResponse|BadRequestError {
        if q.trim().length() == 0 {
            return {
                body: {
                    message: "Query parameter 'q' must not be empty."
                }
            };
        }

        string[]|BadRequestError pages = extractPdfPages(request);
        if pages is BadRequestError {
            return pages;
        }

        SearchMatch[] matches = [];
        foreach int i in 0 ..< pages.length() {
            string? snippet = buildSnippet(pages[i], q);
            if snippet is string {
                matches.push({page: i + 1, snippet: snippet});
            }
        }

        return {
            query: q,
            matches: matches
        };
    }
}
