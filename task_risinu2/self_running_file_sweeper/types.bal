// Outcome of attempting to process a single file during a sweep.
public type FileProcessResult record {|
    string fileName;
    int dataRowCount;
|};
