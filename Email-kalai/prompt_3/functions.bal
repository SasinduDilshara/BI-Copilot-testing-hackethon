import ballerina/email;
import ballerina/mime;

function validateOnboardRequest(OnboardRequest onboardRequest) returns ValidationErrorDetail? {
    if !onboardRequest.personalEmail.includes("@") {
        return {'field: "personalEmail", reason: "must contain '@'"};
    }
    if !onboardRequest.managerEmail.includes("@") {
        return {'field: "managerEmail", reason: "must contain '@'"};
    }
    return ();
}

function createCompanyPolicyAttachment(string employeeId) returns mime:Entity {
    string policyContent = string `Company Policy Summary
=======================
1. Working Hours: Standard working hours are 9 AM to 5 PM, Monday to Friday.
2. Code of Conduct: Treat all colleagues with respect and professionalism.
3. Leave Policy: Submit leave requests at least two weeks in advance.
4. Confidentiality: Do not share confidential company information externally.
5. IT Usage: Company equipment must be used responsibly and for business purposes.
`;
    mime:Entity policyAttachment = new;
    mime:ContentDisposition policyDisposition = new;
    policyDisposition.fileName = string `company-policy-${employeeId}.txt`;
    policyDisposition.disposition = "attachment";
    policyAttachment.setContentDisposition(policyDisposition);
    policyAttachment.setText(policyContent, contentType = "text/plain");
    return policyAttachment;
}

function createItSetupGuideAttachment() returns mime:Entity {
    string setupGuideContent = string `IT Setup Guide
==============
1. Log in to your company laptop using the credentials provided by IT.
2. Set up your company email account on your laptop and mobile device.
3. Install the VPN client and connect using your credentials.
4. Set up multi-factor authentication for your company accounts.
5. Install required software listed by your department.
6. Contact the IT helpdesk if you face any issues during setup.
`;
    mime:Entity setupGuideAttachment = new;
    mime:ContentDisposition setupGuideDisposition = new;
    setupGuideDisposition.fileName = "it-setup-guide.txt";
    setupGuideDisposition.disposition = "attachment";
    setupGuideAttachment.setContentDisposition(setupGuideDisposition);
    setupGuideAttachment.setText(setupGuideContent, contentType = "text/plain");
    return setupGuideAttachment;
}

function checkProvisioningConfirmation(string employeeId) returns string? {
    email:PopConfiguration popConfig = {
        port: popPort
    };
    email:PopClient|email:Error popClient = new (popHost, popUsername, popPassword, clientConfig = popConfig);
    if popClient is email:Error {
        return ();
    }

    string? confirmationBody = ();
    int attempt = 0;
    while attempt < 5 {
        email:Message|email:Error? receiveResult = popClient->receiveMessage();
        if receiveResult is email:Message {
            string subject = receiveResult.subject;
            if subject.includes(employeeId) {
                string? textBody = receiveResult.body;
                if textBody is string {
                    confirmationBody = textBody;
                } else {
                    confirmationBody = receiveResult.htmlBody;
                }
                break;
            }
        }
        attempt += 1;
    }

    email:Error? closeResult = popClient->close();
    if closeResult is email:Error {
        // Ignore close errors, the confirmation check result still stands.
    }

    return confirmationBody;
}

function sendWelcomeEmail(OnboardRequest onboardRequest) returns email:Error? {
    string htmlBody = string `
        <html>
        <body>
            <p>Dear ${onboardRequest.fullName},</p>
            <p>Welcome to the company! We are delighted to have you join the
            <b>${onboardRequest.department}</b> department.</p>
            <p>Your start date is <b>${onboardRequest.startDate}</b>, and your manager will be
            <b>${onboardRequest.managerName}</b>.</p>
            <p>We look forward to working with you.</p>
            <p>Best regards,<br/>HR Team</p>
        </body>
        </html>
    `;
    mime:Entity companyPolicyAttachment = createCompanyPolicyAttachment(onboardRequest.employeeId);
    mime:Entity itSetupGuideAttachment = createItSetupGuideAttachment();

    return smtpClient->send(
        to = onboardRequest.personalEmail,
        subject = "Welcome to the Company!",
        'from = smtpUsername,
        body = "",
        htmlBody = htmlBody,
        cc = hrEmail,
        bcc = complianceEmail,
        replyTo = hrEmail,
        attachments = [companyPolicyAttachment, itSetupGuideAttachment]
    );
}

function sendManagerNotificationEmail(OnboardRequest onboardRequest) returns email:Error? {
    string body = string `Dear ${onboardRequest.managerName},

A new team member, ${onboardRequest.fullName}, will be joining the ${onboardRequest.department} department on ${onboardRequest.startDate}.

Please schedule a first-day check-in with them.

Best regards,
HR Team`;
    return smtpClient->send(
        to = onboardRequest.managerEmail,
        subject = "New Team Member Joining Your Team",
        'from = smtpUsername,
        body = body
    );
}

function sendItProvisioningEmail(OnboardRequest onboardRequest) returns email:Error? {
    string body = string `Dear IT Team,

Please set up the necessary accounts and equipment for the new employee joining on ${onboardRequest.startDate}.

Employee ID: ${onboardRequest.employeeId}
Full Name: ${onboardRequest.fullName}
Department: ${onboardRequest.department}

Best regards,
HR Team`;
    return smtpClient->send(
        to = onboardRequest.itTeamEmail,
        subject = "IT Provisioning Request for New Employee",
        'from = smtpUsername,
        body = body
    );
}
