/**
 * @fileoverview Contains the job for syncing customers from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { generateKeywordsFromText } from '../core/text';
import { batchWriteToFirestore } from '../api/firestore_rest';

/**
 * Parses a date string from KiotViet API format (e.g., "/Date(1609459200000+0700)/")
 * into a JavaScript Date object.
 * @param {string | null | undefined} kiotVietDate The date string from KiotViet.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
function parseKiotVietDate(kiotVietDate: string | null | undefined): Date | null {
  if (!kiotVietDate || typeof kiotVietDate !== 'string') {
    return null;
  }
  const match = kiotVietDate.match(/\/Date\((\d+).*\)\//);
  if (match && match[1]) {
    return new Date(parseInt(match[1], 10));
  }
  return null;
}

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
        const nameKeywords = generateKeywordsFromText(customer.name);
        const codeKeywords = generateKeywordsFromText(customer.code);
        const contactNumberKeywords = generateKeywordsFromText(customer.contactNumber);

        const allKeywords = new Set([
          ...nameKeywords,
          ...codeKeywords,
          ...contactNumberKeywords,
        ]);

        const syncedCustomer: any = {
          ...customer,
          search_keywords: Array.from(allKeywords),
        };

        // Only add date fields if they are valid
        const createdDate = parseKiotVietDate(customer.createdDate);
        if (createdDate) syncedCustomer.createdDate = createdDate;

        const birthDate = parseKiotVietDate(customer.birthDate);
        if (birthDate) syncedCustomer.birthDate = birthDate;
        
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