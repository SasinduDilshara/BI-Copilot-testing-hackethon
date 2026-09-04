import ballerina/log;
import ballerina/tcp;

// Mock SMTP server used only for local testing of the integration. Implements the minimal
// SMTP command sequence (EHLO, AUTH LOGIN, MAIL FROM, RCPT TO, DATA) required for
// email:SmtpClient to successfully deliver the order confirmation email.
configurable int mockSmtpPort = 2525;

service on new tcp:Listener(mockSmtpPort) {
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService|tcp:Error {
        log:printInfo("Mock SMTP server accepted a connection", remotePort = caller.remotePort);
        check caller->writeBytes(stringToBytes("220 mock-smtp-server ready\r\n"));
        return new MockSmtpConnectionService(caller);
    }
}

service class MockSmtpConnectionService {
    *tcp:ConnectionService;

    private final tcp:Caller caller;
    private boolean inData = false;
    private string emailContent = "";
    private boolean awaitingUsername = false;
    private boolean awaitingPassword = false;

    function init(tcp:Caller caller) {
        self.caller = caller;
    }

    remote function onBytes(readonly & byte[] data) returns byte[]|tcp:Error? {
        string|error chunk = string:fromBytes(data);
        if chunk is error {
            return ();
        }

        if self.inData {
            self.emailContent += chunk;
            if chunk.endsWith("\r\n.\r\n") {
                self.inData = false;
                log:printInfo("Mock SMTP server received email content", content = self.emailContent);
                check self.caller->writeBytes(stringToBytes("250 OK: message queued\r\n"));
            }
            return ();
        }

        string[] lines = split(chunk);
        foreach string line in lines {
            check self.handleCommandLine(line.trim());
        }
        return ();
    }

    private function handleCommandLine(string line) returns tcp:Error? {
        if line.length() == 0 {
            return ();
        }

        if self.awaitingUsername {
            self.awaitingUsername = false;
            self.awaitingPassword = true;
            check self.caller->writeBytes(stringToBytes("334 UGFzc3dvcmQ6\r\n"));
            return ();
        }

        if self.awaitingPassword {
            self.awaitingPassword = false;
            check self.caller->writeBytes(stringToBytes("235 Authentication successful\r\n"));
            return ();
        }

        string upperLine = line.toUpperAscii();

        if upperLine.startsWith("EHLO") || upperLine.startsWith("HELO") {
            check self.caller->writeBytes(stringToBytes("250-mock-smtp-server\r\n250-AUTH LOGIN PLAIN\r\n250 OK\r\n"));
        } else if upperLine.startsWith("AUTH LOGIN") {
            self.awaitingUsername = true;
            check self.caller->writeBytes(stringToBytes("334 VXNlcm5hbWU6\r\n"));
        } else if upperLine.startsWith("MAIL FROM") {
            check self.caller->writeBytes(stringToBytes("250 OK\r\n"));
        } else if upperLine.startsWith("RCPT TO") {
            check self.caller->writeBytes(stringToBytes("250 OK\r\n"));
        } else if upperLine.startsWith("DATA") {
            self.inData = true;
            self.emailContent = "";
            check self.caller->writeBytes(stringToBytes("354 Start mail input; end with <CRLF>.<CRLF>\r\n"));
        } else if upperLine.startsWith("QUIT") {
            check self.caller->writeBytes(stringToBytes("221 Bye\r\n"));
        } else {
            check self.caller->writeBytes(stringToBytes("250 OK\r\n"));
        }
        return ();
    }

    remote function onError(tcp:Error err) returns tcp:Error? {
        log:printError("Mock SMTP server connection error", 'error = err);
    }

    remote function onClose() returns tcp:Error? {
        log:printInfo("Mock SMTP server connection closed");
    }
}

function stringToBytes(string text) returns byte[] => text.toBytes();

function split(string text) returns string[] {
    string[] lines = [];
    string remaining = text;
    while remaining.length() > 0 {
        int? idx = remaining.indexOf("\r\n");
        if idx is () {
            if remaining.trim().length() > 0 {
                lines.push(remaining);
            }
            break;
        }
        string line = remaining.substring(0, idx);
        if line.trim().length() > 0 {
            lines.push(line);
        }
        remaining = remaining.substring(idx + 2);
    }
    return lines;
}
