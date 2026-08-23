import ballerina/ai;
import ballerina/time;

// Default model provider configured for this environment.
final ai:ModelProvider triageModel = check ai:getDefaultModelProvider();

// Tracks the last active time (epoch seconds) for each patient's triage session, keyed by patient ID.
// The built-in AI module does not support session expiry configuration, so expiry is enforced manually
// using this map together with the configurable sessionTimeoutMinutes.
isolated map<int> sessionLastActiveTimes = {};

// Records or refreshes the last active time for a patient's session, e.g. when a triage session starts
// or when a follow-up request is served.
#
# + patientId - the patient ID that identifies the session
isolated function touchSession(string patientId) {
    int nowEpochSeconds = time:utcNow()[0];
    lock {
        sessionLastActiveTimes[patientId] = nowEpochSeconds;
    }
}

# Checks whether a patient's session has expired based on sessionTimeoutMinutes.
# A session that has never been touched is considered expired.
#
# + patientId - the patient ID that identifies the session
# + return - true if the session is expired or does not exist, false otherwise
isolated function isSessionExpired(string patientId) returns boolean {
    int? lastActiveTime;
    lock {
        lastActiveTime = sessionLastActiveTimes[patientId];
    }
    if lastActiveTime is () {
        return true;
    }
    int nowEpochSeconds = time:utcNow()[0];
    int elapsedSeconds = nowEpochSeconds - lastActiveTime;
    int timeoutSeconds = sessionTimeoutMinutes * 60;
    return elapsedSeconds > timeoutSeconds;
}

// Default embedding provider configured for this environment, used to embed clinical protocol
// documents and incoming retrieval queries.
final ai:EmbeddingProvider triageEmbeddingProvider = check ai:getDefaultEmbeddingProvider();

// In-memory vector store backing the clinical protocol knowledge base.
final ai:VectorStore clinicalProtocolVectorStore = check new ai:InMemoryVectorStore();

// Vector knowledge base holding the clinical protocol documents used for RAG-based protocol matching.
final ai:KnowledgeBase clinicalProtocolKnowledgeBase = new ai:VectorKnowledgeBase(clinicalProtocolVectorStore, triageEmbeddingProvider, ai:DISABLE);

// Chunks and ingests the clinical protocol documents into the knowledge base at module startup.
// MarkdownChunker is used since the protocol documents contain structured markdown headings and lists.
function ingestClinicalProtocolDocuments() returns error? {
    foreach ai:TextDocument protocolDocument in clinicalProtocolDocuments {
        ai:TextChunk[] protocolChunks = check ai:chunkMarkdownDocument(protocolDocument, 1000, 100);
        check clinicalProtocolKnowledgeBase.ingest(protocolChunks);
    }
}

// Triggers ingestion as part of module-level initialization.
final error? clinicalProtocolIngestionResult = ingestClinicalProtocolDocuments();
