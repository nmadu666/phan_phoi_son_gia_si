/**
 * @fileoverview Contains the job for syncing price books and their details from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { batchWriteToFirestore } from '../api/firestore_rest';
import { parseKiotVietDate } from '../core/date';

/**
 * Fetches all price books from the KiotViet API and syncs them to the 'kiotviet_pricebooks'
 * collection in Firestore. For each price book, it also fetches all associated product
 * prices and syncs them to a 'details' subcollection.
 */
export function syncKiotVietPriceBooksToFirestore() {
  const mainEndpoint = '/pricebooks';
  const mainCollectionName = 'kiotviet_pricebooks';

  Logger.log(
    'Starting KiotViet Price Books to Firestore synchronization process.'
  );

  try {
    // Step 1: Fetch all price books (main data)
    const allPriceBooks = fetchAllKiotVietData(mainEndpoint);

    if (!allPriceBooks || allPriceBooks.length === 0) {
      Logger.log('No price books found to sync.');
      return;
    }

    // Step 2: Map and prepare main price book data for Firestore
    const priceBooksToSync = allPriceBooks.map(pb => {
      const syncedPriceBook: { [key: string]: any } = { ...pb };

      // Parse date fields to ensure they are stored as Timestamps
      syncedPriceBook.startDate = parseKiotVietDate(pb.startDate);
      syncedPriceBook.endDate = parseKiotVietDate(pb.endDate);

      // Remove fields that are not needed or will be in subcollections
      delete syncedPriceBook.priceBookBranches;
      delete syncedPriceBook.priceBookCustomerGroups;
      delete syncedPriceBook.priceBookUsers;

      return syncedPriceBook;
    });

    // Step 3: Write the main price book data to Firestore
    batchWriteToFirestore(mainCollectionName, priceBooksToSync);
    Logger.log(
      `Successfully synced ${priceBooksToSync.length} main price book documents.`
    );

    // Step 4: For each price book, fetch its details and sync to a subcollection
    allPriceBooks.forEach(priceBook => {
      const priceBookId = priceBook.id;
      const detailsEndpoint = `/pricebooks/${priceBookId}`;
      const detailsCollectionName = `${mainCollectionName}/${priceBookId}/details`;

      Logger.log(
        `Fetching details for Price Book ID: ${priceBookId} from endpoint: ${detailsEndpoint}`
      );

      // The details endpoint returns a flat array of all product prices, not paginated in the same way.
      // We assume `fetchAllKiotVietData` can handle this structure as well.
      const priceBookDetails = fetchAllKiotVietData(detailsEndpoint);

      if (priceBookDetails && priceBookDetails.length > 0) {
        // The detail items don't have a unique 'id' field, but 'productId' is unique per price book.
        // We'll map 'productId' to 'id' for `batchWriteToFirestore` to use as the document ID.
        const detailsToSync = priceBookDetails.map(detail => ({
          ...detail,
          id: detail.productId, // Use productId as the document ID
        }));

        batchWriteToFirestore(detailsCollectionName, detailsToSync);
      }
    });
  } catch (e: any) {
    Logger.log(`An error occurred during the price book sync process: ${e.toString()}\n${e.stack}`);
  }
}
