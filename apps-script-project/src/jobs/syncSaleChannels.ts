/**
 * @fileoverview Contains the job for syncing sale channels from KiotViet to Firestore.
 */

import { fetchAllKiotVietData } from '../api/kiotviet';
import { batchWriteToFirestore } from '../api/firestore_rest';

/**
 * Fetches all sale channels from the KiotViet API and syncs them to the 'kiotviet_sale_channels'
 * collection in Firestore.
 */
export function syncKiotVietSaleChannelsToFirestore() {
  const endpoint = '/salechannel';
  const collectionName = 'kiotviet_sale_channels';
  Logger.log('Starting KiotViet Sale Channels to Firestore synchronization process.');

  try {
    const allSaleChannels = fetchAllKiotVietData(endpoint);

    if (allSaleChannels && allSaleChannels.length > 0) {
      batchWriteToFirestore(collectionName, allSaleChannels);
    } else {
      Logger.log('No sale channels found to sync.');
    }
  } catch (e: any) {
    Logger.log(`An error occurred during the sale channel sync process: ${e.toString()}\n${e.stack}`);
  }
}