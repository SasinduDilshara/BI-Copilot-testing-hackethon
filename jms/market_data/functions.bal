import ballerinax/java.jms;

// Tracks whether the market-data consumer service is currently attached to the listener, so
// pause/resume requests are idempotent.
isolated class ConsumerState {
    private boolean attached = true;

    isolated function markDetached() {
        lock {
            self.attached = false;
        }
    }

    isolated function markAttached() {
        lock {
            self.attached = true;
        }
    }

    isolated function isAttached() returns boolean {
        lock {
            return self.attached;
        }
    }
}

final ConsumerState consumerState = new;

// Tracks a running count of ticks processed per instrument class, exposed via GET /marketdata/stats.
isolated class TickCounter {
    private final map<int> countsByInstrumentClass = {};

    isolated function increment(string instrumentClass) {
        lock {
            int currentCount = self.countsByInstrumentClass[instrumentClass] ?: 0;
            self.countsByInstrumentClass[instrumentClass] = currentCount + 1;
        }
    }

    isolated function snapshot() returns InstrumentClassTickCount[] {
        map<int> countsSnapshot;
        lock {
            countsSnapshot = self.countsByInstrumentClass.clone();
        }
        return from string instrumentClass in countsSnapshot.keys()
            select {
                instrumentClass,
                tickCount: countsSnapshot.get(instrumentClass)
            };
    }
}

final TickCounter tickCounter = new;

// Republishes a price tick to MARKET.DATA.NORMALISED as a map message.
function publishNormalisedTick(PriceTick priceTick) returns error? {
    jms:MapMessage mapMessage = {
        content: toNormalisedTickContent(priceTick),
        priority: normalisedTickPriority
    };
    check normalisedTickProducer->send(mapMessage);
}
