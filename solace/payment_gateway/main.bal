import ballerina/http;
import ballerinax/solace;

service /payments on new http:Listener(servicePort) {

    # Accepts a payment instruction, publishes it to the guaranteed instructions queue, and writes
    # its audit entry within a single transacted producer session.
    #
    # + paymentInstruction - The payment instruction to process
    # + return - The acknowledgement on success, or a 503 error response if the transacted publish
    # and audit write could not both be completed
    resource function post instructions(@http:Payload PaymentInstruction paymentInstruction)
            returns PaymentInstructionAccepted|PaymentInstructionUnavailable {

        solace:Error? result = processPaymentInstruction(paymentInstruction);
        if result is solace:Error {
            return <PaymentInstructionUnavailable>{
                body: {
                    message: string `Failed to process payment instruction: ${result.message()}`
                }
            };
        }

        return <PaymentInstructionAccepted>{
            body: {
                instructionId: paymentInstruction.instructionId,
                queueName: paymentInstructionsQueueName
            }
        };
    }
}
