// Externalized settings. Values are supplied through Config.toml.

configurable int servicePort = ?;
configurable int liveServicePort = ?;
configurable string defaultPriority = ?;
configurable string defaultAssignee = ?;
configurable int maxPageSize = ?;

final TicketPriority defaultTicketPriority = resolveDefaultPriority(priorityText = defaultPriority);

isolated function resolveDefaultPriority(string priorityText) returns TicketPriority {
    TicketPriority|error convertedPriority = priorityText.cloneWithType();
    if convertedPriority is TicketPriority {
        return convertedPriority;
    }
    return MEDIUM;
}
