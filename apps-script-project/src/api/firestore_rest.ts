/**
 * @fileoverview Contains functions for interacting with the Firestore REST API.
 */

// (Nội dung của các hàm getServiceAccountOAuthToken_, batchWriteToFirestore, và wrapObjectForFirestore_ từ helpers.ts cũ được chuyển vào đây)
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
export function batchWriteToFirestore(collectionName: string, array: any[]): void {
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
