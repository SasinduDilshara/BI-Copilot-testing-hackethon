// Maximum number of log entries retained per service.
const int MAX_ENTRIES_PER_SERVICE = 1000;

// In-memory store of log entries keyed by serviceId, shared between the TCP
// log aggregation listener and the HTTP query service.
isolated map<LogEntry[]> logStore = {};

// Registry of currently active TCP connections keyed by a unique connection
// ID, shared between the TCP log aggregation listener and the HTTP query
// service.
isolated map<ConnectionInfo> connectionRegistry = {};

// Adds a log entry to the store for its serviceId, dropping the oldest
// entry when the per-service limit is exceeded.
isolated function addLogEntry(LogEntry logEntry) {
    lock {
        string serviceId = logEntry.serviceId;
        LogEntry[] existingEntries = logStore[serviceId] ?: [];
        existingEntries.push(logEntry.clone());
        if existingEntries.length() > MAX_ENTRIES_PER_SERVICE {
            _ = existingEntries.shift();
        }
        logStore[serviceId] = existingEntries;
    }
}

// Returns a clone of the stored log entries for the given serviceId.
isolated function getLogEntries(string serviceId) returns LogEntry[] {
    lock {
        LogEntry[] existingEntries = logStore[serviceId] ?: [];
        return existingEntries.clone();
    }
}

// Returns a clone of the ERROR level log entries for the given serviceId.
isolated function getErrorLogEntries(string serviceId) returns LogEntry[] {
    lock {
        LogEntry[] existingEntries = logStore[serviceId] ?: [];
        LogEntry[] errorEntries = from LogEntry entry in existingEntries
            where entry.level == "ERROR"
            select entry;
        return errorEntries.clone();
    }
}

// Returns the list of all known service IDs.
isolated function getServiceIds() returns string[] {
    lock {
        return logStore.keys().clone();
    }
}

// Registers a newly connected TCP client under the given connection ID.
isolated function registerConnection(string connectionId, ConnectionInfo connectionInfo) {
    lock {
        connectionRegistry[connectionId] = connectionInfo.clone();
    }
}

// Deregisters a TCP connection when it closes or errors out.
isolated function deregisterConnection(string connectionId) {
    lock {
        _ = connectionRegistry.removeIfHasKey(connectionId);
    }
}

// Updates the serviceId and increments the total lines received for a
// registered connection once the first (or a subsequent) log line arrives.
isolated function recordConnectionLogLine(string connectionId, string serviceId) {
    lock {
        ConnectionInfo? connectionInfo = connectionRegistry[connectionId];
        if connectionInfo is ConnectionInfo {
            connectionInfo.serviceId = serviceId;
            connectionInfo.totalLinesReceived += 1;
            connectionRegistry[connectionId] = connectionInfo;
        }
    }
}

// Returns a clone of all currently active connections.
isolated function getActiveConnections() returns ConnectionInfo[] {
    lock {
        return connectionRegistry.toArray().clone();
    }
}
