/**
 * @fileoverview This is the main entry point for the Webpack bundle.
 * All functions that need to be globally available in the Google Apps Script
 * environment should be assigned to the `global` object.
 */

import { refreshKiotVietAccessToken } from './api/kiotviet';
import { syncKiotVietProductsToFirestore } from './jobs/syncProducts';
import { setScriptProperty } from './core/properties';

/**
 * ===============================================================================
 * ONE-TIME MANUAL SETUP FUNCTION
 * ===============================================================================
 * To configure the script, follow these steps:
 * 1. Fill in your secret values in the `propertiesToSet` object below.
 * 2. Deploy your code (`npm run deploy`).
 * 3. In the Google Apps Script editor, select this function (`_MANUAL_SETUP_`) and run it ONCE.
 * 4. (Recommended) After running it successfully, delete your secret values from the code below for security.
 */
function _MANUAL_SETUP_() {
  const propertiesToSet = {
    kiotviet_client_id: 'YOUR_CLIENT_ID_HERE', // <--- FILL IN
    kiotviet_client_secret: 'YOUR_CLIENT_SECRET_HERE', // <--- FILL IN
    kiotviet_retailer: 'YOUR_RETAILER_HERE', // <--- FILL IN
    firestore_client_email: 'YOUR_FIREBASE_CLIENT_EMAIL_HERE', // <--- FILL IN
    firestore_private_key: '-----BEGIN PRIVATE KEY-----\nYOUR_FIREBASE_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----', // <--- FILL IN
    firestore_project_id: 'YOUR_FIREBASE_PROJECT_ID_HERE', // <--- FILL IN
  };

  for (const [key, value] of Object.entries(propertiesToSet)) {
    if (value.includes('YOUR_')) {
      Logger.log(`WARNING: Property "${key}" still contains a placeholder value. It was NOT set.`);
    } else {
      setScriptProperty(key, value);
      Logger.log(`Property "${key}" was set successfully.`);
    }
  }
  Logger.log('Manual setup complete. Please remove your secrets from the `_MANUAL_SETUP_` function.');
}


// --- Assign functions to the global object ---
// This makes them visible and runnable in the Google Apps Script editor.

// Expose the setup function
(global as any)._MANUAL_SETUP_ = _MANUAL_SETUP_;

// Expose the function to manually refresh the KiotViet access token
(global as any).refreshKiotVietAccessToken = refreshKiotVietAccessToken;

// Expose the main job for syncing products
(global as any).syncKiotVietProductsToFirestore = syncKiotVietProductsToFirestore;