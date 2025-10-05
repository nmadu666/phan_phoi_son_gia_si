/**
 * @fileoverview Contains the job for syncing users (employees) from KiotViet to Firestore.
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
 * Fetches all users from the KiotViet API and syncs them to the 'kiotviet_users'
 * collection in Firestore.
 */
export function syncKiotVietUsersToFirestore() {
  const endpoint = '/users';
  const collectionName = 'kiotviet_users';
  Logger.log('Starting KiotViet Users to Firestore synchronization process.');

  try {
    const allUsers = fetchAllKiotVietData(endpoint);

    if (allUsers && allUsers.length > 0) {
      const usersToSync = allUsers.map(user => {
        const syncedUser: any = { ...user };

        const createdDate = parseKiotVietDate(user.createdDate);
        if (createdDate) syncedUser.createdDate = createdDate;

        const birthDate = parseKiotVietDate(user.birthDate);
        if (birthDate) syncedUser.birthDate = birthDate;

        return syncedUser;
      });

      batchWriteToFirestore(collectionName, usersToSync);
    } else {
      Logger.log('No users found to sync.');
    }
  } catch (e: any) {
    Logger.log(`An error occurred during the user sync process: ${e.toString()}\n${e.stack}`);
  }
}