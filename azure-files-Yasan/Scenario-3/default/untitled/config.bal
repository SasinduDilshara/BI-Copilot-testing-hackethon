// Azure Storage account credentials and share configuration.
configurable string accountName = ?;
configurable string accountKey = ?;
configurable string shareName = ?;

// Local directory of finished reports to archive.
configurable string localReportsDirectory = "./reports";

// Number of days to retain dated archive directories before they are pruned.
configurable int retentionDays = 30;
