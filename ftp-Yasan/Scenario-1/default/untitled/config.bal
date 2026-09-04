// SFTP connection configuration, supplied at deployment time.
configurable string sftpHost = ?;
configurable int sftpPort = ?;
configurable string sftpUsername = ?;
configurable string sftpPrivateKeyPath = ?;

// Server-side directories used for exchanging order files with the partner.
const string OUTGOING_DIR = "/outgoing";
const string PROCESSED_DIR = "/processed";
const string ARCHIVE_DIR = "/archive";

// Order files are named like 'orders-20240115.csv'.
final string:RegExp ORDER_FILE_PATTERN = re `^orders-\d{8}\.csv$`;
