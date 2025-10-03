/**
 * @fileoverview Contains the job for syncing products from KiotViet to Firestore.
 */
import { fetchAllKiotVietData } from '../api/kiotviet';
import { generateKeywordsFromText } from '../core/text';
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
        const nameKeywords = generateKeywordsFromText(product.name);
        const codeKeywords = generateKeywordsFromText(product.code);

        // Combine keywords from name and code, ensuring uniqueness
        const allKeywords = new Set([...nameKeywords, ...codeKeywords]);

        return { ...product, search_keywords: Array.from(allKeywords) };
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
