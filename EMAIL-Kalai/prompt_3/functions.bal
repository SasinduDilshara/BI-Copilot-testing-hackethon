import ballerina/email;

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
    return smtpClient->send(
        to = onboardRequest.personalEmail,
        subject = "Welcome to the Company!",
        'from = smtpUsername,
        body = "",
        htmlBody = htmlBody,
        cc = hrEmail,
        bcc = complianceEmail,
        replyTo = hrEmail
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
