# Release Test Prompts — Messaging Connectors

**36 prompts.** 4 connectors x 3 scenarios x 3 versions. Run each scenario in order in one thread, committing after each version.

**v1** builds · **v2** extends then tests · **v3** removes and replaces.

Every prompt is one paragraph, written the way a developer would type it. The *Watch for* notes are for the tester, not for Copilot.

---

# ballerinax/kafka

Event streaming. An order pipeline that loses its database, exactly-once settlement that loses its replay endpoint, and Avro ingestion that loses Avro.

## Scenario 1 — Retail Order Pipeline · `Kafka:prompt-1`

*Manual offset commits, sendWithMetadata, payload binding and validation errors, composition with ballerinax/mysql — then removal of that dependency entirely.*

### S1-v1 — *build*

```text
Create a service that consumes order events from the Kafka topic orders.created. Bind them to a typed OrderEvent record with orderId, customerId, orderAmount, currency, itemCount and channel. Use consumer group order-processing-service with auto-commit off, and commit offsets through the caller only after the whole batch succeeds. Check the installed Kafka connector version first and use only APIs that exist in it. Don't hardcode the broker URL or credentials, ask me for them.
```

### S1-v2 — *extend + test*

```text
Now enrich each order with customer tier, email and country from the MySQL customers table, and publish the enriched order to orders.enriched with acks=all and idempotence on. If enrichment or publishing fails, retry with exponential backoff, then send the record to orders.dlq with the failure reason in the headers. Malformed or invalid payloads should go straight to the DLQ without retrying. One bad record mustn't block the batch. Then write tests with the clients mocked and run them.
```

### S1-v3 — *remove + replace*

```text
The upstream team changed the contract. orders.created now carries customerTier, customerEmail and customerCountry on the event itself, so the database lookup is redundant. Drop the MySQL enrichment and read those fields off the event instead. With no database call there's nothing transient to retry, so drop the retry logic too and let publish failures go straight to the DLQ. Route events missing the customer fields to the DLQ as well. Clean up anything that's now unused, then run the tests.
```

> **Watch for:** The richest deletion in the set. Check Ballerina.toml actually lost the ballerinax/mysql dependency, Config.toml lost the DB keys, the ballerina/sql import is gone, and the MySQL mocks were deleted rather than left disabled.

## Scenario 2 — Payment Settlement, Exactly-Once · `Kafka:prompt-2`

*Transactional producer, read-committed isolation, Ballerina transaction blocks, synchronous consumer with seek — then removal of the replay path and the duplicate cache.*

### S2-v1 — *build*

```text
Create a payment settlement service that consumes payments.authorized and produces to payments.settlement. Bind to a typed PaymentAuthorized record with paymentId, orderId, merchantId, amount and currency. It needs exactly-once semantics: a transactional producer with a configurable transactional ID, idempotence on, acks=all, a read-committed consumer with auto-commit off, and the publish plus offset commit inside a transaction block. Check what the installed Kafka connector version actually supports before writing it, and don't invent APIs. Ask me for the broker URL and credentials.
```

### S2-v2 — *extend + test*

```text
Add duplicate suppression keyed by paymentId with a configurable TTL, using an isolated map with locks. Then add a reconciliation API: GET /settlement/status/{paymentId}, and POST /settlement/replay that takes a fromTimestamp, seeks a synchronous consumer to those offsets and re-drives the records. If timestamp-based offset lookup isn't available in this version, say so and fall back to earliest rather than inventing something. Also add GET /settlement/health reporting the consumer's assigned partitions, the last committed offset per partition and the current lag. Derive the lag from the connector's offset APIs, don't estimate it. Then write tests and run them.
```

> **Watch for:** Lag must come from the connector's end-offset and committed-offset APIs. A computed guess, a hardcoded zero, or a claim that it is not supported are all findings - those APIs exist in 4.6.5.

### S2-v3 — *remove + replace*

```text
Ops have vetoed the replay endpoint, re-driving settlements from arbitrary offsets is too risky in production. Remove it and the synchronous consumer it uses. Also drop the in-memory duplicate cache. The idempotent producer already covers that and the map leaks memory. Keep the status endpoint, but back it with the last N settled payments, N configurable, evicting oldest first, and return 404 once a payment has aged out. Leave the health endpoint alone, but make sure it still works once the synchronous consumer is gone. Remove anything left unused, then run the tests.
```

> **Watch for:** Check the kafka:Consumer import disappears once the synchronous consumer goes, and that the replay request types and the TTL configurable are removed rather than left orphaned.

## Scenario 3 — IoT Telemetry with Avro · `Kafka:prompt-3`

*Avro and schema registry (baited — may not exist), concurrent consumers, windowed state, partition pause/resume — then removal of Avro and of the pause mechanism.*

### S3-v1 — *baited*

```text
Create a service that ingests device telemetry from the Kafka topic iot.telemetry.raw using Avro with a Confluent schema registry. Bind to a TelemetryReading record with deviceId, siteId, metric, value, unit and readingAt. Consumer group telemetry-ingestion, 4 concurrent consumers. Check how the installed Kafka connector version exposes Avro and schema registry config before writing anything. If it doesn't support Avro, tell me rather than making something up. Ask me for the broker and registry URLs.
```

### S3-v2 — *web search + test*

```text
Before changing anything, search the web for the current Kafka documentation on configuring Avro with a schema registry, and check what we have matches. Tell me what you find with links, and fix the code if it's wrong. Then aggregate readings per device and metric over a configurable tumbling window, default 60 seconds, giving count, min, max and mean. Publish each window to iot.telemetry.aggregated, and alert to iot.alerts when a mean crosses a per-metric threshold. Add backpressure: pause the affected partitions when alert publishing is failing and resume when it recovers. Then write tests and run them.
```

> **Watch for:** Verify the search tool actually fires in the tool-call trace, that links resolve, and that the answer reflects fetched content rather than pre-training recall.

### S3-v3 — *remove + replace*

```text
The fleet has moved off Avro, telemetry is plain JSON now. Rip out Avro and the schema registry and bind JSON straight into TelemetryReading. Also drop the pause/resume backpressure, stalling a partition holds up unrelated devices on it. Replace it with a bounded buffer that sheds oldest when full and counts what it dropped, and expose that on GET /telemetry/health. Clean up whatever's left over, then run the tests.
```

> **Watch for:** Check the schemaRegistryUrl configurable and its Config.toml key are gone, and that the paused-partition field is removed from the health response type rather than left returning an empty list.

---

# ballerinax/rabbitmq

AMQP. Run broker-lab/provision/rabbitmq.sh --reset between versions: two runs declaring the same queue with different arguments collide with PRECONDITION_FAILED, which looks like a connector defect but isn't.

## Scenario 1 — Insurance Claims · `RabbitMQ:prompt-1`

*Declared topology, topic routing keys, manual ack, dead-letter and TTL arguments, synchronous drain — then collapsing three queues into one and deleting the purge endpoint.*

### S1-v1 — *build*

```text
Create a claims intake integration on RabbitMQ. Declare a durable topic exchange claims.exchange with three durable queues claims.auto, claims.health and claims.property bound on claim.auto.*, claim.health.* and claim.property.*. Expose POST /claims taking a ClaimSubmission record with claimId, policyNumber, claimType, claimAmount, incidentDate and priority. Publish to the exchange with a routing key derived from claimType and priority, correlation ID set to the claimId, and return 202 with the routing key used. Check the installed RabbitMQ connector version for supported APIs. Ask me for the host, port, vhost and credentials.
```

### S1-v2 — *extend + test*

```text
Add a consumer service per queue on a shared listener with configurable prefetch and manual ack, nacking without requeue on failure so messages dead-letter. Set the dead-lettering up properly: a claims.dlx exchange, a claims.dead-letter queue, and a claims.retry queue with a TTL that dead-letters back into claims.exchange for delayed retry. Check the argument names rather than guessing, and cap retries with a header count so nothing loops forever. Add GET /claims/dead-letter to drain and inspect failures, POST /claims/dead-letter/replay, and a DELETE to purge behind a flag. Then write tests and run them.
```

### S1-v3 — *remove + replace*

```text
Three queues per claim type turned out to be overkill. Collapse them into a single claims.all queue bound on claim.# with one consumer that branches on claimType internally. Also remove the purge endpoint, it's been ruled a production hazard. Add GET /claims/dead-letter/stats returning queue depth broken down by claimType, without consuming anything. Tell me what I need to do to the broker before running this, then clean up anything unused and run the tests.
```

> **Watch for:** Does it warn you to delete the old queues first? Silence means a tester hits PRECONDITION_FAILED and logs a false connector defect. Also check the allowPurge configurable and its Config.toml key are gone.

## Scenario 2 — Fulfilment Saga · `RabbitMQ:prompt-2`

*Server-named reply queues, correlation, compensating saga, TLS and cluster failover — then deleting a whole saga branch and converting synchronous RPC to asynchronous.*

### S2-v1 — *build*

```text
Build an order fulfilment coordinator on RabbitMQ using request-reply. POST /fulfilment/orders takes a FulfilmentRequest with orderId, warehouseId, items of sku and quantity, and shippingMethod. For each request create a server-named exclusive reply queue, publish a reservation request to inventory.reserve with replyTo and correlationId set, and wait for the reply with a configurable timeout. Return 504 if it doesn't arrive. Check what the installed connector supports first. Ask me for the broker details.
```

### S2-v2 — *extend + test*

```text
Add the inventory responder: a service on inventory.reserve that checks stock and publishes a ReservationResponse back to the request's replyTo with the same correlation ID, acking only after the reply is sent. Then make it a compensating saga. After reservation, charge payment and dispatch shipping. If payment fails, release the inventory; if shipping fails, refund. Track saga state per order and expose it on GET /fulfilment/orders/{orderId}/saga. Also configure additional broker addresses so the client fails over to another node when the primary is unreachable. Check the failover address field exists in this connector version before using it, and tell me how I could prove the failover actually happens when I only have one broker. Then write tests and run them.
```

> **Watch for:** The answer to the last question should be to point the primary at a dead port and the failover address at the live broker - testable with a single node. Claiming a second broker is required, or skipping the question, is a finding.

### S2-v3 — *remove + replace*

```text
Shipping is moving to its own service. Take that step out of the saga along with the refund compensation, so it's reserve-then-charge with inventory release as the only compensation. Also drop the synchronous reply wait, it ties up an HTTP worker for the whole saga. Return 202 immediately with the orderId, and have a consumer on fulfilment.replies correlate replies and advance the state. Clients poll the saga endpoint for the outcome. Clean up what's left, then run the tests.
```

> **Watch for:** Check the saga state machine loses its shipping and refund states cleanly, and that the RPC timeout configurable goes along with the correlation-to-caller map.

## Scenario 3 — Notification Fan-Out · `RabbitMQ:prompt-3`

*Fanout exchange, quorum queues with max-priority (baited — likely incompatible), per-tenant throttling, redelivery idempotency — then deleting a channel and the whole priority mechanism.*

### S3-v1 — *baited*

```text
Create a multi-tenant notification dispatcher on RabbitMQ. Declare a fanout exchange notifications.broadcast with durable queues notifications.email, notifications.sms and notifications.push bound to it. Make them quorum queues with a max priority so urgent notifications can jump the queue. POST /notifications takes tenantId, notificationId, recipients, subject, body, channels and urgency. Map urgency to a message priority, put tenantId in the headers, and publish once to the exchange. Check the queue arguments for this connector and RabbitMQ version before using them, and tell me what you used. Ask me for the broker details.
```

### S3-v2 — *web search + test*

```text
First, search the web and confirm whether RabbitMQ actually supports x-max-priority on quorum queues in the current release. Report what you find with links, and if they're incompatible, redesign it and explain, rather than leaving broken arguments in the code. Then add a consumer per channel with its own prefetch and a configurable per-tenant rate limit, requeueing rather than dropping when a tenant is over its limit. Add delivery tracking per notificationId and channel that suppresses duplicates on redelivery, exposed on GET /notifications/{notificationId}. Then write tests and run them.
```

> **Watch for:** The payoff for the v1 bait. Silently keeping incompatible arguments after the search is a Code Quality defect; redesigning and explaining is a pass.

### S3-v3 — *remove + replace*

```text
SMS is being retired. Remove that channel completely, queue, binding, consumer and the enum value. Also drop the priority mechanism given what the docs search turned up. Replace it with a separate notifications.urgent queue bound to the same exchange with its own consumer. Keep the urgency field, it picks the destination now instead of a priority number. Make sure no trace of sms is left anywhere, then run the tests.
```

> **Watch for:** Removing an enum value is the sharpest dead-code probe here. Run grep -rn sms . afterwards: log messages, doc comments and test fixture names are where it survives.

---

# ballerinax/java.jms

JMS needs provider client JARs as platform dependencies in Ballerina.toml (platform.java21 here). Whether Copilot recognises that unprompted, and gets the initial context factory right, is the highest-value thing to watch.

## Scenario 1 — Core-Banking Bridge · `JMS:prompt-1`

*Transacted sessions, client acknowledgement, temporary reply destinations, message selectors, platform dependencies — then deleting the enquiry endpoint and the transactions themselves.*

### S1-v1 — *build*

```text
Create an integration bridging a REST API to a core-banking system over JMS on ActiveMQ Artemis. POST /banking/transfers takes a TransferRequest with transferId, debitAccount, creditAccount, amount, currency and valueDate, and sends it as a JMS text message to CORE.TRANSFER.REQUEST with correlationId set to the transferId and a jmsType of CORE_TRANSFER. Tell me which provider JARs need to go into Ballerina.toml as platform dependencies and add them. Check the installed JMS connector version for the APIs. Ask me for the connection settings.
```

### S1-v2 — *extend + test*

```text
Make the transfer path transactional, committing only after the message is sent and the audit record written, rolling back otherwise. Add a service on CORE.TRANSFER.RESPONSE with client ack that correlates replies back to the pending transfer and acks only once correlated. Unmatched replies go to CORE.TRANSFER.UNMATCHED rather than being silently acked. Add GET /banking/accounts/{accountNumber}/balance doing synchronous request-reply over CORE.ENQUIRY.REQUEST with a temporary reply queue and a selector on correlation ID, 504 on timeout. Close everything on the error paths too. Then write tests and run them.
```

### S1-v3 — *remove + replace*

```text
Drop the balance enquiry endpoint, it's moving to a read replica. Remove it and the temporary-queue request-reply machinery with it. The audit write has moved to its own service too, so the transacted session isn't needed. Switch the transfer path to client acknowledgement, and tell me what durability guarantee that costs before you make the change. Add a max redelivery count on the response service so anything past it goes to CORE.TRANSFER.DLQ. Clean up anything unused, including Ballerina.toml, then run the tests.
```

> **Watch for:** Watch whether it explains the lost guarantee BEFORE editing. Making the change silently is a Copilot Flow finding even if the code is right.

## Scenario 2 — Market Data Distribution · `JMS:prompt-2`

*Durable and shared-durable subscriptions (baited), selectors, MapMessage, delivery mode and TTL, connection lifecycle — then dropping durability and the alerts path.*

### S2-v1 — *baited*

```text
Create a market data service that subscribes to the JMS topic MARKET.DATA.PRICES with a durable subscription so nothing is lost while it's down. Configurable client ID and subscriber name, client ack, and a selector limiting it to a configurable list of instrument classes. Bind to a PriceTick record with instrumentId, instrumentClass, bid, ask, lastTradedPrice, volume and tickTime, acking only after each tick is processed. Check which consumer types the installed version supports, durable, shared or shared-durable, and use only what's there. Ask me for the connection settings.
```

### S2-v2 — *web search + test*

```text
First, look up the current JMS documentation and confirm two things: how provider JARs should be declared in Ballerina.toml, and whether shared durable subscriptions are actually supported here. Report with links and fix anything that doesn't match. Then republish each tick to MARKET.DATA.NORMALISED as a map message, and to MARKET.DATA.ALERTS when the bid-ask spread crosses a per-class threshold, using non-persistent delivery, a short TTL and a higher priority than normalised ticks. Add pause and resume endpoints, and an unsubscribe that refuses with 409 while messages are in flight. Then write tests and run them.
```

### S2-v3 — *remove + replace*

```text
We're scaling this out horizontally, so a single durable subscription no longer works. Switch to a non-durable subscription and remove the unsubscribe endpoint with it. Tell me what we lose while the consumer is down. Also drop the alerts path entirely, spread alerting is moving to the risk platform. Add a running count of ticks per instrumentClass on GET /marketdata/stats, and keep pause and resume as they are. Clean up what's now unused and run the tests.
```

> **Watch for:** Check the client ID and subscriber name configurables are removed from both code and Config.toml, and that the in-flight conflict guard is deleted rather than left unreachable.

## Scenario 3 — Shipment Tracking Bridge · `JMS:prompt-3`

*Fixed-width parsing, carrier routing, batch draining with receive and receiveNoWait, transacted batches, poison escalation — then replacing the parser with JSON and deleting the batch window.*

### S3-v1 — *build*

```text
Create an integration consuming shipment status events from the JMS queue SHIPMENT.STATUS.IN on ActiveMQ Artemis, using the JMS connector. The legacy system sends fixed-width text, so parse it into a ShipmentStatus record with shipmentId, carrierCode, status, locationCode, statusAt and an optional exceptionReason. Use client ack, and send anything that won't parse to SHIPMENT.STATUS.INVALID with the error in a property, then ack it so it doesn't redeliver forever. Check the installed JMS connector version for the APIs, and tell me which provider JARs this needs in Ballerina.toml. Ask me for the connection settings.
```

### S3-v2 — *extend + test*

```text
Publish accepted events to SHIPMENT.STATUS.OUT as map messages, and exceptions to SHIPMENT.EXCEPTIONS with higher priority and a TTL. Route by carrier using a configurable map with a default queue for unknown carriers, and set carrier and status as properties so downstream can use selectors. Add POST /shipments/reconcile for the nightly window: drain SHIPMENT.STATUS.REPLAY in configurable batches with one commit per batch, using the non-blocking receive to spot an empty queue rather than waiting out the timeout. Add poison-message handling so anything past a max attempt count goes to the DLQ. Then write tests and run them.
```

### S3-v3 — *remove + replace*

```text
The legacy system now emits JSON, so the fixed-width parser can go. Bind JSON straight into ShipmentStatus and send binding failures to the DLQ with an error category instead of a separate invalid queue. The nightly reconciliation window has been decommissioned too, so remove that endpoint and its batching. If that was the only thing using the transacted session, tell me what you're changing the ack mode to and why. Clean up anything unused and run the tests.
```

> **Watch for:** Check column-offset constants and fixed-width test fixtures are deleted, and that there is an explicit decision on the ack mode rather than a silent switch.

---

# ballerinax/solace

PubSub+ event mesh. SMF plaintext is on host port 55554, TLS on 55443. Client-certificate auth and OAuth2 are NOT enabled on VPN default, so those paths won't authenticate even with valid material.

## Scenario 1 — Airline Operations Event Mesh · `Solace:prompt-1`

*Hierarchical topics, DeliveryMode (baited), selectors, FlowDownError / InactiveFlowError, temporary-queue request-reply, TLS and OAuth2 — then deleting rebooking and the whole OAuth2 profile.*

### S1-v1 — *baited*

```text
Create an airline operations integration that publishes flight events to a Solace topic hierarchy. POST /ops/flight-events takes a FlightEvent with eventId, flightNumber, carrierCode, departureAirport, arrivalAirport, eventType, scheduledTime, actualTime and an optional delayMinutes. Publish to airline/ops/{carrierCode}/{departureAirport}/{eventType} with persistent delivery, a priority derived from eventType with cancellations highest, and correlationId set to the eventId. Check the installed Solace connector version, in particular which delivery modes its enum actually defines, and don't use one that isn't there. Ask me for the broker URL, VPN and credentials.
```

### S1-v2 — *extend + test*

```text
Add a consumer on the durable queue AIRLINE.OPS.DISRUPTIONS with client ack and a selector accepting only DELAY and CANCELLATION. Nack with requeue on transient failures and without requeue on permanent ones, and handle the flow-down and inactive-flow errors separately rather than catching a generic error. Add rebooking request-reply: POST /ops/rebooking publishes to airline/rebooking/request/{carrierCode} with a temporary reply queue, plus a responder service on the other side. Then put it behind TLS with a truststore, and add an OAuth2 auth profile selectable by config alongside basic auth. Ask me for the secrets. Then write tests and run them.
```

> **Watch for:** OAuth2 IS supported by the connector, so asking for a token is correct. Check it asks for the ISSUER too — OAuth2AccessTokenAuth requires both fields. Asking only for the token is an incomplete config request.

### S1-v3 — *remove + replace*

```text
Rebooking is moving to its own service, so take it out, both the endpoint and the responder. We're also dropping OAuth2, the broker estate standardised on basic auth over TLS. Remove that profile and the authMode switch. Keep TLS, but make the client keystore optional, the broker doesn't ask for a client certificate and the service should start without it. Add a configurable list of carrier codes this deployment handles and reject anything else with 422 before publishing. Clean up what's unused and run the tests.
```

> **Watch for:** The optional-keystore clause is deliberate. solace:SecureSocket.keyStore IS optional, and generated code has been observed making it required, which blocks startup for a broker that never requests a client certificate.

## Scenario 2 — Payment Instruction Gateway · `Solace:prompt-2`

*Transacted producer and consumer, commit and rollback, nack-on-transacted-flow (baited — documented as an error), deliveryCount poison handling — then removing transactions altogether.*

### S2-v1 — *build*

```text
Create a payment instruction gateway on Solace using transacted messaging. POST /payments/instructions takes a PaymentInstruction with instructionId, debtorIban, creditorIban, amount, currency, executionDate and paymentScheme. In a transacted producer session, publish to PAYMENTS.INSTRUCTIONS.IN with persistent delivery, write the audit entry, and commit only if both succeed, rolling back and returning 503 otherwise. Check whether the installed Solace connector version actually supports transactions before writing it. If it doesn't, tell me rather than faking it. Ask me for the broker URL, VPN and credentials.
```

### S2-v2 — *web search + test*

```text
Look up the current Solace documentation on transacted sessions with guaranteed messaging, and any limits on transaction size or duration. Report with links and align the code, telling me what changed. Then add the consumer side: a transacted service on PAYMENTS.INSTRUCTIONS.IN that validates and republishes to PAYMENTS.SETTLEMENT.OUT, committing so consume and publish settle together. Check how nack behaves on a transacted flow in this version and follow that. Add poison handling using the delivery count, sending to the DLQ past a configurable max, plus duplicate suppression by sequence number. Then write tests and run them.
```

> **Watch for:** The connector documents nack as returning an error on transacted flows. Generating a nack call here without comment is a Code Quality defect; naming the constraint is a pass.

### S2-v3 — *remove + replace*

```text
Transactions are coming out. Throughput testing showed they're too slow for our SEPA volumes, and the audit write has moved to an append-only log that doesn't need to be atomic with the publish. Drop transacted messaging on both sides and switch the consumer to client ack. Tell me what guarantee that costs and what happens now if we crash between publish and ack. Drop the sequence-number dedup too. Instead use the instructionId as correlation ID and skip republishing when the delivery count shows a redelivery. Clean up and run the tests.
```

> **Watch for:** Every commit and rollback should be gone from both sides, the transacted flags off the producer and listener config, and the sequence-number field removed from the message rather than just unused.

## Scenario 3 — Retail Store Telemetry · `Solace:prompt-3`

*Topic wildcards, durable topic endpoints, expiration calculation, blocking versus non-blocking receive, the 36-byte userData limit (baited), compression — then deleting the batch window and userData.*

### S3-v1 — *build*

```text
Create a retail telemetry collector on Solace. Subscribe with a durable topic endpoint to every store's device telemetry under retail/telemetry/{region}/{storeId}/{deviceType}, and tell me which wildcard characters you used and what each matches. Bind to a DeviceTelemetry record with storeId, region, deviceType, deviceId, metric, value, unit and readingAt. Turn on receive timestamps and expiration calculation, and drop readings whose expiration has already passed. Ask me for the broker URL, VPN and credentials.
```

### S3-v2 — *baited + test*

```text
Add POST /telemetry/drain for the nightly batch: pull from the durable queue RETAIL.TELEMETRY.BATCH with client ack using a blocking receive with a configurable timeout, switching to the non-blocking receive to spot an empty queue. Return the drained and skipped-expired counts, and close the consumer on every path. Alert to retail/alerts/{region}/{storeId} when a metric crosses a per-device-type threshold, with direct delivery, a short TTL and top priority. Put a compact correlation payload in the user-data field, respecting its size limit. Enable connection compression and tell me the trade-off. Add a bounded buffer that sheds oldest under backpressure, with counts on GET /telemetry/health. Then write tests and run them.
```

> **Watch for:** The user-data field is capped at 36 bytes. Copilot should find that limit and design around it rather than silently attaching an oversized payload.

### S3-v3 — *remove + replace*

```text
Everything's streaming now, so the nightly batch window is gone. Remove the drain endpoint and the synchronous consumer it uses. The user-data field turned out too small to be useful, so drop it and carry the correlation data in message properties instead. Compression is being disabled fleet-wide too, so take that out. Add a configurable per-region allow list that drops and counts telemetry from regions not on it, surfaced on the health endpoint. Leave the buffer counters alone unless the buffer itself is now unused. Clean up and run the tests.
```

> **Watch for:** A conditional-deletion trap. The backpressure buffer IS still used, so its counters must stay. Removing them anyway is over-deletion — as much a defect as under-deletion.

---

# Prompt bank

## Deletion review — after every v3

The point of the v3 prompts. Deletions stress review, diff and reject far harder than additions.

**X1**

```text
List what you deleted and what you added in that last change. Then check for anything left behind: unused imports, configurables nothing reads, types nothing references, Config.toml or Ballerina.toml entries that are now dead, tests or mocks for things that no longer exist. Check, don't assume.
```

> **Watch for:** A leftover unused import, orphaned configurable, stale Config.toml key, undropped dependency, or a test left disabled instead of deleted all go under Code Quality / Usage. A deletion that breaks compilation goes under Runtime Issues.

**X2**

```text
[Verify yourself, don't take its word. In the project directory:]

bal build -- no unused-import warnings
bal test -- passes, nothing left disabled
grep -rn "<removed symbol>". -- nothing outside.git
```

**X3**

```text
[Reject behaviour on a deletion diff. Critical, and easy to skip.]

1. Run a v3 prompt and let it generate.
2. In review mode, REJECT the edits.
3. Confirm every deleted line comes back exactly, with no dangling brace or half-removed function, and the project still compiles.
```

> **Watch for:** Rejecting an addition is trivial; rejecting a DELETION means restoring removed code. The single most likely place for review mode to leave a broken working tree. Anything left behind is a high-severity UI defect.

## Config values — human-in-the-loop (§5.1)

Run after any v1 that Copilot answered without asking. Real working values for every broker are in broker-lab/.

**C1**

```text
What configuration does this need that I haven't given you yet? Ask me for each value, put them in Config.toml, and confirm it's git-ignored. There shouldn't be a broker host, username, password or token literal anywhere in the source.
```

> **Watch for:** Defect signal: invented plausible values (localhost:9092, guest/guest) not flagged as placeholders needing confirmation -> Copilot Flow Issues Found.

## Web search (§5.5)

Each connector has one embedded web-search prompt in its v2. B1 is a generic extra probe for any of the four.

**B1**

```text
What's the latest released version of this connector on Central, and has anything broken since the version we're pinned to? Check the web, give me links, and tell me if upgrading would need code changes here.
```

> **Watch for:** Verify the search tool is actually invoked, that the links are real, and that the answer reflects fetched content rather than pre-training recall.

## Copilot skills (§5.5)

Mandatory in every library's flow. Record whether the skill fired, fired late, fired twice, or was silently skipped.

**S1**

```text
What Copilot skills are available here, and which apply to what we're building?
```

**S2**

```text
[Invoke the most relevant skill by name, using the name Copilot reported in S1, and confirm it actually triggers rather than being paraphrased.]
```

**S3**

```text
Set up a fresh package for this, add the connector dependency and get it compiling before we write any logic.
```

> **Watch for:** S3 should trigger a skill implicitly, without naming one. A skill that never fires here is a Copilot Flow defect.

## Multi chat threads (§5.5)

Test extensively. Threads must stay isolated, history preserved per thread, context must not leak.

**T1**

```text
[Thread A: run Scenario 1 v1 and v2. Open a NEW thread B in the same workspace and run Scenario 2 v1. Then return to thread A and send:] Add the dead-letter path we discussed.
```

> **Watch for:** Thread A must recall its own code, type names and destinations -- not thread B's.

**T2**

```text
What's the payload record type you created earlier in this conversation, and what does it consume from? Answer only from this conversation.
```

> **Watch for:** Send this in thread B. If it answers with thread A's type or destination, that is context leakage -- a Copilot Flow defect.

**T3**

```text
[No prompt. Close the workspace, reopen it, switch between all threads, and confirm each thread's history, file associations and pending diffs survived.]
```

## Surgical edits on an existing project (§5.1, §3.3)

Run on the mid-development project. Then check the diff file list: any file changed outside scope, or whitespace-only churn, is a defect.

**M1**

```text
Add the retry and dead-letter behaviour to the existing consumer service only. Don't change the REST contract, don't rename types, and don't reformat files you're not functionally changing. Show me the plan first.
```

**M2**

```text
Change only the error handling in the consumer service to use structured logging. Don't touch any other file.
```

## Interruption resilience (§5.1)

An action taken mid-generation, not a prompt. Target any v2 or v3 -- both are long enough to interrupt.

**R1**

```text
[While Copilot is mid-generation:]

1. Close the Copilot panel entirely, wait about ten seconds, reopen it.
2. Switch to a different file, then a different editor group, then back.
3. Switch to a different chat thread and back.
4. Switch UI surface mid-generation -- side panel to right-hand panel.
```

> **Watch for:** Generation must continue and state must be preserved. A restart, reset, lost thinking trace, duplicated tool call or orphaned half-applied edit is a Copilot Flow defect.

## Final diagram (§5.5)

Run at the end of every scenario, and also inspect the diagram Copilot renders on its own.

**D1**

```text
Show me the diagram for what we've built and walk me through it. Does everything in the code appear in it?
```

> **Watch for:** After a v3 especially: check REMOVED components have disappeared. A diagram still showing a deleted queue or endpoint is a UI defect.

## Follow-up suggestion accuracy (§5.3)

After any generation completes, read the suggested next steps before typing anything, then send F1.

**F1**

```text
Your first suggested next step, which files would it change, and is it actually the right thing to do here?
```

> **Watch for:** A suggestion referencing a nonexistent file, a completed step, or an unsupported feature is a Code Quality / Usage defect.

## Hallucination probes — one per connector

The correct answer is always “that doesn't exist in this version”, plus a supported alternative.

**H-kafka**

```text
Use the kafka module's built-in dead-letter-topic feature instead of our manual DLQ producer. Check it exists first.
```

**H-rabbitmq**

```text
Use the rabbitmq client's built-in delayed-message API to retry 30s out instead of the TTL queue. Check it exists first.
```

**H-jms**

```text
Configure a built-in retry policy with backoff on the JMS session so we don't need manual redelivery counting. Check it exists first.
```

**H-solace**

```text
Switch the alerts to NON_PERSISTENT delivery and use the producer's built-in delayed delivery API. Check both exist first.
```

> **Watch for:** Confirming and then generating code against an API that does not exist is the highest-severity finding in this category. Log it with the exact generated snippet.

## Connector selection

Different from a hallucination probe: the API does exist, but a better-suited library exists too. Tests whether Copilot reaches for a generic protocol module when a dedicated connector is available.

**L1**

```text
We're moving this integration onto IBM MQ. Should I keep using JMS, or is there a better-suited connector for IBM MQ specifically? Check what's available before answering.
```

> **Watch for:** ballerinax/ibm.ibmmq (1.4.4) exists and is the right answer - a dedicated connector with QueueManager, Queue, Topic, Listener and Caller, native MQ get/put options and MQ-specific headers. Recommending java.jms with a JNDI setup, or claiming no dedicated connector exists, is a Code Quality / Usage finding.

**L2**

```text
Is ballerinax/java.jms the right module for talking to this broker, or is there a connector built specifically for it? Justify the choice.
```

