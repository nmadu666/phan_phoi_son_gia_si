/**
 * @fileoverview Contains functions to fix data integrity issues in Firestore.
 */

import { batchWriteToFirestore } from '../api/firestore_rest';
import { getFirestoreProjectId } from '../core/config';
import { getServiceAccountOAuthToken_ } from '../api/firestore_rest';
import { parseKiotVietDate } from '../core/date';

/**
 * A utility function to find and fix documents in a specific collection
 * where date fields are stored as strings instead of Timestamps.
 *
 * @param {string} collectionName The name of the Firestore collection to scan.
 * @param {string[]} dateFields An array of field names that should be dates.
 */
function fixDateFieldsInCollection(collectionName: string, dateFields: string[]): void {
  const projectId = getFirestoreProjectId();
  const token = getServiceAccountOAuthToken_();
  let nextPageToken: string | undefined = undefined;
  const pageSize = 300; // Process 300 docs per page to stay within limits
  let documentsToUpdate: any[] = [];
  let totalDocsScanned = 0;

  Logger.log(`Starting to fix date fields for collection: '${collectionName}'...`);

  do {
    let url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionName}?pageSize=${pageSize}`;
    if (nextPageToken) {
      url += `&pageToken=${nextPageToken}`;
    }

    const options: GoogleAppsScript.URL_Fetch.URLFetchRequestOptions = {
      method: 'get',
      contentType: 'application/json',
      headers: { Authorization: `Bearer ${token}` },
      muteHttpExceptions: true,
    };

    const response = UrlFetchApp.fetch(url, options);
    const responseData = JSON.parse(response.getContentText());

    const documents = responseData.documents;
    if (documents && documents.length > 0) {
      totalDocsScanned += documents.length;
      Logger.log(`Scanning page of ${documents.length} documents... (Total scanned: ${totalDocsScanned})`);

      documents.forEach((doc: any) => {
        const docId = doc.name.split('/').pop();
        let needsUpdate = false;
        const updatePayload: { [key: string]: any } = { id: docId };

        for (const field of dateFields) {
          const fieldValue = doc.fields?.[field]?.stringValue;

          // Check if the field exists and is a string (indicating it's an incorrect date format)
          if (typeof fieldValue === 'string') {
            const parsedDate = parseKiotVietDate(fieldValue);
            // We update if it's a valid KiotViet date string, or set to null if it's some other invalid string
            if (parsedDate) {
              Logger.log(`Found invalid date in doc '${docId}', field '${field}'. Fixing value: ${fieldValue}`);
              updatePayload[field] = parsedDate;
              needsUpdate = true;
            } else {
               // Optional: handle cases where the string is not a KiotViet date, e.g., set to null
               // updatePayload[field] = null;
               // needsUpdate = true;
            }
          }
        }

        if (needsUpdate) {
          documentsToUpdate.push(updatePayload);
        }
      });
    }

    nextPageToken = responseData.nextPageToken;
  } while (nextPageToken);

  if (documentsToUpdate.length > 0) {
    Logger.log(`Found ${documentsToUpdate.length} documents to update in '${collectionName}'.`);
    // Using merge=true to only update the specified date fields
    batchWriteToFirestore(collectionName, documentsToUpdate, true); // Use merge=true
  } else {
    Logger.log(`No documents with incorrect date formats found in '${collectionName}'.`);
  }
}

/**
 * Main function to be run from the Apps Script Editor.
 * This will scan all relevant collections and fix any date fields
 * that were incorrectly stored as strings.
 */
export function fixIncorrectDateFormatsInFirestore() {
  try {
    Logger.log('--- Starting Data Fix Process ---');
    const collectionsToFix = {
      'kiotviet_products': ['createdDate', 'modifiedDate'],
      'kiotviet_customers': ['createdDate', 'birthDate'],
      'kiotviet_users': ['createdDate', 'birthDate'],
      'kiotviet_branches': ['createdDate', 'modifiedDate'],
    };

    for (const collectionName in collectionsToFix) {
      fixDateFieldsInCollection(collectionName, collectionsToFix[collectionName]);
    }
    Logger.log('--- Data Fix Process Finished ---');
  } catch (e: any) {
    Logger.log(`An error occurred during the data fix process: ${e.toString()}\n${e.stack}`);
  }
}
