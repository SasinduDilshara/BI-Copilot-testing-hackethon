// File user store entries backing the admin console. Each entry's password is stored
// as a BCrypt hash (see security note in functions.bal) — never in plaintext.
//
// NOTE: ballerina/auth's built-in ListenerFileUserStoreBasicAuthProvider only performs a
// direct plaintext string comparison against the `password` value in the special
// [[ballerina.auth.users]] Config.toml section — it has no hashed-password verification
// capability. Since hashed-at-rest passwords were required, that built-in provider cannot
// be used here; instead, users are declared under a regular configurable table below and
// verified explicitly with ballerina/crypto's BCrypt APIs (see functions.bal).
configurable table<HashedUserStoreEntry> key(username) adminConsoleUsers = ?;
