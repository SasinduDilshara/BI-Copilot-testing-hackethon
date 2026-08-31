import ballerina/test;

// isCityServed should return true only for cities present in the configured servedCities list.

@test:Config {}
function testIsCityServedReturnsTrueForServedCity() {
    boolean result = isCityServed("colombo");
    test:assertTrue(result, msg = "Expected 'colombo' to be a served city");
}

@test:Config {}
function testIsCityServedReturnsFalseForUnservedCity() {
    boolean result = isCityServed("jaffna");
    test:assertFalse(result, msg = "Expected 'jaffna' to be reported as not served");
}

@test:Config {}
function testIsCityServedIsCaseSensitive() {
    boolean result = isCityServed("Colombo");
    test:assertFalse(result, msg = "Expected city matching to be case-sensitive");
}
