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
