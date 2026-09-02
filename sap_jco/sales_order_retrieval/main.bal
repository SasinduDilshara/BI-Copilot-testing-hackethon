import ballerina/email;
import ballerina/http;
import ballerina/log;
import ballerinax/sap.jco;

// ============================================================================
// HTTP entry point for the customer service department.
//
// Flow:
//   Receive Sales Order -> Connect to SAP ECC (SAP JCo) -> Get JCo Repository
//   -> Retrieve BAPI_SALESORDER_GETDETAIL -> Set SALESDOCUMENT -> Execute BAPI
//   -> Read RETURN -> Read ORDER_HEADER -> Read ORDER_ITEMS
//   -> Transform Response -> Send Email (SMTP)
// ============================================================================

listener http:Listener salesOrderListener = new (8080);

service /sap/salesorders on salesOrderListener {

    # Retrieves a sales order from SAP ECC via SAP JCo and notifies the
    # customer service team by email.
    #
    # + request - The sales order lookup request containing the sales order number
    # + return - SuccessResponse on full success, PartialSuccessResponse when SAP
    # succeeds but the email fails, SapBusinessErrorResponse when the BAPI
    # reports a functional error, SapConnectionErrorResponse when SAP ECC
    # cannot be reached, or GenericErrorResponse for validation issues
    resource function post retrieve(@http:Payload SalesOrderRequest request)
            returns SuccessResponse|PartialSuccessResponse|SapBusinessErrorResponse
            |SapConnectionErrorResponse|GenericErrorResponse|http:InternalServerError {

        string salesOrderNumber = request.salesOrder.trim();
        if salesOrderNumber.length() == 0 {
            GenericErrorResponse validationError = {
                errorCode: "INVALID_REQUEST",
                message: "salesOrder is required"
            };
            return validationError;
        }

        log:printInfo("Received sales order retrieval request", salesOrder = salesOrderNumber);

        // Step 1 & 2: Connect to SAP ECC and execute BAPI_SALESORDER_GETDETAIL
        // through the SAP JCo destination/repository (see functions.bal).
        BapiSalesOrderGetDetailOutput|jco:Error bapiResult = getSalesOrderFromSap(salesOrderNumber);

        if bapiResult is jco:Error {
            log:printError("SAP JCo connection/execution failure", 'error = bapiResult,
                    salesOrder = salesOrderNumber);
            SapConnectionErrorResponse connectionError = {
                message: "Unable to connect to SAP ECC"
            };
            return connectionError;
        }

        // Step 3: Read RETURN and check for a BAPI business-level failure.
        BapiReturn bapiReturn = bapiResult.RETURN;
        if isSapBusinessError(bapiReturn) {
            log:printWarn("SAP BAPI reported a business error", salesOrder = salesOrderNumber,
                    sapMessage = bapiReturn.MESSAGE);
            SapBusinessErrorResponse businessError = {
                salesOrder: salesOrderNumber,
                message: bapiReturn.MESSAGE
            };
            return businessError;
        }

        // Step 4: Read ORDER_HEADER / ORDER_ITEMS and transform the response.
        SalesOrderDetails orderDetails = transformSalesOrder(salesOrderNumber, bapiResult);

        // Step 5: Send the customer service notification email via SMTP.
        email:Error? emailResult = sendSalesOrderEmail(orderDetails);

        if emailResult is email:Error {
            log:printError("SMTP send failed after successful SAP retrieval", 'error = emailResult,
                    salesOrder = salesOrderNumber);
            PartialSuccessResponse partialSuccess = {
                salesOrder: salesOrderNumber,
                message: "Unable to send notification email"
            };
            return partialSuccess;
        }

        log:printInfo("Sales order retrieved and notification email sent", salesOrder = salesOrderNumber);
        SuccessResponse successResponse = {
            salesOrder: salesOrderNumber,
            recipient: notificationRecipient
        };
        return successResponse;
    }
}
