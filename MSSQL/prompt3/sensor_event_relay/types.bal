
# Raw CDC change record shape captured from the sensor_events table.
public type SensorEventChange record {
    string eventId;
    string sensorId;
    decimal reading;
    string recordedAt;
};

# Sensor event enriched with the originating plant before being forwarded to analytics.
public type PlantTaggedSensorEvent record {|
    string eventId;
    string sensorId;
    decimal reading;
    string recordedAt;
    string plant;
|};