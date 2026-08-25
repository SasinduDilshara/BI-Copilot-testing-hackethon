import ballerina/cache;
import ballerina/http;

service /products on new http:Listener(servicePort) {

    // Fetches a product by its identifier, serving from cache when available.
    resource function get [string productId]() returns ProductResponse|http:NotFound|http:InternalServerError {
        boolean isCached = productCache.hasKey(productId);
        if isCached {
            any|cache:Error cachedValue = productCache.get(productId);
            if cachedValue is cache:Error {
                return <http:InternalServerError>{
                    body: {message: "Failed to read product from cache: " + cachedValue.message()}
                };
            }
            Product cachedProduct = <Product>cachedValue;
            ProductResponse cachedResponse = {...cachedProduct, cacheHit: true};
            return cachedResponse;
        }

        Product? product = productDatabase[productId];
        if product is () {
            return <http:NotFound>{
                body: {message: "Product not found: " + productId}
            };
        }

        cache:Error? putResult = productCache.put(productId, product);
        if putResult is cache:Error {
            return <http:InternalServerError>{
                body: {message: "Failed to store product in cache: " + putResult.message()}
            };
        }

        ProductResponse freshResponse = {...product, cacheHit: false};
        return freshResponse;
    }
}
