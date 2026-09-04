import ballerinax/azure.storage.files;

listener files:Listener invoiceShareListener = check new (invoiceShareName, {
    auth: {
        accountName: storageAccountName,
        accountKey: storageAccountKey
    },
    pollingInterval: pollingIntervalSeconds
});

// In-memory vendor master-data store, keyed by vendorId.
map<VendorUpdate> vendorStore = {};
