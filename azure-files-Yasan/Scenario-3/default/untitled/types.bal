// Represents a single file uploaded to the archive, as reported in the manifest.
type UploadedFileEntry record {|
    string sharePath;
    int sizeInBytes;
|};

// Summary manifest produced after archiving the local reports directory.
type UploadManifest record {|
    UploadedFileEntry[] uploadedFiles;
    int totalFiles;
    int totalBytes;
|};

// Represents a single dated archive directory that was pruned during retention cleanup.
type PrunedArchiveEntry record {|
    string archiveDate;
    int fileCount;
|};

// Summary report produced after applying the retention policy to the archive.
type RetentionReport record {|
    PrunedArchiveEntry[] prunedArchives;
|};
