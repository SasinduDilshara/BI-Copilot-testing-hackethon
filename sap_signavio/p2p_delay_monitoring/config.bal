// Configuration values required to run the SAP Signavio -> Email (SMTP) integration.
//
// NOTE: signavioUsername/signavioPassword/smtpHost/smtpUsername/smtpPassword below have
// mock/placeholder defaults so the project (and its mocked test suite) can run without
// external configuration. Override these with real values in Config.toml for production use.

// --- SAP Signavio connection configuration ---
configurable string signavioUsername = "mock-signavio-user";
configurable string signavioPassword = "mock-signavio-password";
configurable string signavioRegion = "eu";

// SAP Signavio Process Intelligence process id that identifies the
// Purchase-to-Pay process definition to be monitored.
configurable string p2pProcessId = "purchase-to-pay";

// --- Business rule configuration ---
// Maximum number of hours a process instance may wait in the "Manager Approval"
// activity before a delay notification is triggered.
configurable decimal approvalThresholdHours = 24;

// --- SMTP configuration ---
configurable string smtpHost = "mock-smtp.example.com";
configurable string smtpUsername = "mock-smtp-user";
configurable string smtpPassword = "mock-smtp-password";
configurable int smtpPort = 587;

// --- Scheduling configuration ---
// Interval, in seconds, between two consecutive monitoring cycles.
configurable decimal pollingIntervalSeconds = 3600;
