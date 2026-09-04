import ballerina/email;
import ballerina/log;
import ballerina/time;
import ballerinax/sap.businessone.inventory;
import ballerinax/sap.businessone.purchasing;

// SAP Business One Service Layer configuration
configurable string serviceLayerUrl = ?;
configurable string companyDb = ?;
configurable string username = ?;
configurable string password = ?;

// Procurement notification configuration
configurable string requesterEmail = ?;
configurable string procurementEmail = ?;
configurable int businessPlaceId = ?;

// SMTP configuration
configurable string smtpHost = ?;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable int smtpPort = 465;
configurable string smtpSecurity = "SSL";

inventory:Client inventoryClient = check new (
    {companyDb, username, password},
    serviceUrl = serviceLayerUrl
);

purchasing:Client purchasingClient = check new (
    {companyDb, username, password},
    serviceUrl = serviceLayerUrl
);

email:Security smtpSecurityMode = smtpSecurity == "START_TLS_NEVER" ? email:START_TLS_NEVER :
    smtpSecurity == "START_TLS_ALWAYS" ? email:START_TLS_ALWAYS :
    smtpSecurity == "START_TLS_AUTO" ? email:START_TLS_AUTO : email:SSL;

email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, {
    port: smtpPort,
    security: smtpSecurityMode
});

public function main() returns error? {
    // Step 1: List low-stock items from SAP Business One Inventory
    inventory:ItemsCollectionResponse lowStockResult = check inventoryClient->listItems(
        dollarFilter = "QuantityOnStock lt 10 and PurchaseItem eq 'YES'"
    );
    inventory:Item[] lowStockItems = lowStockResult.value ?: [];

    // Step 2: Empty-stock handling
    if lowStockItems.length() == 0 {
        log:printInfo("No low-stock items to reorder.");
        return;
    }

    // Step 3 & 4: Create purchase requests and send email notifications
    foreach inventory:Item lowStockItem in lowStockItems {
        string itemCode = lowStockItem.ItemCode ?: "";

        purchasing:DocumentLine documentLine = {
            ItemCode: itemCode,
            Quantity: 50
        };

        purchasing:Document purchaseRequestPayload = {
            DocumentLines: [documentLine],
            RequesterEmail: requesterEmail,
            RequriedDate: getRequiredDate(),
            BPL_IDAssignedToInvoice: <int:Signed32> businessPlaceId
        };

        purchasing:Document purchaseRequest = check purchasingClient->createPurchaseRequests(purchaseRequestPayload);

        int docNum = purchaseRequest.DocNum ?: 0;

        log:printInfo("Created purchase request", docNum = docNum, itemCode = itemCode);

        // Send email notification for the successfully created purchase request
        string itemName = lowStockItem.ItemName ?: "";
        decimal quantityOnStock = lowStockItem.QuantityOnStock ?: 0;

        string emailBody = string `Item code: ${itemCode}
Item name: ${itemName}
Current quantity: ${quantityOnStock}
Purchase request number: ${docNum}
Requested quantity: 50`;

        email:Message notificationMessage = {
            to: procurementEmail,
            subject: "Low stock: " + itemCode,
            body: emailBody
        };

        check smtpClient->sendMessage(notificationMessage);
    }

    log:printInfo("Done - reordered low-stock items");
}

function getRequiredDate() returns string {
    time:Utc currentUtc = time:utcNow();
    time:Utc requiredUtc = time:utcAddSeconds(currentUtc, 7 * 24 * 60 * 60);
    time:Civil requiredCivil = time:utcToCivil(requiredUtc);
    string year = requiredCivil.year.toString();
    string month = requiredCivil.month < 10 ? "0" + requiredCivil.month.toString() : requiredCivil.month.toString();
    string day = requiredCivil.day < 10 ? "0" + requiredCivil.day.toString() : requiredCivil.day.toString();
    return year + "-" + month + "-" + day;
}
