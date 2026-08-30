// Bounded, insertion-ordered buffer of alerts pending publish to
// `iot.alerts`. Decouples alert publishing from the ingestion/aggregation
// path: enqueue never blocks or fails, so a slow or failing publish for one
// device's alerts never stalls processing for unrelated devices. Once the
// buffer is at capacity, the oldest pending alert is dropped to make room for
// the newest, and the drop is counted. All state is guarded by this class's
// own lock.
public isolated class BoundedAlertBuffer {
    private final int capacity;
    private TelemetryAlert[] pendingAlerts = [];
    private int droppedCount = 0;

    public isolated function init(int capacity) {
        self.capacity = capacity;
    }

    // Adds an alert to the buffer, dropping the oldest pending alert first if
    // the buffer is already at capacity.
    public isolated function enqueue(TelemetryAlert telemetryAlert) {
        lock {
            self.pendingAlerts.push(telemetryAlert.clone());
            if self.pendingAlerts.length() > self.capacity {
                _ = self.pendingAlerts.shift();
                self.droppedCount += 1;
            }
        }
    }

    // Removes and returns every alert currently buffered, leaving the buffer
    // empty.
    public isolated function dequeueAll() returns TelemetryAlert[] {
        TelemetryAlert[] & readonly drainedAlerts;
        lock {
            drainedAlerts = self.pendingAlerts.cloneReadOnly();
            self.pendingAlerts = [];
        }
        return drainedAlerts.clone();
    }

    // Reports the current buffer occupancy, its capacity, and the total
    // number of alerts dropped since startup.
    public isolated function getHealth() returns AlertBufferHealth {
        lock {
            return {
                droppedCount: self.droppedCount,
                currentSize: self.pendingAlerts.length(),
                capacity: self.capacity
            };
        }
    }
}
