public function main() returns error? {
    check ensureShareExists();

    string archiveRootPath = check buildArchiveRootPath();
    UploadManifest manifest = check archiveReportsDirectory(localReportsDirectory, archiveRootPath);
    printManifest(manifest);
}
