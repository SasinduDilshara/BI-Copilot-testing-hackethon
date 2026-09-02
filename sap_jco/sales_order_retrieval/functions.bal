import ballerina/email;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;
import ballerinax/sap.jco;

// ============================================================================
// Core integration logic:
//   Receive Sales Order -> Connect to SAP ECC -> Execute BAPI_SALESORDER_GETDETAIL
//   -> Read RETURN / ORDER_HEADER / ORDER_ITEMS -> Transform -> Send Email
// ============================================================================

# Invokes BAPI_SALESORDER_GETDETAIL on SAP ECC via the SAP JCo client for the
# given sales document number, retrying transient SAP connection failures.
#
# JCo repository/BAPI lookup: internally, `sapEccClient->execute` asks the JCo
# repository (`JCoRepository`) bound to this destination for the function
# module metadata of `BAPI_SALESORDER_GETDETAIL` (its import/export parameters
# and table structures, e.g. SALESDOCUMENT, ORDER_HEADER, ORDER_ITEMS, RETURN),
# builds a matching `JCoFunction`, sets `SALESDOCUMENT`, executes the RFC call
# against SAP ECC, and maps the resulting SAP structures/tables back into the
# `BapiSalesOrderGetDetailOutput` record declared below.
#
# + salesOrderNumber - The sales order number to retrieve (SALESDOCUMENT)
# + return - The BAPI output on success, or a typed SAP JCo error on failure
function getSalesOrderFromSap(string salesOrderNumber) returns BapiSalesOrderGetDetailOutput|jco:Error {
    BapiSalesOrderGetDetailInput input = {SALESDOCUMENT: salesOrderNumber};

    int attempt = 0;
    while true {
        BapiSalesOrderGetDetailOutput|jco:Error result = sapEccClient->execute(
                "BAPI_SALESORDER_GETDETAIL",
                {importParameters: input}
        );

        if result is BapiSalesOrderGetDetailOutput {
            return result;
        }

        boolean transientFailure = result is jco:ConnectionError || result is jco:LogonError
            || result is jco:SystemError || result is jco:ResourceError;

        if !transientFailure || attempt >= sapRetryCount {
            log:printError("SAP ECC connection failed for sales order " + salesOrderNumber,
                    'error = result, attempt = attempt + 1);
            return result;
        }

        attempt += 1;
        log:printWarn("Transient SAP connection issue, retrying", attempt = attempt,
                salesOrder = salesOrderNumber);
        runtime:sleep(sapRetryDelaySeconds);
    }
}

# Checks whether the BAPI RETURN structure indicates a functional/business
# error (TYPE = E for Error or A for Abort) as opposed to success or a warning.
#
# + bapiReturn - The RETURN structure obtained from the BAPI execution
# + return - True when the BAPI reported a business-level failure
function isSapBusinessError(BapiReturn bapiReturn) returns boolean {
    string returnType = bapiReturn.TYPE;
    return returnType == "E" || returnType == "A";
}

# Transforms the raw SAP JCo BAPI output (header structure + item internal
# table) into the canonical `SalesOrderDetails` representation used for the
# email notification.
#
# + salesOrderNumber - The sales order number requested
# + bapiOutput - The raw BAPI_SALESORDER_GETDETAIL output from SAP ECC
# + return - The transformed sales order details
function transformSalesOrder(string salesOrderNumber, BapiSalesOrderGetDetailOutput bapiOutput)
        returns SalesOrderDetails {
    SapOrderHeader header = bapiOutput.ORDER_HEADER;
    SapOrderItem[] rawItems = bapiOutput.ORDER_ITEMS;

    SalesOrderItem[] items = from SapOrderItem rawItem in rawItems
        select {
            itemNumber: rawItem.ITM_NUMBER,
            material: rawItem.MATERIAL,
            description: rawItem.SHORT_TEXT,
            quantity: rawItem.REQ_QTY,
            unit: rawItem.SALES_UNIT,
            netValue: rawItem.NET_VALUE
        };

    CustomerInfo customer = {
        id: header.SOLD_TO,
        name: header.CUST_NAME
    };

    return {
        salesOrder: salesOrderNumber,
        customer: customer,
        salesOrganization: header.SALES_ORG,
        distributionChannel: header.DISTR_CHAN,
        documentDate: header.DOC_DATE,
        currency: header.CURRENCY,
        netValue: header.NET_VALUE,
        items: items
    };
}

# Builds the plain-text customer service notification email body from the
# transformed sales order details.
#
# + orderDetails - The transformed sales order details
# + sapStatusMessage - The SAP BAPI RETURN message describing the outcome
# + return - The formatted email body text
function buildEmailBody(SalesOrderDetails orderDetails, string sapStatusMessage) returns string {
    string itemLines = "";
    int lineNumber = 1;
    foreach SalesOrderItem item in orderDetails.items {
        itemLines += string `${lineNumber}. ${item.description}
   Material: ${item.material}
   Quantity: ${item.quantity} ${item.unit}
   Value: ${orderDetails.currency} ${item.netValue}

`;
        lineNumber += 1;
    }

    string emailBody = string `Dear Customer Service Team,

The following sales order was successfully retrieved from SAP ECC using SAP JCo.

Sales Order: ${orderDetails.salesOrder}
Customer: ${orderDetails.customer.name}
Customer ID: ${orderDetails.customer.id}
Sales Organization: ${orderDetails.salesOrganization}
Document Date: ${orderDetails.documentDate}
Currency: ${orderDetails.currency}
Net Value: ${orderDetails.currency} ${orderDetails.netValue}

Items:

${itemLines}SAP BAPI: BAPI_SALESORDER_GETDETAIL
Status: ${sapStatusMessage}

Integration Timestamp: ${time:utcToString(time:utcNow())}

Regards,
SAP Integration System`;

    return emailBody;
}

# Sends the sales order notification email to the customer service mailbox.
#
# + orderDetails - The transformed sales order details
# + return - () on success, or an `email:Error` if the SMTP send failed
function sendSalesOrderEmail(SalesOrderDetails orderDetails) returns email:Error? {
    string subject = string `SAP ECC Sales Order Retrieved – ${orderDetails.salesOrder}`;
    string body = buildEmailBody(orderDetails, "SUCCESS");

    email:Message notification = {
        to: notificationRecipient,
        subject: subject,
        body: body,
        'from: smtpUsername
    };

    return smtpClient->sendMessage(notification);
}
