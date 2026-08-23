import ballerina/ai;

// Default model provider configured for this environment.
final ai:ModelProvider triageModel = check ai:getDefaultModelProvider();

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
