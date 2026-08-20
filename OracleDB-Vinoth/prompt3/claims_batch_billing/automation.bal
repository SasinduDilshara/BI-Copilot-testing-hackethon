
import ballerina/log;

public function main() returns error? {
    do {
        check ensureClaimLineConstraintsExist();

        string? nextPageToken = ();
        boolean hasMorePages = true;
        while hasMorePages {
            string pendingLinesPath = nextPageToken is string
                ? string `/claims/pending-lines?pageToken=${nextPageToken}`
                : "/claims/pending-lines";
            PendingClaimLinesPage page = check clearinghouseClient->get(pendingLinesPath);
            check insertClaimLineBatch(page.items);

            nextPageToken = page.nextPageToken;
            hasMorePages = nextPageToken is string;
        }
    } on fail error e {
        log:printError("Claims batch billing run failed", 'error = e);
    }
}