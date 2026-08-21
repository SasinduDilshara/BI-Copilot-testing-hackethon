import ballerina/http;

listener http:Listener orderFraudListener = new (9090);

service /orders on orderFraudListener {

    # Analyses an incoming order for fraud risk using the orderFraudAgent.
    #
    # + orderRequest - the strongly typed order payload to analyse
    # + return - the structured fraud analysis result, or an error if analysis fails
    resource function post fraudCheck(@http:Payload OrderRequest orderRequest) returns FraudAnalysisResult|error {
        string query = string `Analyse the following order for fraud risk: ${orderRequest.toJsonString()}`;

        FraudAnalysisResult analysisResult =
            check orderFraudAgent.run(query, sessionId = orderRequest.orderId);
        return analysisResult;
    }
}
