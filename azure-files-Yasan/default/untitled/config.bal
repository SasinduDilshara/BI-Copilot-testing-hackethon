// Azure storage account credentials used to authenticate the Azure Files listener.
configurable string storageAccountName = ?;
configurable string storageAccountKey = ?;

// Polling interval, in seconds, at which the listener checks the share for new files.
configurable decimal pollingIntervalSeconds = 30;

// Name of the Azure Files share that contains the /inbound, /processed and /error directories.
configurable string invoiceShareName = ?;
