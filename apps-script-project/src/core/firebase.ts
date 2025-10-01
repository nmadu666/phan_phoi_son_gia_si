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

/**
 * Creates and returns an authenticated Firestore instance.
 *
 * This function retrieves the service account credentials from Script Properties
 * and uses them to initialize the Firestore service.
 *
 * @returns {GoogleAppsScript.Firestore.Firestore} An authenticated Firestore instance from the FirestoreGoogleAppsScript library.
 */
export function getFirestoreInstance(): Firestore {
  const scriptProperties = PropertiesService.getScriptProperties();
  const clientEmail = scriptProperties.getProperty('firestore_client_email');
  const privateKey = scriptProperties.getProperty('firestore_private_key');
  const projectId = scriptProperties.getProperty('firestore_project_id');

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error('Missing Firestore credentials (client_email, private_key, or project_id) in Script Properties.');
  }

  return FirestoreApp.getFirestore(clientEmail, privateKey, projectId);
}
