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
