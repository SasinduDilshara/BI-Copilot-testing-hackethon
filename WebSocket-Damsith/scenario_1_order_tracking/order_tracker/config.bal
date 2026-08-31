// Port on which the secured (wss) order tracking listener is exposed.
configurable int servicePort = 9090;

// TLS certificate and private key used to secure the WebSocket listener (wss).
configurable string tlsCertFile = "./resources/public.crt";
configurable string tlsKeyFile = "./resources/private.key";

// JWT validator settings used to authenticate customers connecting to the tracking feed.
configurable string jwtIssuer = "wso2";
configurable string jwtAudience = "ballerina";
configurable string jwtSigningCertFile = "./resources/public.crt";

// Name of the JWT custom claim that carries the order ID the customer is entitled to track.
configurable string orderIdClaimName = "orderId";
