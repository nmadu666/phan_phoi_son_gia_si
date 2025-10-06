/**
 * @fileoverview Contains the job for syncing customers from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { generateSearchables } from '../core/text';
import { parseKiotVietDate } from '../core/date';
import { batchWriteToFirestore } from '../api/firestore_rest';

/**
 * Fetches all customers from the KiotViet API and syncs them to the 'kiotviet_customers'
 * collection in Firestore, enriching them with search keywords.
 */
export function syncKiotVietCustomersToFirestore() {
  const endpoint = '/customers';
  const collectionName = 'kiotviet_customers';
  Logger.log('Starting KiotViet Customers to Firestore synchronization process.');

  try {
    const allCustomers = fetchAllKiotVietData(endpoint);

    if (allCustomers && allCustomers.length > 0) {
      const customersToSync = allCustomers.map(customer => {
        const nameSearchables = generateSearchables(customer.name);
        const codeSearchables = generateSearchables(customer.code);
        const contactNumberSearchables = generateSearchables(customer.contactNumber);

        const allKeywords = new Set([...nameSearchables.keywords, ...codeSearchables.keywords, ...contactNumberSearchables.keywords]);
        const allPrefixes = new Set([...nameSearchables.prefixes, ...codeSearchables.prefixes, ...contactNumberSearchables.prefixes]);

        const syncedCustomer: any = {
          ...customer,
          search_keywords: Array.from(allKeywords),
          search_prefixes: Array.from(allPrefixes),
        };

        // Only add date fields if they are valid
        syncedCustomer.createdDate = parseKiotVietDate(customer.createdDate);
        syncedCustomer.birthDate = parseKiotVietDate(customer.birthDate);
        return syncedCustomer;
      });

      batchWriteToFirestore(collectionName, customersToSync);
    } else {
      Logger.log('No customers found to sync.');
    }
  } catch (e: any) {
    Logger.log(`An error occurred during the customer sync process: ${e.toString()}\n${e.stack}`);
  }
}