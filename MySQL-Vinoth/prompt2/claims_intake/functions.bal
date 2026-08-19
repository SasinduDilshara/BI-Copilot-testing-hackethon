import ballerina/http;

function forwardToAdjudication(ClaimSubmission claim) returns error? {
    AdjudicationRequest req = {
        claimNumber: claim.claimNumber,
        policyNumber: claim.policyNumber,
        diagnosisCode: claim.diagnosisCode,
        billedAmount: claim.billedAmount,
        coverageLimit: 0d // TODO: no policy lookup yet — placeholder
    };
    http:Response _ = check adjudicationClient->post("/adjudicate", req,
        {"Authorization": "Bearer " + adjudicationApiKey});
}
