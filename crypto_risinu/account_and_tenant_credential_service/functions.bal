import ballerina/crypto;
import ballerina/log;

const int MINIMUM_PASSWORD_LENGTH = 12;

const string GENERIC_SERVER_ERROR_MESSAGE = "Something went wrong. Please try again later.";
const string INVALID_LOGIN_MESSAGE = "Invalid username or password.";

// Registers a new account. Validates the password length first, before doing
// anything else (including before checking whether the username exists), then
// rejects duplicate usernames, then hashes and stores the password.
function registerAccount(string username, string password) returns AuthResult|error {
    if password.length() < MINIMUM_PASSWORD_LENGTH {
        return error("Password does not meet the minimum length requirement");
    }

    if accountStore.hasKey(username) {
        return error("Username is already taken");
    }

    string passwordHash = check crypto:hashArgon2(password);
    Account newAccount = {username, passwordHash};
    accountStore[username] = newAccount;

    return {message: "Registration successful."};
}

// Authenticates an account. Always performs a hash verification, even when the
// username is unknown, and always returns the same outcome/message for
// "unknown username" and "wrong password" so callers cannot distinguish the
// two cases through the response or through timing.
function authenticateAccount(string username, string password) returns boolean|error {
    Account? existingAccount = accountStore[username];

    string hashToVerify = existingAccount is Account ? existingAccount.passwordHash : decoyPasswordHash;
    boolean passwordMatches = check crypto:verifyArgon2(password, hashToVerify);

    return existingAccount is Account && passwordMatches;
}

// Logs the real cause of an unexpected failure server-side while a generic
// message is returned to the caller.
function logInternalError(string context, error cause) {
    log:printError(context, 'error = cause);
}
