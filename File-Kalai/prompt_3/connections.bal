import ballerina/file;
import ballerina/log;
import ballerina/time;

const int MAX_AUDIT_EVENTS = 50;

isolated ConfigChangeEvent[] configChangeEvents = [];

isolated function addConfigChangeEvent(ConfigChangeEvent configChangeEvent) {
    lock {
        configChangeEvents.push(configChangeEvent.clone());
        if configChangeEvents.length() > MAX_AUDIT_EVENTS {
            _ = configChangeEvents.shift();
        }
    }
}

isolated function getConfigChangeEvents() returns ConfigChangeEvent[] {
    lock {
        return configChangeEvents.clone();
    }
}

listener file:Listener configDirectoryListener = new ({path: configBasePath, recursive: true});

service "configDirectoryWatcher" on configDirectoryListener {

    remote function onCreate(file:FileEvent fileEvent) returns error? {
        string detectedAt = time:utcToString(time:utcNow());
        log:printInfo("config file change detected", event = "config_changed", changeType = "created", filePath = fileEvent.name, detectedAt = detectedAt);
        addConfigChangeEvent({changeType: "created", filePath: fileEvent.name, detectedAt});
    }

    remote function onModify(file:FileEvent fileEvent) returns error? {
        string detectedAt = time:utcToString(time:utcNow());
        log:printInfo("config file change detected", event = "config_changed", changeType = "modified", filePath = fileEvent.name, detectedAt = detectedAt);
        addConfigChangeEvent({changeType: "modified", filePath: fileEvent.name, detectedAt});
    }

    remote function onDelete(file:FileEvent fileEvent) returns error? {
        string detectedAt = time:utcToString(time:utcNow());
        log:printInfo("config file change detected", event = "config_changed", changeType = "deleted", filePath = fileEvent.name, detectedAt = detectedAt);
        addConfigChangeEvent({changeType: "deleted", filePath: fileEvent.name, detectedAt});
    }
}
