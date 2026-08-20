import ballerina/http;

service /support on new http:Listener(9090) {

    # Accepts a support ticket, triages it using the supportTicketAgent, and returns a
    # strongly typed triage response.
    #
    # + ticket - the strongly typed support ticket to triage
    # + return - the triage response, or an error if triage fails
    resource function post tickets(@http:Payload SupportTicket ticket) returns TicketTriageResponse|http:InternalServerError {
        TicketTriageResult|error triageResult = triageSupportTicket(ticket);

        if triageResult is error {
            return <http:InternalServerError>{
                body: {message: "Failed to triage support ticket: " + triageResult.message()}
            };
        }

        return {
            ticketId: ticket.id,
            category: triageResult.category,
            urgency: triageResult.urgency,
            summary: triageResult.summary,
            suggestedReply: triageResult.suggestedReply,
            confidence: triageResult.confidence,
            referencedArticleId: triageResult?.referencedArticleId,
            referencedArticleTitle: triageResult?.referencedArticleTitle
        };
    }

    # Accepts a follow-up question about a previously triaged ticket and answers it using the
    # supportTicketAgent, continuing that ticket's own conversation.
    #
    # + ticketId - the ID of the ticket the follow-up question relates to
    # + followUpQuestion - the follow-up question to ask
    # + return - the follow-up answer, or an error if answering fails
    resource function post tickets/[string ticketId]/questions(@http:Payload FollowUpQuestionRequest followUpQuestion)
        returns FollowUpQuestionResponse|http:InternalServerError {
        string|error answer = answerFollowUpQuestion(ticketId, followUpQuestion.question);

        if answer is error {
            return <http:InternalServerError>{
                body: {message: "Failed to answer follow-up question: " + answer.message()}
            };
        }

        return {
            ticketId: ticketId,
            answer: answer
        };
    }
}
