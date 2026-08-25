import ballerina/cache;
import ballerina/http;
import ballerina/time;

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

    // Updates a product in the simulated database and invalidates its cached entry.
    resource function put [string productId](ProductUpdateRequest productUpdateRequest) returns Product|http:NotFound|http:InternalServerError {
        Product? existingProduct = productDatabase[productId];
        if existingProduct is () {
            return <http:NotFound>{
                body: {message: "Product not found: " + productId}
            };
        }

        time:Utc currentUtc = time:utcNow();
        string currentTimestamp = time:utcToString(currentUtc);
        Product updatedProduct = {
            productId: productId,
            name: productUpdateRequest.name,
            category: existingProduct.category,
            price: productUpdateRequest.price,
            stockCount: productUpdateRequest.stockCount,
            lastUpdated: currentTimestamp
        };
        productDatabase[productId] = updatedProduct;

        cache:Error? invalidateResult = productCache.invalidate(productId);
        if invalidateResult is cache:Error {
            return <http:InternalServerError>{
                body: {message: "Failed to invalidate cache entry: " + invalidateResult.message()}
            };
        }

        return updatedProduct;
    }

    // Flushes the entire product cache.
    resource function delete cache() returns CacheFlushResponse|http:InternalServerError {
        int entryCountBeforeFlush = productCache.size();

        cache:Error? invalidateAllResult = productCache.invalidateAll();
        if invalidateAllResult is cache:Error {
            return <http:InternalServerError>{
                body: {message: "Failed to flush cache: " + invalidateAllResult.message()}
            };
        }

        time:Utc currentUtc = time:utcNow();
        CacheFlushResponse flushResponse = {
            flushedAt: time:utcToString(currentUtc),
            flushedEntryCount: entryCountBeforeFlush
        };
        return flushResponse;
    }
}
