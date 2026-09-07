// Outcome of attempting to process a single file during a sweep.
public type FileProcessResult record {|
    string fileName;
    int dataRowCount;
|};

// Running totals of files processed and failed since the sweeper started up.
public type SweepCounters record {|
    int processedCount;
    int failedCount;
|};
