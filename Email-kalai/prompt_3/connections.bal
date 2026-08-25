import ballerina/email;

final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword);
