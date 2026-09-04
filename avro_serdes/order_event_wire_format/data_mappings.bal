// Avro schema definition for the CustomerProfile record, matching the `CustomerProfile` Ballerina type.
// - customerId: required string
// - email: nullable string (union with null)
// - address: nested Address record
// - loyaltyProgramIds: array of strings
// - consentFlags: map of boolean values
// - customerTier: string, constrained on the Ballerina side to the `CustomerTier` union
//   (BRONZE | SILVER | GOLD | PLATINUM). An Avro `enum` schema type is intentionally avoided here
//   since the `ballerina/avro` module does not yet correctly round-trip enum-typed fields.
final string & readonly customerProfileAvroSchema = string `
{
    "type": "record",
    "name": "CustomerProfile",
    "namespace": "customer.profile.avro",
    "fields": [
        {"name": "customerId", "type": "string"},
        {"name": "email", "type": ["null", "string"], "default": null},
        {"name": "address", "type": {
            "type": "record",
            "name": "Address",
            "fields": [
                {"name": "street", "type": "string"},
                {"name": "city", "type": "string"},
                {"name": "postalCode", "type": "string"},
                {"name": "country", "type": "string"}
            ]
        }},
        {"name": "loyaltyProgramIds", "type": {"type": "array", "items": "string"}},
        {"name": "consentFlags", "type": {"type": "map", "values": "boolean"}},
        {"name": "customerTier", "type": "string"}
    ]
}`;
