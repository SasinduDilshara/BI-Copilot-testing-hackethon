1. When running tests for MQTT, it didn't know it needed to have a secondary Config.toml in the tests/ directory at first. It tried to run tests, failed and then asked for the configs using another configuration form.
2. When scrolling the chat, it always auto-scrolls down to the bottom to show updates. This makes it hard to read stuff.
3. Cannot queue messages.
4. Noticed when the agent is editing a file, it logs 2 tool calls 1. Creating
6. Is it okay that it goes ahead and creates random .bal files outside of the structure of a normal Low code generated integration? Also sometimes a trigger code is getting created in automation.bal - ASB example
7. ASB listener onError was generated wrongly -     remote function onError(asb:MessageRetrievalError 'error, error asbError) returns error? - Should be fixed with the metadata.json though
8. ![alt text](image.png)
9. Sometimes half of the configs are asked in the middle of code generation. Then the agent realizes it needs further configs, which is fine. However, when re-prompting, it asks for the new configs and the old configs that I provided before to be submitted again.
10. Showing thinking steps would make the user feel that the agent is actually progressing.
11. ASB prompt-1:v2 creates a regional SQL rule without removing the subscription's default `$Default` rule. The default rule continues to match every message, so the subscription is not actually restricted to the configured region.
12. ASB prompt-1:v3's live future-scheduling test fails: the command scheduled 30 seconds ahead is received and completed before its requested time.
13. ASB prompt-2:v1's `publishAssessmentResult` only logs the result and returns success. The input message is then completed even though no assessment result is published to an ASB entity or another downstream system.
14. ASB prompt-2:v2 waits for the lock-renewal task after signalling it to stop, but the task cannot leave its current `runtime:sleep` early. This adds up to the full renewal interval to every fast claim before settlement and causes later live tests to time out.
15. ASB prompt-2:v3 does not add a `manualReview` marker to `ClaimSubmission`; instead, it infers manual review solely when the simulated score sees an amount greater than 50,000. The live defer/receive test also times out before the deferred counter increases.
16. ASB prompt-2:v1's transient scoring failure path is unreachable because `scoreClaim` always returns a result and `publishAssessmentResult` cannot fail, so the requested abandon behaviour and counter are not meaningfully tested.
17. ASB prompt-2's batch worker propagates any per-message settlement error out of its loop. A single complete, dead-letter, defer, or abandon failure can therefore terminate the background worker and stop all later claim processing.
18. ASB prompt-1:v2's transient failure test only verifies that a direct send to a nonexistent topic fails. It does not exercise the production listener, verify that the input message is abandoned, or check the abandoned counter.
