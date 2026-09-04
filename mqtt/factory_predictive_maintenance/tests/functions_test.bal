import ballerina/test;

@test:Config {}
function testExtractPlantAndMachineIdsFromVibrationTopic() returns error? {
    [string, string] ids = check extractPlantAndMachineIds("plant/plant-1/machines/machine-1/vibration");
    test:assertEquals(ids[0], "plant-1", msg = "plantId should be extracted correctly");
    test:assertEquals(ids[1], "machine-1", msg = "machineId should be extracted correctly");
}

@test:Config {}
function testExtractPlantAndMachineIdsFromRuntimeTopic() returns error? {
    [string, string] ids = check extractPlantAndMachineIds("plant/plant-2/machines/machine-9/runtime");
    test:assertEquals(ids[0], "plant-2", msg = "plantId should be extracted correctly");
    test:assertEquals(ids[1], "machine-9", msg = "machineId should be extracted correctly");
}

@test:Config {}
function testExtractPlantAndMachineIdsRejectsMalformedTopic() {
    [string, string]|error ids = extractPlantAndMachineIds("plant/plant-1/vibration");
    test:assertTrue(ids is error, msg = "A topic missing the machines segment should be rejected");
}

@test:Config {}
function testExtractPlantAndMachineIdsRejectsEmptySegments() {
    [string, string]|error ids = extractPlantAndMachineIds("plant//machines//vibration");
    test:assertTrue(ids is error, msg = "A topic with empty plantId or machineId should be rejected");
}

@test:Config {}
function testParseValidVibrationReading() returns error? {
    byte[] payload = string `{"vibrationMm":4.5,"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    VibrationReading reading = check parseVibrationReading(payload, "plant-1", "machine-1");

    test:assertEquals(reading.plantId, "plant-1", msg = "plantId should be set from the topic");
    test:assertEquals(reading.machineId, "machine-1", msg = "machineId should be set from the topic");
    test:assertEquals(reading.vibrationMm, 4.5d, msg = "vibrationMm should be parsed correctly");
    test:assertEquals(reading.recordedAt, "2026-09-04T03:54:49Z", msg = "recordedAt should be parsed correctly");
}

@test:Config {}
function testParseVibrationReadingRejectsInvalidJson() {
    byte[] payload = "not-json".toBytes();
    VibrationReading|error reading = parseVibrationReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Non-JSON payload should be rejected");
}

@test:Config {}
function testParseVibrationReadingRejectsMissingFields() {
    byte[] payload = string `{"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    VibrationReading|error reading = parseVibrationReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Payload missing vibrationMm should be rejected");
}

@test:Config {}
function testParseVibrationReadingRejectsInvalidTimestamp() {
    byte[] payload = string `{"vibrationMm":4.5,"recordedAt":"not-a-date"}`.toBytes();
    VibrationReading|error reading = parseVibrationReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Payload with invalid recordedAt should be rejected");
}

@test:Config {}
function testParseVibrationReadingRejectsWrongFieldType() {
    byte[] payload = string `{"vibrationMm":"high","recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    VibrationReading|error reading = parseVibrationReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Payload with wrong vibrationMm type should be rejected");
}

@test:Config {}
function testParseValidRuntimeReading() returns error? {
    byte[] payload = string `{"runtimeHours":120.5,"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    RuntimeReading reading = check parseRuntimeReading(payload, "plant-1", "machine-1");

    test:assertEquals(reading.plantId, "plant-1", msg = "plantId should be set from the topic");
    test:assertEquals(reading.machineId, "machine-1", msg = "machineId should be set from the topic");
    test:assertEquals(reading.runtimeHours, 120.5d, msg = "runtimeHours should be parsed correctly");
    test:assertEquals(reading.recordedAt, "2026-09-04T03:54:49Z", msg = "recordedAt should be parsed correctly");
}

@test:Config {}
function testParseRuntimeReadingRejectsInvalidJson() {
    byte[] payload = "not-json".toBytes();
    RuntimeReading|error reading = parseRuntimeReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Non-JSON payload should be rejected");
}

@test:Config {}
function testParseRuntimeReadingRejectsMissingFields() {
    byte[] payload = string `{"recordedAt":"2026-09-04T03:54:49Z"}`.toBytes();
    RuntimeReading|error reading = parseRuntimeReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Payload missing runtimeHours should be rejected");
}

@test:Config {}
function testParseRuntimeReadingRejectsInvalidTimestamp() {
    byte[] payload = string `{"runtimeHours":120.5,"recordedAt":"not-a-date"}`.toBytes();
    RuntimeReading|error reading = parseRuntimeReading(payload, "plant-1", "machine-1");
    test:assertTrue(reading is error, msg = "Payload with invalid recordedAt should be rejected");
}

@test:Config {}
function testVibrationBreachDetected() {
    VibrationReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 15.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertTrue(isVibrationBreach(reading, 10.0), msg = "Reading above max threshold should be a breach");
}

@test:Config {}
function testVibrationNotBreachedWithinLimit() {
    VibrationReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 4.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertFalse(isVibrationBreach(reading, 10.0), msg = "Reading within max threshold should not be a breach");
}

@test:Config {}
function testRuntimeBreachDetected() {
    RuntimeReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        runtimeHours: 600.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertTrue(isRuntimeBreach(reading, 500.0), msg = "Reading above max threshold should be a breach");
}

@test:Config {}
function testRuntimeNotBreachedWithinLimit() {
    RuntimeReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        runtimeHours: 100.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    test:assertFalse(isRuntimeBreach(reading, 500.0), msg = "Reading within max threshold should not be a breach");
}

@test:Config {}
function testBuildMaintenanceAlertTopic() {
    string topic = buildMaintenanceAlertTopic("plant-42");
    test:assertEquals(topic, "plant/plant-42/maintenance", msg = "Maintenance alert topic should be built with the plant id");
}

@test:Config {}
function testBuildVibrationAlert() {
    VibrationReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 15.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    MaintenanceAlert alert = buildVibrationAlert(reading, 10.0);

    test:assertEquals(alert.plantId, "plant-1", msg = "Alert should carry the plant id");
    test:assertEquals(alert.machineId, "machine-1", msg = "Alert should carry the machine id");
    test:assertEquals(alert.sensorType, "vibration", msg = "Alert should be typed as a vibration alert");
    test:assertEquals(alert.value, 15.0d, msg = "Alert should carry the recorded vibration value");
    test:assertEquals(alert.thresholdValue, 10.0d, msg = "Alert should carry the configured threshold");
}

@test:Config {}
function testBuildRuntimeAlert() {
    RuntimeReading reading = {
        plantId: "plant-1",
        machineId: "machine-1",
        runtimeHours: 600.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    MaintenanceAlert alert = buildRuntimeAlert(reading, 500.0);

    test:assertEquals(alert.plantId, "plant-1", msg = "Alert should carry the plant id");
    test:assertEquals(alert.machineId, "machine-1", msg = "Alert should carry the machine id");
    test:assertEquals(alert.sensorType, "runtime", msg = "Alert should be typed as a runtime alert");
    test:assertEquals(alert.value, 600.0d, msg = "Alert should carry the recorded runtime value");
    test:assertEquals(alert.thresholdValue, 500.0d, msg = "Alert should carry the configured threshold");
}

@test:Config {}
function testMachineStateStoreTracksLatestVibrationReading() {
    MachineStateStore store = new;
    VibrationReading firstReading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 3.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    VibrationReading secondReading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 6.0,
        recordedAt: "2026-09-04T04:00:00Z"
    };
    store.recordVibrationReading(firstReading);
    store.recordVibrationReading(secondReading);

    MachineState? state = store.getState("plant-1", "machine-1");
    test:assertTrue(state is MachineState, msg = "State should exist after recording readings");
    if state is MachineState {
        VibrationReading? latestVibration = state.latestVibration;
        test:assertTrue(latestVibration is VibrationReading, msg = "Latest vibration reading should be present");
        if latestVibration is VibrationReading {
            test:assertEquals(latestVibration.vibrationMm, 6.0d, msg = "Latest vibration reading should reflect the most recent update");
        }
    }
}

@test:Config {}
function testMachineStateStoreTracksLatestRuntimeReading() {
    MachineStateStore store = new;
    RuntimeReading firstReading = {
        plantId: "plant-2",
        machineId: "machine-5",
        runtimeHours: 50.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    RuntimeReading secondReading = {
        plantId: "plant-2",
        machineId: "machine-5",
        runtimeHours: 75.0,
        recordedAt: "2026-09-04T04:00:00Z"
    };
    store.recordRuntimeReading(firstReading);
    store.recordRuntimeReading(secondReading);

    MachineState? state = store.getState("plant-2", "machine-5");
    test:assertTrue(state is MachineState, msg = "State should exist after recording readings");
    if state is MachineState {
        RuntimeReading? latestRuntime = state.latestRuntime;
        test:assertTrue(latestRuntime is RuntimeReading, msg = "Latest runtime reading should be present");
        if latestRuntime is RuntimeReading {
            test:assertEquals(latestRuntime.runtimeHours, 75.0d, msg = "Latest runtime reading should reflect the most recent update");
        }
    }
}

@test:Config {}
function testMachineStateStoreTracksMachinesIndependently() {
    MachineStateStore store = new;
    VibrationReading machineOneReading = {
        plantId: "plant-1",
        machineId: "machine-1",
        vibrationMm: 3.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    VibrationReading machineTwoReading = {
        plantId: "plant-1",
        machineId: "machine-2",
        vibrationMm: 9.0,
        recordedAt: "2026-09-04T03:54:49Z"
    };
    store.recordVibrationReading(machineOneReading);
    store.recordVibrationReading(machineTwoReading);

    MachineState? machineOneState = store.getState("plant-1", "machine-1");
    MachineState? machineTwoState = store.getState("plant-1", "machine-2");

    test:assertTrue(machineOneState is MachineState, msg = "machine-1 state should exist");
    test:assertTrue(machineTwoState is MachineState, msg = "machine-2 state should exist");

    if machineOneState is MachineState {
        VibrationReading? latestVibration = machineOneState.latestVibration;
        if latestVibration is VibrationReading {
            test:assertEquals(latestVibration.vibrationMm, 3.0d, msg = "machine-1 state should not be affected by machine-2 updates");
        }
    }
}

@test:Config {}
function testMachineStateStoreReturnsNilForUnknownMachine() {
    MachineStateStore store = new;
    MachineState? state = store.getState("plant-unknown", "machine-unknown");
    test:assertTrue(state is (), msg = "Unknown plant/machine combinations should have no recorded state");
}
