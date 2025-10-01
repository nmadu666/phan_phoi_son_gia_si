/**
 * Creates and returns an authenticated Firestore instance.
 *
 * This function retrieves the service account credentials from Script Properties
 * and uses them to initialize the Firestore service.
 *
 * @returns {GoogleAppsScript.Firestore.Firestore} An authenticated Firestore instance from the FirestoreGoogleAppsScript library.
 */
function getFirestoreInstance() {
    const scriptProperties = PropertiesService.getScriptProperties();
    const clientEmail = scriptProperties.getProperty('firestore_client_email');
    const privateKey = scriptProperties.getProperty('firestore_private_key');
    const projectId = scriptProperties.getProperty('firestore_project_id');
    if (!clientEmail || !privateKey || !projectId) {
        throw new Error('Missing Firestore credentials (client_email, private_key, or project_id) in Script Properties.');
    }
    return FirestoreApp.getFirestore(clientEmail, privateKey, projectId);
}
