/**
 * @fileoverview Contains the job for syncing branches from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { batchWriteToFirestore } from '../api/firestore_rest';
import { parseKiotVietDate } from '../core/date';

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
      const branchesToSync = allBranches.map(branch => {
        const syncedBranch: any = { ...branch };
        syncedBranch.createdDate = parseKiotVietDate(branch.createdDate);
        syncedBranch.modifiedDate = parseKiotVietDate(branch.modifiedDate);
        return syncedBranch;
      });
      batchWriteToFirestore(collectionName, branchesToSync);
    } else {
      Logger.log('No branches found to sync.');
    }
  } catch (e: any) {
    Logger.log(`An error occurred during the branch sync process: ${e.toString()}\n${e.stack}`);
  }
}