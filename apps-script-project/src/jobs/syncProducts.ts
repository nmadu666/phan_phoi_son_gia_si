/**
 * @fileoverview Contains the job for syncing products from KiotViet to Firestore.
 */
import { fetchAllKiotVietData } from '../api/kiotviet';
import { generateSearchables } from '../core/text';
import { parseKiotVietDate } from '../core/date';
import { batchWriteToFirestore } from '../api/firestore_rest';

/**
 * Fetches all products from the KiotViet API and syncs them to the 'kiotviet_products'
 * collection in Firestore, enriching them with search keywords.
 */
export function syncKiotVietProductsToFirestore(): void {
  const endpoint = '/products';
  const collectionName = 'kiotviet_products';

  Logger.log('Starting KiotViet to Firestore synchronization process.');

  try {
    // Step 1: Fetch all product data from KiotViet
    Logger.log(`Fetching all data from KiotViet endpoint: ${endpoint}`);
    const allProducts = fetchAllKiotVietData(endpoint);

    if (allProducts && allProducts.length > 0) {
      // Step 2: Enrich products with the search_keywords field
      const productsWithKeywords = allProducts.map(product => {
        const syncedProduct: any = { ...product };

        const nameSearchables = generateSearchables(product.name);
        const codeSearchables = generateSearchables(product.code);

        // Combine keywords and prefixes, ensuring uniqueness
        syncedProduct.search_keywords = Array.from(new Set([...nameSearchables.keywords, ...codeSearchables.keywords]));
        syncedProduct.search_prefixes = Array.from(new Set([...nameSearchables.prefixes, ...codeSearchables.prefixes]));

        // Parse date fields to ensure they are stored as Timestamps
        syncedProduct.createdDate = parseKiotVietDate(product.createdDate);
        syncedProduct.modifiedDate = parseKiotVietDate(product.modifiedDate);

        return syncedProduct;
      });

      // Step 3: Write the data to Firestore in batches
      Logger.log(
        `Fetched ${productsWithKeywords.length} products. Starting batch write to Firestore collection: ${collectionName}`
      );
      batchWriteToFirestore(collectionName, productsWithKeywords);
      Logger.log('Successfully completed synchronization.');
    } else {
      Logger.log('No products found to sync.');
    }
  } catch (e: any) {
    Logger.log(
      `An error occurred during the sync process: ${e.toString()}\n${e.stack}`
    );
  }
}
