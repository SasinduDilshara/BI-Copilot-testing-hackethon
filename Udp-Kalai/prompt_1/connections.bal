// Isolated in-memory store holding the latest reading per sensor, keyed by sensorId.
isolated map<SensorReading> sensorReadings = {};

// Isolated in-memory store holding the last 100 critical alert events.
isolated AlertEvent[] alertHistory = [];
