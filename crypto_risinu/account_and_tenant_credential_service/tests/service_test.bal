import ballerina/http;
import ballerina/test;

const string TEST_SERVICE_URL = "http://localhost:8080/auth";

final http:Client testClient = check new (TEST_SERVICE_URL);

// Computes the machine-to-machine proof header value for a given tenant and
// raw request body, mirroring exactly what a legitimate caller would send.
function computeProof(string tenantId, string requestBody) returns string|error {
    return computeTenantProofHex(tenantId, requestBody);
}

// Onboards a tenant directly (bypassing HTTP) so tests can set up fixtures
// without depending on the tenant-registration endpoint's HTTP behavior.
function ensureTenantRegistered(string tenantId) returns error? {
    if !tenantStore.hasKey(tenantId) {
        TenantRegistrationResult|error result = registerTenant(tenantId);
        if result is error {
            return result;
        }
    }
}

@test:BeforeSuite
function beforeSuite() returns error? {
    check ensureTenantRegistered("tenant-alpha");
    check ensureTenantRegistered("tenant-beta");
}

// ----- Tenant registration -----

@test:Config {}
function testTenantRegistrationSucceeds() returns error? {
    TenantRegistration payload = {tenantId: "tenant-fresh"};
    TenantRegistrationResult response = check testClient->/tenants.post(payload);

    test:assertEquals(response.tenantId, "tenant-fresh", msg = "Tenant id should echo back");
    test:assertTrue(response.tenantSecret.length() > 0, msg = "A derived tenant secret should be returned");
}

@test:Config {dependsOn: [testTenantRegistrationSucceeds]}
function testDuplicateTenantRegistrationRejected() returns error? {
    TenantRegistration payload = {tenantId: "tenant-fresh"};
    http:Response response = check testClient->/tenants.post(payload);

    test:assertEquals(response.statusCode, 400, msg = "Duplicate tenant id should be rejected with 400");
}

// ----- Account registration -----

@test:Config {}
function testAccountRegistrationSucceeds() returns error? {
    string tenantId = "tenant-alpha";
    Credentials payload = {username: "reg-success-user", password: "correct-horse-battery"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 201, msg = "Registration with a valid password should succeed");

    json responseJson = check response.getJsonPayload();
    AuthResult authResult = check responseJson.cloneWithType(AuthResult);
    test:assertEquals(authResult.message, "Registration successful.", msg = "Success message mismatch");
}

@test:Config {dependsOn: [testAccountRegistrationSucceeds]}
function testAccountRegistrationRejectsShortPassword() returns error? {
    string tenantId = "tenant-alpha";
    Credentials payload = {username: "reg-short-pw-user", password: "short"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 400, msg = "A password under 12 characters should be rejected");
}

@test:Config {dependsOn: [testAccountRegistrationSucceeds]}
function testAccountRegistrationRejectsDuplicateUsername() returns error? {
    string tenantId = "tenant-alpha";
    Credentials payload = {username: "reg-success-user", password: "another-long-password"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 400, msg = "Re-registering the same username should be rejected");
}

// ----- Login success/failure -----

@test:Config {dependsOn: [testAccountRegistrationSucceeds]}
function testLoginSucceedsWithCorrectPassword() returns error? {
    string tenantId = "tenant-alpha";
    Credentials payload = {username: "reg-success-user", password: "correct-horse-battery"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/login.post(request);
    test:assertEquals(response.statusCode, 201, msg = "Login with the correct password should succeed");

    json responseJson = check response.getJsonPayload();
    AuthResult authResult = check responseJson.cloneWithType(AuthResult);
    test:assertEquals(authResult.message, "Login successful.", msg = "Success message mismatch");
}

@test:Config {dependsOn: [testAccountRegistrationSucceeds]}
function testLoginFailsWithWrongPassword() returns error? {
    string tenantId = "tenant-alpha";
    Credentials payload = {username: "reg-success-user", password: "totally-wrong-password"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/login.post(request);
    test:assertEquals(response.statusCode, 401, msg = "Login with the wrong password should be rejected");
}

// ----- Identical response for unknown user vs wrong password -----

@test:Config {dependsOn: [testAccountRegistrationSucceeds]}
function testUnknownUserAndWrongPasswordProduceIdenticalResponse() returns error? {
    string tenantId = "tenant-alpha";

    Credentials unknownUserPayload = {username: "nobody-such-user", password: "irrelevant-password-1"};
    string unknownUserBody = unknownUserPayload.toJsonString();
    string unknownUserProof = check computeProof(tenantId, unknownUserBody);

    http:Request unknownUserRequest = new;
    unknownUserRequest.setJsonPayload(unknownUserPayload.toJson());
    unknownUserRequest.setHeader("X-Tenant-Id", tenantId);
    unknownUserRequest.setHeader("X-Tenant-Proof", unknownUserProof);

    http:Response unknownUserResponse = check testClient->/login.post(unknownUserRequest);

    Credentials wrongPasswordPayload = {username: "reg-success-user", password: "totally-wrong-password"};
    string wrongPasswordBody = wrongPasswordPayload.toJsonString();
    string wrongPasswordProof = check computeProof(tenantId, wrongPasswordBody);

    http:Request wrongPasswordRequest = new;
    wrongPasswordRequest.setJsonPayload(wrongPasswordPayload.toJson());
    wrongPasswordRequest.setHeader("X-Tenant-Id", tenantId);
    wrongPasswordRequest.setHeader("X-Tenant-Proof", wrongPasswordProof);

    http:Response wrongPasswordResponse = check testClient->/login.post(wrongPasswordRequest);

    test:assertEquals(unknownUserResponse.statusCode, wrongPasswordResponse.statusCode,
            msg = "Unknown user and wrong password must produce the same status code");

    json unknownUserJson = check unknownUserResponse.getJsonPayload();
    json wrongPasswordJson = check wrongPasswordResponse.getJsonPayload();
    AuthResult unknownUserResult = check unknownUserJson.cloneWithType(AuthResult);
    AuthResult wrongPasswordResult = check wrongPasswordJson.cloneWithType(AuthResult);

    test:assertEquals(unknownUserResult.message, wrongPasswordResult.message,
            msg = "Unknown user and wrong password must produce the same message");
}

// ----- Silent upgrade of a legacy-hashed account on next login -----

@test:Config {}
function testLegacyHashAccountIsSilentlyUpgradedOnLogin() returns error? {
    string tenantId = "tenant-alpha";
    string username = "legacy-hash-user";
    string password = "legacy-account-password";

    string legacyHash = check hashWithLegacyScheme(password);
    test:assertTrue(isLegacyHash(legacyHash), msg = "Fixture hash should be recognized as legacy");

    string key = accountKey(tenantId, username);
    Account legacyAccount = {tenantId, username, passwordHash: legacyHash};
    accountStore[key] = legacyAccount;

    Credentials payload = {username, password};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/login.post(request);
    test:assertEquals(response.statusCode, 201, msg = "Login against a legacy-hashed account should still succeed");

    Account? upgradedAccount = accountStore[key];
    if upgradedAccount is Account {
        test:assertFalse(isLegacyHash(upgradedAccount.passwordHash),
                msg = "Stored hash should be upgraded away from the legacy scheme");
        test:assertNotEquals(upgradedAccount.passwordHash, legacyHash,
                msg = "Stored hash value should have changed after the upgrade");
    } else {
        test:assertFail(msg = "Account should still exist after login");
    }

    boolean stillVerifies = check verifyPassword(password, upgradedAccount is Account ? upgradedAccount.passwordHash : "");
    test:assertTrue(stillVerifies, msg = "The same password should still verify against the upgraded hash");
}

// ----- Tenant proof accepted / tampered proof rejected -----

@test:Config {}
function testValidTenantProofIsAccepted() returns error? {
    string tenantId = "tenant-beta";
    Credentials payload = {username: "proof-ok-user", password: "a-valid-long-password"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", proof);

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 201, msg = "A correctly computed tenant proof should be accepted");
}

@test:Config {}
function testTamperedTenantProofIsRejected() returns error? {
    string tenantId = "tenant-beta";
    Credentials payload = {username: "proof-tampered-user", password: "a-valid-long-password"};
    string requestBody = payload.toJsonString();
    string proof = check computeProof(tenantId, requestBody);

    // Flip the last character to simulate a tampered/incorrect proof.
    string tamperedProof = proof.substring(0, proof.length() - 1) + (proof.endsWith("a") ? "b" : "a");

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", tenantId);
    request.setHeader("X-Tenant-Proof", tamperedProof);

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 401, msg = "A tampered tenant proof should be rejected");

    json responseJson = check response.getJsonPayload();
    AuthResult authResult = check responseJson.cloneWithType(AuthResult);
    test:assertEquals(authResult.message, "Unauthorized.", msg = "Tampered proof should produce the generic unauthorized message");
}

@test:Config {}
function testUnrecognizedTenantProducesSameResponseAsTamperedProof() returns error? {
    Credentials payload = {username: "someone", password: "irrelevant-password-2"};

    http:Request request = new;
    request.setJsonPayload(payload.toJson());
    request.setHeader("X-Tenant-Id", "tenant-does-not-exist");
    request.setHeader("X-Tenant-Proof", "0123456789abcdef");

    http:Response response = check testClient->/accounts.post(request);
    test:assertEquals(response.statusCode, 401, msg = "An unrecognized tenant id should be rejected as unauthorized");

    json responseJson = check response.getJsonPayload();
    AuthResult authResult = check responseJson.cloneWithType(AuthResult);
    test:assertEquals(authResult.message, "Unauthorized.", msg = "Unrecognized tenant should produce the generic unauthorized message");
}
