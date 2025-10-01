
/**
 * @fileoverview Contains common, reusable logic functions for the entire project.
 */

// ===============================================================
// INTERFACES AND TYPES
// ===============================================================

/** Configuration object for the syncKiotVietDataStreamed function. */
interface SyncStreamConfig {
  sheetName: string;
  collectionName: string;
  endpoint: string;
  headers: string[];
  dataMapper?: (item: any, existingData: { [id: string]: any }) => any;
}

/** Represents a document to be patched in Firestore. */
interface FirestorePatchDocument {
  id: string;
  fields: { [key: string]: any };
}

// ===============================================================
// UI HELPER
// ===============================================================

/**
 * Safely displays a toast notification if the script is running in a spreadsheet context.
 * Otherwise, it logs the message to the Apps Script logger.
 * @param {string} title The title of the toast notification.
 * @param {string} message The message to display.
 * @param {number} [timeoutSeconds=5] The duration to display the toast.
 */
function showToast(title: string, message: string, timeoutSeconds: number = 5): void {
    const activeSpreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    if (activeSpreadsheet) {
        activeSpreadsheet.toast(message, title, timeoutSeconds);
    } else {
        // If not running in a spreadsheet, log to the console instead.
        Logger.log(`[${title}] ${message}`);
    }
}

// ===============================================================
// KIOTVIET API HELPER
// ===============================================================

/**
 * Performs a GET request to the KiotViet API with retry logic.
 * @param {string} url The full URL to fetch.
 * @returns {GoogleAppsScript.URL_Fetch.HTTPResponse} The HTTP response.
 * @throws {Error} if KiotViet credentials are not set or if the request fails after 3 retries.
 */
function fetchKiotVietApi(url: string): GoogleAppsScript.URL_Fetch.HTTPResponse {
  const scriptProperties = PropertiesService.getScriptProperties();
  const kiotVietAccessToken = scriptProperties.getProperty('kiotviet_access_token');
  const kiotVietRetailer = scriptProperties.getProperty('kiotviet_retailer');

  if (!kiotVietAccessToken || !kiotVietRetailer) {
    throw new Error('Missing kiotviet_access_token or kiotviet_retailer in Script Properties.');
  }

  const headers = {
    'Authorization': 'Bearer ' + kiotVietAccessToken,
    'Retailer': kiotVietRetailer,
  };

  const options: GoogleAppsScript.URL_Fetch.URLFetchRequestOptions = {
    method: 'get',
    headers: headers,
    muteHttpExceptions: true,
  };

  for (let i = 0; i < 3; i++) {
    try {
      const response = UrlFetchApp.fetch(url, options);
      if (response.getResponseCode() < 400) {
        return response;
      }
      Logger.log(`KiotViet API returned status ${response.getResponseCode()} for URL ${url}. Retrying...`);
    } catch (e: any) {
      Logger.log(`Network error calling KiotViet API (Attempt ${i + 1}): ${e.toString()}`);
    }
    if (i < 2) {
      Utilities.sleep(2000); // Wait 2 seconds before retrying
    }
  }
  
  throw new Error(`Failed to fetch from KiotViet API at ${url} after 3 attempts.`);
}


/**
 * Fetches ALL data from a KiotViet endpoint by iterating through pages.
 * @param {string} endpoint - The API endpoint path (e.g., "/products").
 * @returns {any[]} An array containing all the data.
 */
function fetchAllKiotVietData(endpoint: string): any[] {
  const allData: any[] = [];
  let currentItem = 0;
  const pageSize = 100;
  let totalItems = -1;

  const baseUrl = 'https://public.kiotapi.com';
  showToast("KiotViet Fetch", `Starting data fetch from: ${endpoint}...`, -1);

  const initialUrl = `${baseUrl}${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
  const initialResponse = fetchKiotVietApi(initialUrl);
  const initialResult = JSON.parse(initialResponse.getContentText());

  if (initialResult && initialResult.total > 0 && Array.isArray(initialResult.data)) {
    totalItems = initialResult.total;
    allData.push(...initialResult.data);
    currentItem = initialResult.data.length;
    showToast(endpoint, `Fetched ${currentItem}/${totalItems} items...`);
  } else {
    showToast("Complete", `No data found at ${endpoint}.`, 5);
    return [];
  }
  
  while (currentItem < totalItems) {
    const url = `${baseUrl}${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
    const response = fetchKiotVietApi(url);
    const result = JSON.parse(response.getContentText());
    
    if (result && Array.isArray(result.data) && result.data.length > 0) {
      allData.push(...result.data);
      currentItem += result.data.length;
      showToast(endpoint, `Fetching data... ${currentItem}/${totalItems}`);
    } else {
      break; 
    }
  }

  showToast("Complete", `Finished fetching ${allData.length} items from ${endpoint}.`, 5);
  return allData;
}

// ===============================================================
// FIRESTORE REST API HELPERS
// ===============================================================

/**
 * Creates and returns an OAuth2 access token for the service account.
 * It uses credentials stored in Script Properties and caches the token.
 * @returns {string} The access token.
 * @private
 */
function getServiceAccountOAuthToken_(): string {
  const scriptProperties = PropertiesService.getScriptProperties();
  const clientEmail = scriptProperties.getProperty('firestore_client_email');
  const privateKey = scriptProperties.getProperty('firestore_private_key');

  if (!clientEmail || !privateKey) {
    throw new Error('Missing firestore_client_email or firestore_private_key in Script Properties.');
  }

  const cache = CacheService.getScriptCache();
  const cachedToken = cache.get('firestore_token');
  if (cachedToken) {
    return cachedToken;
  }

  const jwtHeader = {
    alg: 'RS256',
    typ: 'JWT'
  };

  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://www.googleapis.com/oauth2/v4/token',
    exp: now + 3600, // Token expires in 1 hour
    iat: now
  };

  const toSign = `${Utilities.base64EncodeWebSafe(JSON.stringify(jwtHeader))}.${Utilities.base64EncodeWebSafe(JSON.stringify(jwtClaimSet))}`;
  const signature = Utilities.computeRsaSha256Signature(toSign, privateKey);
  const jwt = `${toSign}.${Utilities.base64EncodeWebSafe(signature)}`;

  const tokenResponse = UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v4/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    }
  });

  const tokenData = JSON.parse(tokenResponse.getContentText());
  const accessToken = tokenData.access_token;

  if (accessToken) {
    // Cache for 59 minutes
    cache.put('firestore_token', accessToken, 3540);
  } else {
    throw new Error('Could not retrieve access token from Google OAuth.');
  }

  return accessToken;
}

/**
 * Writes a large array of data to Firestore by splitting it into batches of 500.
 * This uses the Firestore REST API for true batch operations.
 * @param {string} collectionName - The name of the Firestore collection.
 * @param {any[]} array - The array of objects to write. Each object must have an 'id' property.
 */
function batchWriteToFirestore(collectionName: string, array: any[]): void {
  const token = getServiceAccountOAuthToken_();
  const projectId = PropertiesService.getScriptProperties().getProperty("firestore_project_id");
  if (!projectId) {
    throw new Error("Missing firestore_project_id in Script Properties.");
  }
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const batchSize = 500;
  let successCount = 0;

  Logger.log(`Starting batch write of ${array.length} documents to collection '${collectionName}'.`);

  for (let i = 0; i < array.length; i += batchSize) {
    const batch = array.slice(i, i + batchSize);
    
    const writes = batch.map(item => {
      const docId = String(item.id);
      if (!docId || docId === 'undefined') return null;

      return {
        update: {
          name: `projects/${projectId}/databases/(default)/documents/${collectionName}/${docId}`,
          fields: wrapObjectForFirestore_(item)
        }
      };
    }).filter(w => w !== null);

    if (writes.length === 0) continue;

    const request = { writes: writes };
    const options: GoogleAppsScript.URL_Fetch.URLFetchRequestOptions = {
      method: "post",
      contentType: "application/json",
      headers: { Authorization: "Bearer " + token },
      payload: JSON.stringify(request),
      muteHttpExceptions: true
    };
    
    const response = UrlFetchApp.fetch(baseUrl, options);
    const responseCode = response.getResponseCode();
    
    if (responseCode >= 200 && responseCode < 300) {
      successCount += writes.length;
      Logger.log(`Successfully wrote batch ${Math.ceil((i + 1) / batchSize)} (${successCount}/${array.length} items).`);
    } else {
      const responseText = response.getContentText();
      throw new Error(`Error writing batch. Code: ${responseCode}. Response: ${responseText}`);
    }
  }
   Logger.log(`SUCCESS: Finished batch write for collection '${collectionName}'. ${successCount} documents written.`);
}

/**
 * Converts a JavaScript object into Firestore's `fields` format.
 * @param {object} obj - The object to convert.
 * @returns {object} The object in Firestore's fields format.
 * @private
 */
function wrapObjectForFirestore_(obj: { [key: string]: any }): { [key: string]: any } {
  const fields: { [key: string]: any } = {};
  for (const key in obj) {
    if (!obj.hasOwnProperty(key)) continue;
    const value = obj[key];

    if (value === null || value === undefined) {
      fields[key] = { nullValue: null };
    } else if (typeof value === 'string') {
        if (value.startsWith('projects/')) { // Handle reference values
            fields[key] = { referenceValue: value };
        } else {
            fields[key] = { stringValue: value };
        }
    } else if (typeof value === 'boolean') {
      fields[key] = { booleanValue: value };
    } else if (typeof value === 'number') {
      if (Number.isInteger(value)) {
        fields[key] = { integerValue: String(value) };
      } else {
        fields[key] = { doubleValue: value };
      }
    } else if (value instanceof Date) {
      fields[key] = { timestampValue: value.toISOString() };
    } else if (Array.isArray(value)) {
      fields[key] = {
        arrayValue: {
          values: value.map(item => {
            // Simple array conversion, can be expanded
            if (typeof item === 'string') return { stringValue: item };
            if (typeof item === 'number') return { doubleValue: item };
            return { stringValue: String(item) }; 
          })
        }
      };
    } else if (typeof value === 'object') {
        fields[key] = { mapValue: { fields: wrapObjectForFirestore_(value) } };
    }
  }
  return fields;
}

// ===============================================================
// UTILITY FUNCTIONS
// ===============================================================

/**
 * Clears the KiotViet token from the script cache.
 * Run this function to force the script to fetch a new token.
 */
function clearKiotVietTokenCache(): void {
  try {
    const cache = CacheService.getScriptCache();
    cache.remove("kiotviet_token");
    if (SpreadsheetApp.getUi()) {
      Browser.msgBox("Success!", "KiotViet token has been cleared from the cache.", Browser.Buttons.OK);
    }
    Logger.log("KiotViet token cleared from cache.");
  } catch(e: any) {
    if (SpreadsheetApp.getUi()) {
      Browser.msgBox("Error!", "Could not clear token from cache. Details: " + e.toString(), Browser.Buttons.OK);
    }
    Logger.log(`Error clearing token cache: ${e.toString()}`);
  }
}
