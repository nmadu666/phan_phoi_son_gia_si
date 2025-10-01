/**
 * @fileoverview This is the main execution file for the project.
 * It contains the primary function(s) that will be run from the Apps Script editor.
 */
/**
 * Fetches all products from the KiotViet API and syncs them to the 'products'
 * collection in Firestore using a true batch write operation.
 *
 * This function relies on helpers defined in `helpers.ts`.
 *
 * Required Script Properties:
 * - firestore_project_id: Your Google Cloud / Firebase project ID.
 * - firestore_client_email: The client email from your Google Cloud service account JSON key.
 * - firestore_private_key: The private key from your Google Cloud service account JSON key.
 * - kiotviet_client_id: The Client ID for your KiotViet application.
 * - kiotviet_client_secret: The Client Secret for your KiotViet application.
 * - kiotviet_retailer: The retailer name for your KiotViet account.
 */
function syncKiotVietProductsToFirestore() {
    var endpoint = '/products';
    var collectionName = 'kiotviet_products';
    Logger.log('Starting KiotViet to Firestore synchronization process.');
    try {
        // Step 1: Fetch all product data from KiotViet
        Logger.log("Fetching all data from KiotViet endpoint: ".concat(endpoint));
        var allProducts = fetchAllKiotVietData(endpoint);
        if (allProducts && allProducts.length > 0) {
            // Step 2: Write the data to Firestore in batches
            Logger.log("Fetched ".concat(allProducts.length, " products. Starting batch write to Firestore collection: ").concat(collectionName));
            batchWriteToFirestore(collectionName, allProducts);
            Logger.log('Successfully completed synchronization.');
            showToast('Sync Complete!', "Successfully synced ".concat(allProducts.length, " products to Firestore."));
        }
        else {
            Logger.log('No products found to sync.');
            showToast('Sync Complete', 'No new products to sync.');
        }
    }
    catch (e) {
        Logger.log("An error occurred during the sync process: ".concat(e.toString(), "\n").concat(e.stack));
        showToast('Sync Failed', "Error: ".concat(e.message));
    }
}
