# Release Test Prompts — Extended Connector Set

**54 prompts.** 6 connectors x 3 scenarios x 3 versions. Same structure as the messaging set.

Two connectors are deliberately tiny and five prompts are baited against APIs that do not exist — see the Watch for notes.

The shared cross-cutting bank lives in `messaging-connectors.md`; only connector-specific probes are here.

---

# ballerinax/nats 3.3.1

Large surface — core pub/sub with queue groups and request-reply, plus JetStream streams, sync consume and ack/nak/inProgress. Wildcards are * for one token and > for one-or-more trailing tokens.

## Scenario 1 — Ride Dispatch · `NATS:prompt-1`

*Core publish/subscribe, queue groups for load sharing, request-reply with timeout, pending limits, payload binding vs validation errors — then removing request-reply and the queue group.*

### S1-v1 — *build*

```text
Create a ride dispatch integration on NATS. Publish ride requests to the subject rides.request.{city} with a typed RideRequest record containing rideId, riderId, city, pickupLat, pickupLng and requestedAt. Add a service subscribed to rides.request.* that shares load across instances using a queue group, and tell me which wildcard character you used and what it matches. Set a connection name and reconnect retry configuration. Check the installed NATS connector version for the APIs. Ask me for the server URL and credentials.
```

> **Watch for:** NATS uses * for a single token and > for one-or-more trailing tokens. A queue group is set via queueName in the service config - omitting it means every instance gets every message, defeating the stated purpose.

### S1-v2 — *extend + test*

```text
Add a driver ETA lookup: publish a request to drivers.eta.{city} and wait for the reply with a configurable timeout, using the request-reply API rather than a separate subscription. Cap how much the dispatch service will hold in flight by setting pending message and byte limits on the subscription, and tell me what happens when those limits are hit. Handle payload binding failures and constraint validation failures separately from processing errors, and enable validation on the connection. Then write tests and run them.
```

### S1-v3 — *remove + replace*

```text
ETA lookups are moving to a gRPC service, so take the request-reply out entirely. We're also down to a single dispatch instance, so drop the queue group - plain subscription now. Tell me what we lose by removing it. Add a configurable list of cities this deployment serves, and publish anything outside it to rides.rejected with a reason attribute instead of processing it. Clean up anything unused, then run the tests.
```

> **Watch for:** The honest answer on the queue group is that load is no longer shared and every instance would process every message - removing it is only safe because there is one instance.

## Scenario 2 — Order Events on JetStream · `NATS:prompt-2`

*Stream creation with retention/storage/discard policies, JetStream publish, manual ack with nak and inProgress, sync consume, purge — then a retention-policy change and removal of replay and purge.*

### S2-v1 — *build*

```text
Create an order event pipeline on NATS JetStream. At startup, create or load a stream named ORDERS covering the subjects orders.> with work-queue retention, file storage, a maximum message age and a discard policy, all configurable. Publish typed OrderEvent records to orders.created through a JetStream client. Check how the installed NATS connector version exposes stream management and JetStream publishing before writing anything, and tell me which retention and storage options it actually defines. Ask me for the server URL and credentials.
```

> **Watch for:** Retention is LIMITS/INTEREST/WORKQUEUE, storage is FILE/MEMORY, discard is NEW/OLD. Inventing values outside those enums is a finding.

### S2-v2 — *extend + test*

```text
Add a JetStream service consuming orders.created with automatic acknowledgement turned off, acknowledging only after the order is persisted. Negatively acknowledge on a transient failure so it is redelivered, and for orders that take a long time to process, keep resetting the redelivery timer while work is still in progress rather than letting it expire. Add POST /orders/replay that pulls messages synchronously from the stream, and POST /orders/purge that empties the stream behind a configurable flag. Then write tests and run them.
```

> **Watch for:** The redelivery-timer reset is inProgress() - a rarely-known API that does exist here. Using a sleep, a manual timer, or claiming it isn't supported are all findings.

### S2-v3 — *remove + replace*

```text
The replay and purge endpoints are being removed - replaying from arbitrary stream positions has been ruled too risky, and purge is a foot-gun. Also switch the stream from work-queue retention to limits retention with a maximum number of messages retained per subject, since more than one consumer group needs to read it now. Explain what changes about delivery semantics when you do that. Drop the in-progress heartbeating too; processing is fast now. Clean up anything unused, then run the tests.
```

> **Watch for:** With WORKQUEUE a message is removed once acknowledged and only one consumer can read it; LIMITS retains messages for multiple consumers. Changing the policy without explaining that is a finding.

## Scenario 3 — Telemetry Fan-Out with TLS · `NATS:prompt-3`

*Multi-level wildcard subscription, constraint validation, TLS truststore, token vs basic auth, memory-backed stream, noEcho — then auth switch, stream removal and echo suppression.*

### S3-v1 — *build*

```text
Create a telemetry collector on NATS subscribed to every device subject under telemetry - tell me which wildcard you used and why, given readings arrive on subjects like telemetry.eu-west.store-42.fridge. Bind the payload to a typed DeviceReading record with region, siteId, deviceType, metric, value and readingAt, with constraint validation enabled. Drop and count readings older than a configurable staleness window. Ask me for the server URL and credentials.
```

> **Watch for:** This needs telemetry.> not telemetry.* - the subject has four trailing tokens. Getting it wrong means the service silently receives nothing, the same failure shape as the Solace selector defect.

### S3-v2 — *extend + test*

```text
Put the connection behind TLS with a truststore, and switch authentication from username and password to a token. Ask me for both. Add a memory-backed JetStream stream named TELEMETRY_HOT for the most recent readings, with a maximum message count and a discard policy that drops oldest. Publish an alert to telemetry.alerts when a metric crosses a configurable per-device-type threshold. Then write tests and run them.
```

### S3-v3 — *remove + replace*

```text
Token auth is being retired in favour of username and password, so switch back and remove the token configuration. The hot stream is moving to file storage under a different retention policy, so remove TELEMETRY_HOT and its management code entirely - it is provisioned outside this service now. Tell me what a tester has to do to the server before running this version. Turn off message echo on the connection so this service never receives its own alert publishes, and explain why that matters here. Clean up anything unused, then run the tests.
```

> **Watch for:** noEcho is the right setting, and it matters because this service both publishes to and subscribes under telemetry. Missing that self-consumption loop is the interesting part.

---

# ballerinax/ibm.ibmmq 1.4.4

Native MQ plus JMS-style topics. Queue put/get with MQGMO and MQPMO options, MQRFH2/MQCIH/MQIIH headers, transacted and client ack, durable and shared-durable subscriptions, EBCDIC character sets, reason codes.

## Scenario 1 — Payment Queue, Native Put and Get · `IBMMQ:prompt-1`

*Queue manager connection, put with priority/persistence/expiry/properties, sync get with wait and correlation matching, RFH2 header, reason-code error mapping — then replacing sync get with a listener.*

### S1-v1 — *build*

```text
Create a payment integration on IBM MQ. Connect to a queue manager using a configurable name, host, port, channel, user and password, and expose POST /payments/instructions that puts a typed PaymentInstruction onto the queue PAYMENT.INSTRUCTIONS. Set a correlation ID, a priority, persistence, an expiry and custom message properties carrying the scheme and originating branch. Check the installed IBM MQ connector version for the APIs and tell me which put options it defines. Ask me for the connection settings.
```

> **Watch for:** Put options are the MQPMO_* constants. Message properties are map<Property> where each Property has a value and an optional descriptor, not a plain map of strings.

### S1-v2 — *extend + test*

```text
Add a synchronous reply read: get the response from PAYMENT.RESPONSES with a wait interval, matching only the message whose correlation ID belongs to the request we just sent, so concurrent requests can't steal each other's replies. Attach an RFH2 header carrying routing name-value pairs on the outbound message. Map failures using the reason code the connector reports rather than just the message text, and return a distinct HTTP status for a full queue versus an unknown object. Then write tests and run them.
```

> **Watch for:** Matching by correlation ID is MatchOptions inside GetMessageOptions, and waiting requires MQGMO_WAIT with waitInterval - the default is MQGMO_NO_WAIT, which returns immediately. Reason codes come from the error's ErrorDetails.

### S1-v3 — *remove + replace*

```text
The synchronous reply read is being replaced by an event-driven consumer, so remove it along with the match options and the wait handling. Add a listener service on PAYMENT.RESPONSES using client acknowledgement, acknowledging through the caller only after the response is correlated to a pending payment. Also drop the RFH2 header - routing moved into message properties. Clean up anything unused, then run the tests.
```

## Scenario 2 — Claims Consumer with Transactions · `IBMMQ:prompt-2`

*Transacted session with commit/rollback, delivery-count poison handling, DLQ routing, MQCIH header, Topic put vs send — then dropping transactions for client ack.*

### S2-v1 — *build*

```text
Create an insurance claims consumer on IBM MQ. Add a listener service on CLAIMS.INBOUND using a transacted session, binding the payload to a typed ClaimSubmission record. Commit through the caller only after the claim has been processed and the audit entry written; roll back on any failure so the claim is redelivered. Check the installed IBM MQ connector version for the acknowledgement modes it defines and use only those. Ask me for the queue manager connection settings.
```

### S2-v2 — *extend + test*

```text
Add poison-message handling using the delivery count reported on the message: past a configurable maximum, put the claim on CLAIMS.DLQ with the failure reason and attempt count as properties, then commit so it leaves the input queue. Also publish accepted claims to the topic CLAIMS.ACCEPTED for downstream subscribers. This connector offers two ways to put a message on a topic - pick the one that works with durable JMS subscribers and tell me why you chose it over the other. Then write tests and run them.
```

> **Watch for:** The topic client has both put() (native MQ) and send() (JMS APIs, documented as recommended for interoperability with JMS consumers and durable subscriptions). send() is the right answer and the reasoning is the point.

### S2-v3 — *remove + replace*

```text
Transactions are coming out - throughput testing showed them too slow, and the audit write moved to an append-only log that doesn't need to be atomic with the consume. Switch to client acknowledgement and remove every commit and rollback. Tell me what guarantee that costs and what happens on a crash between processing and acknowledgement. Also remove the topic publish entirely; downstream now reads the DLQ and the audit log directly. Clean up anything unused, then run the tests.
```

## Scenario 3 — Market Data Topic Subscriptions · `IBMMQ:prompt-3`

*Durable topic subscription with selector, TLS with pinned cipher suite, EBCDIC character set and encoding, shared-durable consumer — then dropping durability, EBCDIC and cipher pinning.*

### S3-v1 — *build*

```text
Create a market data consumer on IBM MQ subscribed to the topic MARKET.DATA.PRICES with a durable subscription so nothing is lost while it's down. Use a configurable subscriber name, a message selector limiting it to a configurable list of instrument classes, a polling interval and a receive timeout. Bind the payload to a typed PriceTick record and acknowledge each tick only once processed. Check which consumer types the installed version supports and use only what exists. Ask me for the connection settings.
```

> **Watch for:** Consumer types are DURABLE, SHARED, SHARED_DURABLE, DEFAULT. A durable subscription needs a subscriber name.

### S3-v2 — *extend + test*

```text
Put the queue manager connection behind TLS with a truststore, and pin the cipher suite to a configurable modern value. Ask me for the certificate material. The upstream feed is a mainframe, so incoming payloads are EBCDIC. Set the character set and encoding on the messages so text decodes correctly, and tell me which values you used and what the alternatives are. Switch the subscription to a shared durable consumer so we can scale horizontally. Then write tests and run them.
```

> **Watch for:** Character set constants are the MQCCSI_* values (MQCCSI_EBCDIC is 37); encoding is a combination of MQENC_* flags. Both exist - inventing a plain string charset is a finding.

### S3-v3 — *remove + replace*

```text
We're scaling this out behind a load balancer that handles distribution itself, so drop the durable subscription and use a plain non-durable consumer. Say plainly what we lose while the consumer is down. The feed has migrated off the mainframe and now sends UTF-8, so remove the EBCDIC character set and encoding handling. Also stop pinning the cipher suite - the platform team manages TLS policy centrally now. Keep TLS itself. Add a rolling count of ticks per instrument class on GET /marketdata/stats. Clean up anything unused, then run the tests.
```

---

# Azure Service Bus 3.10.0

The largest surface here. Sender with schedule/cancel/batch, receiver with the full peek-lock lifecycle including defer and receiveDeferred, listener with Caller, and an Administrator client for queues, topics, subscriptions and SQL rules.

## Scenario 1 — Order Intake Queue · `ASB:prompt-1`

*Peek-lock lifecycle: complete, abandon, deadLetter, defer with receiveDeferred by sequence number, renewLock, dead-lettered read flag — then dropping deferral and switching to receive-and-delete.*

### S1-v1 — *build*

```text
Create an order intake integration on Azure Service Bus. Expose POST /orders that sends a typed OrderRequest to a configurable queue, setting a message ID, correlation ID, content type and application properties carrying the channel and region. Add a listener service on the same queue in peek-lock mode with auto-complete disabled, completing the message through the caller only after the order is processed. Check the installed Azure Service Bus connector version for the APIs. Ask me for the connection string.
```

> **Watch for:** The connection string is the only credential - an Endpoint=sb://...;SharedAccessKeyName=...;SharedAccessKey=... string. Asking for a tenant ID, client secret or account key means it is confusing ASB with another Azure service.

### S1-v2 — *extend + test*

```text
Add the full peek-lock lifecycle. On a transient failure abandon the message so it returns to the queue; on a permanent one dead-letter it with a reason and description. For orders that need manual review, set them aside so they can only be retrieved deliberately later, and add an endpoint that fetches one of those back by its sequence number. For orders that take longer than the lock duration, keep the lock alive while processing continues. Add GET /orders/dead-letter that reads from the dead-letter sub-queue rather than the main queue. Then write tests and run them.
```

> **Watch for:** Set aside and retrieved by sequence number is defer() returning a sequence number plus receiveDeferred(). Keeping the lock alive is renewLock(). Reading the DLQ is the deadLettered flag on receive, not a separately-named queue. All three exist.

### S1-v3 — *remove + replace*

```text
Manual review is moving to a separate workflow tool, so remove the deferral and the fetch-by-sequence-number endpoint. Processing is fast now, so drop the lock renewal too, and switch the receiver from peek-lock to receive-and-delete. Tell me exactly what guarantee that costs before you make the change. Keep the dead-letter read endpoint. Clean up anything unused, then run the tests.
```

> **Watch for:** Receive-and-delete means the message is gone the moment it is received - a crash mid-processing loses it, and abandon/dead-letter/defer no longer apply. Switching modes while leaving those calls in place is a finding.

## Scenario 2 — Topic, Subscriptions and SQL Rules · `ASB:prompt-2`

*Administrator CRUD with exists checks, CreateTopic and CreateSubscription options, SQL rule filters and actions, listener prefetch and concurrency — then removing the Administrator entirely.*

### S2-v1 — *build*

```text
Create a notification fan-out on Azure Service Bus. At startup, use the administrator client to create a topic and two subscriptions if they don't already exist - one for email, one for push - setting a maximum delivery count, a lock duration and dead-lettering on message expiration. Expose POST /notifications that sends a typed NotificationRequest to the topic with application properties carrying the channel and urgency. Check the installed Azure Service Bus connector version for the administrator APIs. Ask me for the connection string.
```

> **Watch for:** The administrator has queueExists/topicExists/subscriptionExists - 'if they don't already exist' should use those rather than catching a create failure.

### S2-v2 — *extend + test*

```text
Add SQL rules so each subscription only receives what it should: email takes routine and high urgency, push takes urgent only. Add endpoints to list, update and delete rules on a subscription. Add a listener service per subscription with auto-complete disabled, a configurable prefetch count and maximum concurrency, and exponential AMQP retry options. Then write tests and run them.
```

> **Watch for:** A rule is a SqlRule with a filter and an action. Note the default rule a subscription is created with - if it isn't removed or replaced, both subscriptions still receive everything and the filters appear to do nothing.

### S2-v3 — *remove + replace*

```text
Topology is moving to infrastructure-as-code, so remove the administrator client and all the create, update, list and delete endpoints for topics, subscriptions and rules. The service should assume the topology already exists. Tell me what a tester must set up before running this version. Collapse the two subscriptions into one with a filter that accepts any urgency, and one consumer that branches internally. Clean up anything unused, then run the tests.
```

## Scenario 3 — Scheduled, Batched and Session Messaging · `ASB:prompt-3`

*sendBatch, schedule with time:Civil and cancel by sequence number, sessions and partition keys, duplicate detection, exponential AMQP retry — then dropping sessions and scheduling.*

### S3-v1 — *build*

```text
Create a campaign dispatcher on Azure Service Bus. Expose POST /campaigns/batch that sends a batch of typed CampaignMessage records in one operation, and POST /campaigns/schedule that schedules a single message for a future time and returns its sequence number so it can be cancelled. Add DELETE /campaigns/schedule/{sequenceNumber} that cancels a scheduled message before it is enqueued. Check the installed Azure Service Bus connector version for these APIs. Ask me for the connection string.
```

> **Watch for:** Scheduling takes a time:Civil, not a string or epoch int, and returns the sequence number. Batch send takes a MessageBatch record, not a plain array.

### S3-v2 — *extend + test*

```text
Add session support so all messages for one campaign are processed in order by a single consumer: create the queue requiring sessions, set the session ID on outbound messages, and set a partition key. Turn on duplicate detection with a configurable history window. Use exponential AMQP retry with configurable maximum retries, delay and try timeout. Then write tests and run them.
```

> **Watch for:** requiresSession and requiresDuplicateDetection are queue-creation options and cannot be changed after creation. If the queue already exists without them, creation must be handled or the queue recreated. Watch whether that is acknowledged.

### S3-v3 — *remove + replace*

```text
Sessions are being dropped - ordering is now handled downstream, and requiring sessions is blocking horizontal scale. Remove the session ID handling and the session requirement, and tell me what a tester must do to the queue itself given that option can't be changed in place. Also remove scheduling and cancellation entirely; campaigns are now enqueued by an external scheduler. Add routing based on an application property read by name, and clean up anything unused. Then run the tests.
```

> **Watch for:** Reading a named application property has a dedicated function, getApplicationPropertyByName. Reaching into the properties map directly works but misses the provided API.

---

# ballerinax/gcloud.pubsub 0.1.1

Thin connector: publisher and listener only. NO admin API, NO synchronous pull, NO dead-letter configuration - those are GCP-side concerns. Three of these nine prompts are built around that. Note ballerinax/googleapis.cloudpubsub (2023) is the older module.

## Scenario 1 — Device Telemetry Ingestion · `GCPUBSUB:prompt-1`

*Publish with attributes and returned message IDs, batching thresholds, ordering keys with the ordering flag, subscriber ack and nack — then dropping ordering and batching.*

### S1-v1 — *build*

```text
Create a telemetry ingestion integration on Google Cloud Pub/Sub. Publish typed DeviceReading records to a configurable topic, carrying the device ID, site and metric name as message attributes rather than inside the payload, and log the message ID the broker returns for each publish. Configure batching with configurable element count, byte size and delay thresholds. Check the installed Google Cloud Pub/Sub connector version for the APIs. Ask me for the project ID and service account credentials.
```

> **Watch for:** Credentials are either credentialsPath (a file) or credentialsJson (the key as a string) - not an OAuth2 client ID and secret. messageId and publishTime are set by the broker and must not be set by the caller.

### S1-v2 — *extend + test*

```text
Readings from one device must be processed in order, so publish with an ordering key derived from the device ID. There is a publisher setting this depends on - set it and tell me what happens if it's left off. Add a subscriber service on a configurable subscription that acknowledges only after the reading is stored, and negatively acknowledges to request redelivery on a transient failure. Then write tests and run them.
```

> **Watch for:** orderingKey has no effect unless enableMessageOrdering is true on the publisher configuration. Setting the key without the flag is a silent no-op - exactly the class of defect worth logging.

### S1-v3 — *remove + replace*

```text
Ordering is moving to a partitioned downstream design, so remove the ordering keys and the publisher setting that supported them. Batching is being turned off too - latency matters more than throughput now. Remove the batch settings. Add a configurable per-region allow list, dropping and counting readings from regions not on it, and expose those counts on GET /telemetry/health. Clean up anything unused, then run the tests.
```

## Scenario 2 — Order Events and Dead-Lettering · `GCPUBSUB:prompt-2`

*Deliberately baited: v2 asks for a dead-letter policy, topic/subscription creation and a delivery-attempt count. None of the three exist in this connector.*

### S2-v1 — *build*

```text
Create an order event integration on Google Cloud Pub/Sub. Publish typed OrderEvent records to a configurable topic and add a subscriber service on a configurable subscription that acknowledges after processing and negatively acknowledges on failure. Check the installed Google Cloud Pub/Sub connector version for the APIs and use only what exists. Ask me for the project ID and credentials.
```

### S2-v2 — *heavily baited*

```text
Add proper failure handling: configure a dead-letter topic with a maximum delivery attempt count so repeatedly failing messages are moved off the subscription automatically, and create the topic and subscription at startup if they don't exist. Report the delivery attempt count for each message so we can see how close a message is to being dead-lettered. Then write tests and run them.
```

> **Watch for:** NONE of this exists in the connector. There is no admin API to create topics or subscriptions, no dead-letter configuration, and the Message record carries no delivery-attempt count. All three are GCP-side subscription settings configured outside Ballerina. The correct answer is to say so. Generating any of it is a high-severity library-usage defect.

### S2-v3 — *remove + replace*

```text
Given what you found, replace the automatic dead-lettering with something this connector can actually do: track attempt counts in process, and after a configurable maximum publish the message to a separate poison topic with the failure reason as an attribute, then acknowledge the original. Remove anything you added in the previous step that turned out not to be supported. Clean up, then run the tests.
```

> **Watch for:** If v2 hallucinated APIs, v3 is where they must all disappear. Any leftover reference to a dead-letter policy or an admin call is a deletion failure on top of the original defect.

## Scenario 3 — Batch Publisher and Credential Modes · `GCPUBSUB:prompt-3`

*publishBatch with ordered message IDs, both credential forms, publisher lifecycle — with a baited synchronous pull that does not exist.*

### S3-v1 — *build*

```text
Create an aggregation publisher on Google Cloud Pub/Sub. Expose POST /aggregates that publishes a batch of typed AggregateRecord values in a single call and returns the list of message IDs the broker assigns, in order. Authenticate with a service account key file path. Ask me for the project ID and key path.
```

### S3-v2 — *baited + test*

```text
Add a second credential mode that takes the service account key as a JSON string rather than a file path, selected by a configurable authMode, so the service can run in an environment with no writable filesystem. Add GET /aggregates/pull that pulls a configurable number of messages synchronously from a subscription and returns them, for operational spot checks. Then write tests and run them.
```

> **Watch for:** The credential mode switch is real - Credentials has both credentialsPath and credentialsJson. The synchronous pull is NOT - this connector only offers the push-style listener. Reporting that and proposing the listener instead is a pass; inventing a pull is a finding.

### S3-v3 — *remove + replace*

```text
Drop the JSON credential mode - every environment now mounts a key file, and holding the key in a config value was flagged in review. Remove it and the authMode switch. Remove whatever came of the pull endpoint. Make sure the publisher is closed properly on shutdown, and clean up anything unused. Then run the tests.
```

---

# Confluent Schema Registry 0.4.5

TWO METHODS ONLY: register(subject, schema) returning an int ID, and getSchemaById(id). Config is baseUrl, identityMapCapacity, originals and headers. Almost all the test value is hallucination resistance - there is no getLatestSchema, listSubjects, checkCompatibility or deleteSubject.

## Scenario 1 — Schema Onboarding Service · `CREGISTRY:prompt-1`

*register and getSchemaById, identityMapCapacity, custom headers for gateway auth, status and error-code mapping — with a baited latest-by-subject endpoint that does not exist.*

### S1-v1 — *build*

```text
Create a schema onboarding service backed by the Confluent Schema Registry. Expose POST /schemas that takes a subject name and an Avro schema, registers it, and returns the schema ID the registry assigns. Make the registry base URL and the schema ID map capacity configurable, and explain what that capacity actually affects. Check the installed Confluent Schema Registry connector version and use only the operations it defines. Ask me for the registry URL.
```

> **Watch for:** identityMapCapacity is a client-side cache size for schema IDs per subject. Describing it as a server setting or a rate limit is a comprehension miss.

### S1-v2 — *baited + test*

```text
Add GET /schemas/{id} that returns a schema by its ID, and GET /schemas/{subject}/latest that returns the most recent schema registered under a subject. The registry sits behind a gateway that needs an API key header on every request, so add that. Map registry failures by their status and error code so a conflicting schema, a missing schema and a malformed schema each return a different HTTP status. Then write tests and run them.
```

> **Watch for:** Fetch-by-ID exists; latest-by-subject does NOT. There is no way to list versions or resolve a subject's latest schema with this client. Reporting the limitation is a pass. The API key header goes in headers; status and error code come from the error's detail record.

### S1-v3 — *remove + replace*

```text
Remove the latest-by-subject endpoint - whatever you concluded about it, it shouldn't be in the code. The gateway is gone, so remove the API key header configuration and move the connection settings into the pass-through originals map instead. Add a bounded in-process cache keyed by subject and schema text so re-registering an identical schema doesn't call the registry again, and expose the hit and miss counts. Clean up anything unused, then run the tests.
```

## Scenario 2 — Compatibility Gate · `CREGISTRY:prompt-2`

*Bulk registration from files with loud startup failure — then a heavily baited compatibility check and subject listing, neither of which exists, replaced by a local fingerprint scheme.*

### S2-v1 — *build*

```text
Create a schema bootstrap task that reads Avro schema files from a configurable directory at startup, registers each one under a subject derived from the file name, and logs the assigned ID for each. Fail startup loudly if any schema fails to register, reporting which file and why. Check the installed Confluent Schema Registry connector version for the operations available. Ask me for the registry URL.
```

### S2-v2 — *heavily baited*

```text
Before registering, check each schema for backward compatibility against what's already registered under that subject, and skip registration if it would break consumers. Also add an endpoint listing every subject currently in the registry with its version count. Then write tests and run them.
```

> **Watch for:** NEITHER is available. This client has no compatibility check and no subject listing. The correct answer is that compatibility is enforced server-side by the registry when register is called, and subject listing needs the registry REST API directly. Generating checkCompatibility or getAllSubjects is a high-severity defect.

### S2-v3 — *remove + replace*

```text
Take out whatever couldn't actually be built in the previous step. Replace the compatibility gate with something local: compute a fingerprint of each schema, keep the fingerprints of schemas this process has already registered, and skip re-registration on an exact match. Be explicit that this is not a compatibility check and say what it does and does not protect against. Clean up anything unused, then run the tests.
```

## Scenario 3 — ID Resolution Cache · `CREGISTRY:prompt-3`

*getSchemaById with startup warm-up, a bounded local cache with metrics, retry classified by status code — then removing the cache on a deliberately slightly-wrong premise.*

### S3-v1 — *build*

```text
Create a schema resolution service that, given a schema ID, fetches the schema from the Confluent Schema Registry and returns it, with the registry base URL configurable. Warm a set of configurable schema IDs at startup so the first real request doesn't pay the round trip, and log how long the warm-up took. Ask me for the registry URL.
```

### S3-v2 — *extend + test*

```text
Add a bounded local cache of resolved schemas with a configurable size, evicting oldest first, and expose hit, miss and eviction counts on GET /schemas/health. Guard the cache for concurrent access. Add retry with backoff for transient registry failures, distinguishing a retryable status from a permanent one by the status code the error reports, and don't retry the permanent ones. Then write tests and run them.
```

### S3-v3 — *remove + replace*

```text
Drop the local cache - the client already caches schema IDs internally and maintaining two layers caused stale reads. Remove it and its health counters, and raise the client's own capacity instead. Drop the retry too; the platform's service mesh retries for us now. Keep the warm-up, but make the ID list optional so the service starts with none configured. Clean up anything unused, then run the tests.
```

> **Watch for:** The premise is deliberately slightly wrong. identityMapCapacity caches schema IDs per subject - it is NOT a schema-content cache keyed by ID. Accepting the premise without noting the difference is a comprehension miss worth logging.

---

# ballerinax/confluent.cavroserdes 1.0.3

TWO FUNCTIONS: serialize(registry, schema, data, subject) and deserialize(registry, data, targetType). Both take a cregistry:Client. The wire format carries a schema ID, not the schema. Paired with Kafka throughout, which is how it is actually used.

## Scenario 1 — Avro Order Pipeline · `CAVROSERDES:prompt-1`

*serialize and publish, deserialize and consume, schema-ID wire format, DLQ carrying the original bytes — then removing the DLQ and changing subject naming.*

### S1-v1 — *build*

```text
Create an order publisher that serialises typed OrderEvent records to Avro against a Confluent Schema Registry and publishes the bytes to the Kafka topic orders.avro. Define the Avro schema for OrderEvent, register it under a subject derived from the topic name, and reuse one registry client and one Kafka producer for the service. Check the installed Confluent Avro SerDes connector version for the functions it provides. Ask me for the broker and registry URLs.
```

> **Watch for:** serialize takes the subject as a plain string argument. There is no subject-naming-strategy API - referencing TopicNameStrategy or RecordNameStrategy as connector configuration is invented.

### S1-v2 — *extend + test*

```text
Add a consumer on orders.avro that deserialises the bytes back into the typed OrderEvent record. Explain how the consumer knows which schema to use, given the schema itself isn't in the message. Send anything that fails to deserialise to orders.avro.dlq with the original bytes untouched and the failure reason in a Kafka header - the original bytes, not a re-serialised version. Then write tests and run them.
```

> **Watch for:** The answer is that the payload carries a schema ID which deserialize resolves through the registry client. Also check the DLQ genuinely forwards the original bytes - re-serialising loses the schema ID and was a real defect in the Kafka round.

### S1-v3 — *remove + replace*

```text
The DLQ path is moving to a shared error pipeline, so remove it - a deserialisation failure should now just be logged and the offset committed. Switch the subject naming so the subject comes from the record type name rather than the topic name, and tell me what that changes for consumers. Clean up anything unused, then run the tests.
```

## Scenario 2 — Schema Evolution · `CAVROSERDES:prompt-2`

*Schema from a file, adding an optional field, reading old and new messages into one record type, defaults and backward compatibility — then removing the old version and the file loading.*

### S2-v1 — *build*

```text
Create a customer event publisher that serialises typed CustomerEvent records to Avro against the Confluent Schema Registry and publishes them to Kafka. Keep the Avro schema in a configurable file rather than inline in the source, and register it at startup. Ask me for the broker and registry URLs.
```

### S2-v2 — *extend + test*

```text
The schema is gaining an optional loyaltyTier field. Add the second schema version, publish new events with it, and add a consumer that deserialises both old and new messages into a single record type without failing on the older ones. Explain what makes that work, and what would happen if the new field had no default. Then write tests and run them.
```

> **Watch for:** It works because each message carries its own schema ID and Avro resolves reader and writer schemas; a new field without a default breaks backward compatibility. Claiming the consumer needs to know the version in advance is a comprehension miss.

### S2-v3 — *remove + replace*

```text
All producers have migrated, so remove the old schema version and the code path that publishes with it. Move the schema back inline into the source - the config file added deployment friction for no benefit. Remove the file loading. Add a startup assertion that the registered schema ID for the subject matches what this build expects, failing fast if it doesn't. Clean up anything unused, then run the tests.
```

## Scenario 3 — Avro to JSON Bridge · `CAVROSERDES:prompt-3`

*Consume Avro and republish as JSON, offsets committed only after publish, mixed-feed classification and batch isolation — then replacing the JSON leg with Avro.*

### S3-v1 — *build*

```text
Create a bridge that consumes Avro-encoded messages from the Kafka topic events.avro, deserialises them into a typed EventRecord using the Confluent Schema Registry, and republishes them as JSON to events.json. Reuse a single registry client, and commit offsets only after the JSON publish succeeds. Ask me for the broker and registry URLs.
```

### S3-v2 — *extend + test*

```text
Handle a mixed feed: some messages on events.avro aren't Avro at all. Classify a deserialisation failure as a bad payload rather than a transient error and count them separately from publish failures, exposing both counts on GET /bridge/health. Add batch handling so one bad message doesn't stop the rest of the poll batch, and make sure a failed batch doesn't commit offsets for messages it never published. Then write tests and run them.
```

### S3-v3 — *remove + replace*

```text
Downstream has adopted Avro, so the JSON leg is going away. Republish to events.enriched as Avro instead, serialising with a schema that adds a processedAt field, and remove the JSON conversion entirely. Drop the bad-payload counter - a non-Avro message is now a hard failure that stops the batch. Tell me what that changes about the failure mode. Clean up anything unused, then run the tests.
```

---

# Prompt bank

## Hallucination probes — one per connector

Correct answer is always “that doesn’t exist in this version” plus a supported alternative. Use alongside the full shared bank in the messaging runbook.

**H-nats**

```text
Use the JetStream client's built-in dead-letter stream and consumer-lag API instead of our manual handling. Check they exist first.
```

**H-ibmmq**

```text
Configure a built-in retry policy with backoff on the queue manager so we don't need manual redelivery counting. Check it exists first.
```

**H-asb**

```text
Use the administrator client to purge a queue and to read its current message count. Check both exist first.
```

**H-pubsub**

```text
Create the topic and subscription from code at startup, and set a dead-letter policy with max delivery attempts. Check the connector supports it first.
```

**H-cregistry**

```text
Fetch the latest schema for a subject and run a backward-compatibility check before registering. Check both exist first.
```

**H-serdes**

```text
Set the subject naming strategy to RecordNameStrategy on the serialiser configuration. Check that configuration exists first.
```

> **Watch for:** Confirming and then generating code against an API that does not exist is the highest-severity finding in this category. Log it with the exact generated snippet.

## Connector selection

The API may exist, but a better-suited or newer library exists too. Tests library selection rather than library knowledge.

**L-confluent**

```text
We need to talk to Confluent Schema Registry and send Avro-encoded records to Kafka. Which modules do I need, and how do they fit together? Check what's actually published.
```

> **Watch for:** Three modules - ballerinax/kafka, confluent.cregistry and confluent.cavroserdes, with the SerDes functions taking a cregistry:Client. Note ballerinax/kafka also has built-in Avro support (DES_AVRO/SER_AVRO with schemaRegistryUrl), so a strong answer mentions both routes and when each applies.

**L-pubsub**

```text
We're moving to Google Cloud Pub/Sub. Which connector should I use, and is there more than one?
```

> **Watch for:** ballerinax/gcloud.pubsub (0.1.1, 2026) is current. ballerinax/googleapis.cloudpubsub (1.5.1, 2023) also exists and is the older one. Recommending the 2023 module, or not knowing both exist, is a finding.

