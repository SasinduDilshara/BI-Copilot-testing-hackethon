// Represents the customer's loyalty tier.
// Modeled as a string-literal union (instead of an Avro `enum` schema type) because the
// `ballerina/avro` module currently fails to serialize/deserialize record fields backed by an
// Avro `enum` schema. The wire format therefore encodes `customerTier` as an Avro `string`.
public const BRONZE = "BRONZE";
public const SILVER = "SILVER";
public const GOLD = "GOLD";
public const PLATINUM = "PLATINUM";

public type CustomerTier "BRONZE"|"SILVER"|"GOLD"|"PLATINUM";

# Represents a customer's postal address.
#
# + street - Street address
# + city - City name
# + postalCode - Postal or ZIP code
# + country - Country name
public type Address record {|
    string street;
    string city;
    string postalCode;
    string country;
|};

# Represents a customer profile that is synchronized over Kafka using Avro.
#
# + customerId - Unique identifier of the customer
# + email - Email address of the customer, nullable
# + address - Nested address record of the customer
# + loyaltyProgramIds - Array of loyalty program identifiers the customer is enrolled in
# + consentFlags - Map of consent flag name to its boolean value
# + customerTier - Loyalty tier of the customer
public type CustomerProfile record {|
    string customerId;
    string? email;
    Address address;
    string[] loyaltyProgramIds;
    map<boolean> consentFlags;
    CustomerTier customerTier;
|};

# Error raised when a `CustomerProfile` fails required business field validation prior to serialization.
public type ValidationError distinct error;

# Error raised when Avro serialization of a `CustomerProfile` fails.
public type SerializationError distinct error;

# Error raised when Avro deserialization of Kafka bytes into a `CustomerProfile` fails.
public type DeserializationError distinct error;

# Error raised when publishing serialized bytes to Kafka fails.
public type PublishError distinct error;

# Error raised when consuming messages from Kafka fails.
public type ConsumeError distinct error;
