/**
 * @fileoverview This file contains functions for initializing and interacting with Google Firestore.
 * It relies on the 'FirestoreGoogleAppsScript' library.
 *
 * To use this, you must add the 'FirestoreGoogleAppsScript' library to your project:
 * 1. In the Apps Script editor, click 'Libraries +'.
 * 2. In the 'Add a library' dialog, enter the following script ID:
 *    1VUSl4b1r1eoNcRWotZM3e87ygkxBvKHleYjMvt2vsdmgT5dypcby_m-s
 * 3. Click 'Look up', select the latest version, and set the identifier to 'FirestoreApp'.
 * 4. Click 'Add'.
 */
import {
  getFirestoreClientEmail,
  getFirestorePrivateKey,
  getFirestoreProjectId,
} from './config';

/**
 * Creates and returns an authenticated Firestore instance.
 *
 * This function retrieves the service account credentials from Script Properties
 * and uses them to initialize the Firestore service.
 *
 * @returns {GoogleAppsScript.Firestore.Firestore} An authenticated Firestore instance from the FirestoreGoogleAppsScript library.
 */
export function getFirestoreInstance(): Firestore {
  return FirestoreApp.getFirestore(
    getFirestoreClientEmail(),
    getFirestorePrivateKey(),
    getFirestoreProjectId()
  );
}
