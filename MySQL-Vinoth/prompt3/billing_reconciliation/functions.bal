
import ballerinax/mysql;

// Shared connection profile so every client in this project uses the
// same SSL + timeout policy instead of repeating it in each connection.
// NOTE: the mysql compiler plugin does NOT range-check connectTimeout /
// socketTimeout (verified: even an inlined literal like -2 builds clean).
// So the sanity check below is enforced explicitly, once, at module-init
// time via a panic -- this runs during startup, before any of the four
// clients in connections.bal are constructed, so a bad value here blocks
// the whole module from coming up instead of silently connecting with a
// broken timeout.
public const mysql:SSLMode DB_SSL_MODE = mysql:SSL_REQUIRED;
public const decimal DB_CONNECT_TIMEOUT = 20;
public const decimal DB_SOCKET_TIMEOUT = 15;

function validateDbTimeout(decimal timeoutSeconds, string fieldName) returns decimal {
    if timeoutSeconds <= 0d {
        panic error(string `Invalid ${fieldName}: ${timeoutSeconds}. Timeout values must be positive.`);
    }
    return timeoutSeconds;
}

final decimal validatedConnectTimeout = validateDbTimeout(DB_CONNECT_TIMEOUT, "DB_CONNECT_TIMEOUT");
final decimal validatedSocketTimeout = validateDbTimeout(DB_SOCKET_TIMEOUT, "DB_SOCKET_TIMEOUT");

// Shared options record built once from the validated values above, and
// reused (not copy-pasted) across all four mysql:Client definitions.
final mysql:Options dbOptions = {
    ssl: {mode: DB_SSL_MODE},
    connectTimeout: validatedConnectTimeout,
    socketTimeout: validatedSocketTimeout
};