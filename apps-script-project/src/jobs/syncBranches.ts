/**
 * @fileoverview Contains the job for syncing branches from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
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
 * Fetches all branches from the KiotViet API and syncs them to the 'kiotviet_branches'
 * collection in Firestore.
 */
export function syncKiotVietBranchesToFirestore() {
  const endpoint = '/branches';
  const collectionName = 'kiotviet_branches';
  Logger.log('Starting KiotViet Branches to Firestore synchronization process.');

  try {
    const allBranches = fetchAllKiotVietData(endpoint);

    if (allBranches && allBranches.length > 0) {
      const branchesToSync = allBranches.map(branch => ({
        ...branch,
        createdDate: parseKiotVietDate(branch.createdDate),
        modifiedDate: parseKiotVietDate(branch.modifiedDate),
      }));
      batchWriteToFirestore(collectionName, branchesToSync);
    } else {
      Logger.log('No branches found to sync.');
    }
  } catch (e: any) {
    Logger.log(`An error occurred during the branch sync process: ${e.toString()}\n${e.stack}`);
  }
}