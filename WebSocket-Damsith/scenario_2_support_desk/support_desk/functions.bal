// Request validation helpers shared by the ticket resources.

isolated function validateCreateRequest(TicketCreateRequest createRequest) returns ErrorPayload? {
    string subjectText = createRequest.ticketSubject.trim();
    if subjectText.length() == 0 {
        return {errorMessage: "ticketSubject must not be empty"};
    }
    string descriptionText = createRequest.ticketDescription.trim();
    if descriptionText.length() == 0 {
        return {errorMessage: "ticketDescription must not be empty"};
    }
    string emailText = createRequest.requesterEmail.trim();
    if !isValidEmail(emailText = emailText) {
        return {errorMessage: "requesterEmail is not a valid email address", errorDetail: emailText};
    }
    return ();
}

isolated function validateUpdateRequest(TicketUpdateRequest updateRequest) returns ErrorPayload? {
    if updateRequest.length() == 0 {
        return {errorMessage: "at least one updatable field must be provided"};
    }
    string? subjectText = updateRequest.ticketSubject;
    if subjectText is string && subjectText.trim().length() == 0 {
        return {errorMessage: "ticketSubject must not be empty"};
    }
    string? descriptionText = updateRequest.ticketDescription;
    if descriptionText is string && descriptionText.trim().length() == 0 {
        return {errorMessage: "ticketDescription must not be empty"};
    }
    return ();
}

isolated function isValidEmail(string emailText) returns boolean {
    int? atIndex = emailText.indexOf("@");
    if atIndex is () || atIndex == 0 || atIndex == emailText.length() - 1 {
        return false;
    }
    string domainPart = emailText.substring(atIndex + 1);
    int? dotIndex = domainPart.indexOf(".");
    return dotIndex is int && dotIndex > 0 && dotIndex < domainPart.length() - 1;
}
