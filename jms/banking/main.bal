import ballerina/http;

service /banking on new http:Listener(servicePort) {

    # Accepts a transfer request and forwards it to the core-banking system over JMS.
    #
    # + transferRequest - The transfer details to be processed
    # + return - The accepted transfer confirmation, or an error response
    resource function post transfers(@http:Payload TransferRequest transferRequest)
            returns TransferAccepted|http:InternalServerError {
        error? sendResult = sendTransferRequest(transferRequest);
        if sendResult is error {
            return {
                body: {
                    message: "Failed to submit transfer request to core-banking system: " + sendResult.message()
                }
            };
        }
        return {
            transferId: transferRequest.transferId,
            status: "ACCEPTED"
        };
    }
}
