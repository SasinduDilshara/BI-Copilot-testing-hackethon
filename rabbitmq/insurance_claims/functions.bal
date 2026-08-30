import ballerinax/rabbitmq;

# Derives the routing key for a claim submission from its claim type and priority.
# The claim type is normalized to lower case and any whitespace is replaced with a dot
# to build a `claim.<type>.<priority>` style routing key, e.g. `claim.auto.high`.
#
# + claimType - the type of the claim (e.g. "auto", "health", "property")
# + priority - the priority of the claim (e.g. "high", "low")
# + return - the derived routing key
function buildRoutingKey(string claimType, string priority) returns string {
    string normalizedType = claimType.trim().toLowerAscii();
    string normalizedPriority = priority.trim().toLowerAscii();
    string:RegExp whitespacePattern = re `\s+`;
    normalizedType = whitespacePattern.replaceAll(normalizedType, "-");
    normalizedPriority = whitespacePattern.replaceAll(normalizedPriority, "-");
    return string `claim.${normalizedType}.${normalizedPriority}`;
}

# Reads the current retry count from a claim message's headers. Absent or malformed
# values are treated as the first attempt (0 prior retries).
#
# + properties - the message's basic properties, if present
# + return - the number of times this message has already been retried
function extractRetryCount(rabbitmq:BasicProperties? properties) returns int {
    if properties is () {
        return 0;
    }
    map<anydata>? headers = properties?.headers;
    if headers is () {
        return 0;
    }
    anydata retryCountValue = headers[RETRY_COUNT_HEADER];
    if retryCountValue is int {
        return retryCountValue;
    }
    return 0;
}

# Simulates the business validation/processing of a claim submission. Returns an error
# when the claim cannot be processed so the caller can decide to retry or dead-letter it.
#
# + claimSubmission - the claim submission to process
# + return - () on success, or an error describing why processing failed
function processClaim(ClaimSubmission claimSubmission) returns error? {
    if claimSubmission.claimAmount <= 0d {
        return error(string `Invalid claim amount for claim ${claimSubmission.claimId}`);
    }
}

# Routes a claim submission consumed from the single `claims.all` queue to its type-specific
# processing logic based on `claimType`. All claim types currently share the same validation,
# but this keeps the branching point explicit so type-specific rules can be added later.
#
# + claimSubmission - the claim submission to process
# + return - () on success, or an error describing why processing failed
function processClaimByType(ClaimSubmission claimSubmission) returns error? {
    string claimType = claimSubmission.claimType.trim().toLowerAscii();
    if claimType == "auto" {
        return processClaim(claimSubmission);
    } else if claimType == "health" {
        return processClaim(claimSubmission);
    } else if claimType == "property" {
        return processClaim(claimSubmission);
    }
    return processClaim(claimSubmission);
}
