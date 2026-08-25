// Represents a product entity.
public type Product record {|
    string productId;
    string name;
    string category;
    decimal price;
    int stockCount;
    string lastUpdated;
|};

// Response returned by the product endpoint, including cache status.
public type ProductResponse record {|
    *Product;
    boolean cacheHit;
|};

// Fields accepted when updating an existing product.
public type ProductUpdateRequest record {|
    string name;
    decimal price;
    int stockCount;
|};

// Response returned when the entire cache is flushed.
public type CacheFlushResponse record {|
    string flushedAt;
    int flushedEntryCount;
|};

// Cache health statistics used for monitoring.
public type CacheStats record {|
    int currentSize;
    int maxCapacity;
    string[] cachedKeys;
    decimal utilizationPercent;
|};
