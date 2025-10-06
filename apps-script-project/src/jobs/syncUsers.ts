/**
 * @fileoverview Contains the job for syncing users (employees) from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { batchWriteToFirestore } from '../api/firestore_rest';
import { parseKiotVietDate } from '../core/date';

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

        syncedUser.createdDate = parseKiotVietDate(user.createdDate);
        syncedUser.birthDate = parseKiotVietDate(user.birthDate);
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