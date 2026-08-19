
import ballerinax/mysql;

// Shared connection profile so every client in this project uses the
// same SSL + timeout policy instead of repeating it in each connection.
function buildDbOptions() returns mysql:Options => {
    ssl: {mode: mysql:SSL_REQUIRED},
    connectTimeout: -2, // <- meant to be 20
    socketTimeout: 15
};