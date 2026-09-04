import ballerinax/azure.storage.files;

// Account-level client used to ensure the share exists.
final files:AdminClient azureFilesAdminClient = check new (auth = {accountName, accountKey});

// Share-scoped client used for all directory and file operations on the archive share.
final files:Client azureFilesClient = check new (shareName, auth = {accountName, accountKey});
