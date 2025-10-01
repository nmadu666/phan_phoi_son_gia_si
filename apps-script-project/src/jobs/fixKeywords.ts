/**
 * @fileoverview Contains the one-time job for adding search keywords to existing products.
 */
import { getFirestoreInstance } from '../core/firebase';
import { generateKeywordsFromText } from '../core/text';
import { showToast } from '../core/ui';

/**
 * Updates all documents in the 'kiotviet_products' collection to include
 * a 'search_keywords' field. This function should be run manually from the 
 * Apps Script editor when needed.
 */
export function addSearchKeywordsToProducts(): void {
  const collectionName = 'kiotviet_products';
  const batchSize = 400; // Firestore batch writes are limited to 500 operations.

  Logger.log(`Starting to add 'search_keywords' to collection: '${collectionName}'`);

  try {
    const firestore = getFirestoreInstance();
    const allDocs = firestore.getDocuments(collectionName);

    if (!allDocs || allDocs.length === 0) {
      Logger.log('No documents found in the collection. Nothing to do.');
      return;
    }

    Logger.log(`Found ${allDocs.length} documents to process.`);

    for (let i = 0; i < allDocs.length; i += batchSize) {
      const batch = firestore.batch();
      const end = Math.min(i + batchSize, allDocs.length);
      Logger.log(`Processing batch: documents ${i + 1} to ${end}`);

      for (let j = i; j < end; j++) {
        const doc = allDocs[j];
        const productData = doc.obj;
        const docPath = `${collectionName}/${doc.name.split('/').pop()}`;

        const nameKeywords = generateKeywordsFromText(productData.name);
        const codeKeywords = generateKeywordsFromText(productData.code);

        // Combine keywords from name and code, ensuring uniqueness
        const allKeywords = new Set([...nameKeywords, ...codeKeywords]);

        // Update the document with the new array of keywords
        batch.update(docPath, { search_keywords: Array.from(allKeywords) });
      }

      // Commit the batch
      batch.commit();
    }

    Logger.log('Successfully updated all documents with search_keywords.');
    showToast('Fix Complete!', `Updated ${allDocs.length} products.`);
  } catch (e: any) {
    Logger.log(`An error occurred during the fix process: ${e.toString()}\n${e.stack}`);
    showToast('Fix Failed', `Error: ${e.message}`);
  }
}
