
import ballerina/http;

function verifyIdentity(AccountApplication app) returns error? {
    IdentityCheckRequest req = {
        applicationId: app.applicationId,
        fullName: app.fullName,
        dateOfBirth: app.dateOfBirth,
        countryCode: app.countryCode
    };
    http:Response _ = check identityClient->post("/verify", req,
        {"Authorization": "Bearer " + identityApiKey});
}