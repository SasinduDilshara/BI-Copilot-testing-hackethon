import ballerina/email;
import ballerina/http;

service /hr on new http:Listener(7070) {

    resource function post onboard(@http:Payload OnboardRequest onboardRequest) returns OnboardResponse|http:InternalServerError {
        string[] failedRecipients = [];
        int emailsSent = 0;

        email:Error? welcomeResult = sendWelcomeEmail(onboardRequest);
        if welcomeResult is email:Error {
            failedRecipients.push(onboardRequest.personalEmail);
        } else {
            emailsSent += 1;
        }

        email:Error? managerResult = sendManagerNotificationEmail(onboardRequest);
        if managerResult is email:Error {
            failedRecipients.push(onboardRequest.managerEmail);
        } else {
            emailsSent += 1;
        }

        email:Error? itResult = sendItProvisioningEmail(onboardRequest);
        if itResult is email:Error {
            failedRecipients.push(onboardRequest.itTeamEmail);
        } else {
            emailsSent += 1;
        }

        if failedRecipients.length() == 0 {
            return {
                employeeId: onboardRequest.employeeId,
                emailsSent: emailsSent,
                status: "completed"
            };
        }

        return {
            employeeId: onboardRequest.employeeId,
            emailsSent: emailsSent,
            status: "partial_failure",
            failedRecipients: failedRecipients
        };
    }

    resource function post 'check\-provisioning/[string employeeId]() returns ProvisioningCheckResponse {
        string? confirmationBody = checkProvisioningConfirmation(employeeId);
        if confirmationBody is string {
            return {
                employeeId: employeeId,
                provisioningStatus: "completed",
                provisioningConfirmation: confirmationBody
            };
        }

        return {
            employeeId: employeeId,
            provisioningStatus: "pending"
        };
    }
}
