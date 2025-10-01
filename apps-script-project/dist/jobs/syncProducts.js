/**
 * Fetches all products from the KiotViet API and syncs them to the 'kiotviet_products'
 * collection in Firestore, enriching them with search keywords.
 */
function syncKiotVietProductsToFirestore() {
    const endpoint = '/products';
    const collectionName = 'kiotviet_products';
    Logger.log('Starting KiotViet to Firestore synchronization process.');
    try {
        // Step 1: Fetch all product data from KiotViet
        Logger.log(`Fetching all data from KiotViet endpoint: ${endpoint}`);
        const allProducts = (0, kiotviet_1.fetchAllKiotVietData)(endpoint);
        if (allProducts && allProducts.length > 0) {
            // Step 2: Enrich products with the search_keywords field
            const productsWithKeywords = allProducts.map(product => {
                const nameKeywords = (0, text_1.generateKeywordsFromText)(product.name);
                const codeKeywords = (0, text_1.generateKeywordsFromText)(product.code);
                // Combine keywords from name and code, ensuring uniqueness
                const allKeywords = new Set([...nameKeywords, ...codeKeywords]);
                return { ...product, search_keywords: Array.from(allKeywords) };
            });
            // Step 3: Write the data to Firestore in batches
            Logger.log(`Fetched ${productsWithKeywords.length} products. Starting batch write to Firestore collection: ${collectionName}`);
            (0, firestore_rest_1.batchWriteToFirestore)(collectionName, productsWithKeywords);
            Logger.log('Successfully completed synchronization.');
            (0, ui_1.showToast)('Sync Complete!', `Successfully synced ${productsWithKeywords.length} products to Firestore.`);
        }
        else {
            Logger.log('No products found to sync.');
            (0, ui_1.showToast)('Sync Complete', 'No new products to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the sync process: ${e.toString()}\n${e.stack}`);
        (0, ui_1.showToast)('Sync Failed', `Error: ${e.message}`);
    }
}
