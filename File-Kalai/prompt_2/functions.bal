import ballerina/file;

// Recursively collects the names of all files (not directories) inside the given directory,
// and adds up the size in bytes of every file encountered (including files in subdirectories).
function collectDirContents(string dirPath, string[] fileNames) returns int|file:Error {
    file:MetaData[]&readonly entries = check file:readDir(dirPath);
    int totalSizeBytes = 0;

    foreach file:MetaData entry in entries {
        string entryAbsPath = entry.absPath;
        if entry.dir {
            int subDirSizeBytes = check collectDirContents(entryAbsPath, fileNames);
            totalSizeBytes += subDirSizeBytes;
        } else {
            string[] pathParts = re `[/\\]`.split(entryAbsPath);
            string entryName = pathParts[pathParts.length() - 1];
            fileNames.push(entryName);
            totalSizeBytes += entry.size;
        }
    }

    return totalSizeBytes;
}
