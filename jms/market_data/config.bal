// ActiveMQ Artemis broker connection URL.
configurable string providerUrl = "tcp://localhost:61616";

// Instrument classes this subscriber is interested in. Used to build a JMS message selector so
// only ticks for these instrument classes are delivered to this subscription.
configurable string[] instrumentClasses = ["EQUITY", "FX", "FIXED_INCOME"];

// HTTP listener port for the pause/resume/stats control endpoints.
configurable int servicePort = 8080;

// JMS priority (0-9) used for normalised tick messages published to MARKET.DATA.NORMALISED.
configurable int normalisedTickPriority = 4;
