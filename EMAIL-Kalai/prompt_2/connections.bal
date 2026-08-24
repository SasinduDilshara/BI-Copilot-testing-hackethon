import ballerina/email;

final email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, port = smtpPort);

final email:ImapClient imapClient = check new (imapHost, imapUsername, imapPassword, port = imapPort);
