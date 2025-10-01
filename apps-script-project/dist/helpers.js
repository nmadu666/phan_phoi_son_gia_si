/**
 * @fileoverview Contains common, reusable logic functions for the entire project.
 */
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
function showToast(title, message, timeoutSeconds) {
    if (timeoutSeconds === void 0) { timeoutSeconds = 5; }
    var activeSpreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    if (activeSpreadsheet) {
        activeSpreadsheet.toast(message, title, timeoutSeconds);
    }
    else {
        // If not running in a spreadsheet, log to the console instead.
        Logger.log("[".concat(title, "] ").concat(message));
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
function fetchKiotVietApi(url) {
    var scriptProperties = PropertiesService.getScriptProperties();
    var kiotVietAccessToken = scriptProperties.getProperty('kiotviet_access_token');
    var kiotVietRetailer = scriptProperties.getProperty('kiotviet_retailer');
    if (!kiotVietAccessToken || !kiotVietRetailer) {
        throw new Error('Missing kiotviet_access_token or kiotviet_retailer in Script Properties.');
    }
    var headers = {
        'Authorization': 'Bearer ' + kiotVietAccessToken,
        'Retailer': kiotVietRetailer,
    };
    var options = {
        method: 'get',
        headers: headers,
        muteHttpExceptions: true,
    };
    for (var i = 0; i < 3; i++) {
        try {
            var response = UrlFetchApp.fetch(url, options);
            if (response.getResponseCode() < 400) {
                return response;
            }
            Logger.log("KiotViet API returned status ".concat(response.getResponseCode(), " for URL ").concat(url, ". Retrying..."));
        }
        catch (e) {
            Logger.log("Network error calling KiotViet API (Attempt ".concat(i + 1, "): ").concat(e.toString()));
        }
        if (i < 2) {
            Utilities.sleep(2000); // Wait 2 seconds before retrying
        }
    }
    throw new Error("Failed to fetch from KiotViet API at ".concat(url, " after 3 attempts."));
}
/**
 * Fetches ALL data from a KiotViet endpoint by iterating through pages.
 * @param {string} endpoint - The API endpoint path (e.g., "/products").
 * @returns {any[]} An array containing all the data.
 */
function fetchAllKiotVietData(endpoint) {
    var allData = [];
    var currentItem = 0;
    var pageSize = 100;
    var totalItems = -1;
    var baseUrl = 'https://public.kiotapi.com';
    showToast("KiotViet Fetch", "Starting data fetch from: ".concat(endpoint, "..."), -1);
    var initialUrl = "".concat(baseUrl).concat(endpoint, "?currentItem=").concat(currentItem, "&pageSize=").concat(pageSize);
    var initialResponse = fetchKiotVietApi(initialUrl);
    var initialResult = JSON.parse(initialResponse.getContentText());
    if (initialResult && initialResult.total > 0 && Array.isArray(initialResult.data)) {
        totalItems = initialResult.total;
        allData.push.apply(allData, initialResult.data);
        currentItem = initialResult.data.length;
        showToast(endpoint, "Fetched ".concat(currentItem, "/").concat(totalItems, " items..."));
    }
    else {
        showToast("Complete", "No data found at ".concat(endpoint, "."), 5);
        return [];
    }
    while (currentItem < totalItems) {
        var url = "".concat(baseUrl).concat(endpoint, "?currentItem=").concat(currentItem, "&pageSize=").concat(pageSize);
        var response = fetchKiotVietApi(url);
        var result = JSON.parse(response.getContentText());
        if (result && Array.isArray(result.data) && result.data.length > 0) {
            allData.push.apply(allData, result.data);
            currentItem += result.data.length;
            showToast(endpoint, "Fetching data... ".concat(currentItem, "/").concat(totalItems));
        }
        else {
            break;
        }
    }
    showToast("Complete", "Finished fetching ".concat(allData.length, " items from ").concat(endpoint, "."), 5);
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
function getServiceAccountOAuthToken_() {
    var scriptProperties = PropertiesService.getScriptProperties();
    var clientEmail = scriptProperties.getProperty('firestore_client_email');
    var privateKey = scriptProperties.getProperty('firestore_private_key');
    if (!clientEmail || !privateKey) {
        throw new Error('Missing firestore_client_email or firestore_private_key in Script Properties.');
    }
    var cache = CacheService.getScriptCache();
    var cachedToken = cache.get('firestore_token');
    if (cachedToken) {
        return cachedToken;
    }
    var jwtHeader = {
        alg: 'RS256',
        typ: 'JWT'
    };
    var now = Math.floor(Date.now() / 1000);
    var jwtClaimSet = {
        iss: clientEmail,
        scope: 'https://www.googleapis.com/auth/datastore',
        aud: 'https://www.googleapis.com/oauth2/v4/token',
        exp: now + 3600, // Token expires in 1 hour
        iat: now
    };
    var toSign = "".concat(Utilities.base64EncodeWebSafe(JSON.stringify(jwtHeader)), ".").concat(Utilities.base64EncodeWebSafe(JSON.stringify(jwtClaimSet)));
    var signature = Utilities.computeRsaSha256Signature(toSign, privateKey);
    var jwt = "".concat(toSign, ".").concat(Utilities.base64EncodeWebSafe(signature));
    var tokenResponse = UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v4/token', {
        method: 'post',
        contentType: 'application/x-www-form-urlencoded',
        payload: {
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: jwt
        }
    });
    var tokenData = JSON.parse(tokenResponse.getContentText());
    var accessToken = tokenData.access_token;
    if (accessToken) {
        // Cache for 59 minutes
        cache.put('firestore_token', accessToken, 3540);
    }
    else {
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
function batchWriteToFirestore(collectionName, array) {
    var token = getServiceAccountOAuthToken_();
    var projectId = PropertiesService.getScriptProperties().getProperty("firestore_project_id");
    if (!projectId) {
        throw new Error("Missing firestore_project_id in Script Properties.");
    }
    var baseUrl = "https://firestore.googleapis.com/v1/projects/".concat(projectId, "/databases/(default)/documents:commit");
    var batchSize = 500;
    var successCount = 0;
    Logger.log("Starting batch write of ".concat(array.length, " documents to collection '").concat(collectionName, "'."));
    for (var i = 0; i < array.length; i += batchSize) {
        var batch = array.slice(i, i + batchSize);
        var writes = batch.map(function (item) {
            var docId = String(item.id);
            if (!docId || docId === 'undefined')
                return null;
            return {
                update: {
                    name: "projects/".concat(projectId, "/databases/(default)/documents/").concat(collectionName, "/").concat(docId),
                    fields: wrapObjectForFirestore_(item)
                }
            };
        }).filter(function (w) { return w !== null; });
        if (writes.length === 0)
            continue;
        var request = { writes: writes };
        var options = {
            method: "post",
            contentType: "application/json",
            headers: { Authorization: "Bearer " + token },
            payload: JSON.stringify(request),
            muteHttpExceptions: true
        };
        var response = UrlFetchApp.fetch(baseUrl, options);
        var responseCode = response.getResponseCode();
        if (responseCode >= 200 && responseCode < 300) {
            successCount += writes.length;
            Logger.log("Successfully wrote batch ".concat(Math.ceil((i + 1) / batchSize), " (").concat(successCount, "/").concat(array.length, " items)."));
        }
        else {
            var responseText = response.getContentText();
            throw new Error("Error writing batch. Code: ".concat(responseCode, ". Response: ").concat(responseText));
        }
    }
    Logger.log("SUCCESS: Finished batch write for collection '".concat(collectionName, "'. ").concat(successCount, " documents written."));
}
/**
 * Converts a JavaScript object into Firestore's `fields` format.
 * @param {object} obj - The object to convert.
 * @returns {object} The object in Firestore's fields format.
 * @private
 */
function wrapObjectForFirestore_(obj) {
    var fields = {};
    for (var key in obj) {
        if (!obj.hasOwnProperty(key))
            continue;
        var value = obj[key];
        if (value === null || value === undefined) {
            fields[key] = { nullValue: null };
        }
        else if (typeof value === 'string') {
            if (value.startsWith('projects/')) { // Handle reference values
                fields[key] = { referenceValue: value };
            }
            else {
                fields[key] = { stringValue: value };
            }
        }
        else if (typeof value === 'boolean') {
            fields[key] = { booleanValue: value };
        }
        else if (typeof value === 'number') {
            if (Number.isInteger(value)) {
                fields[key] = { integerValue: String(value) };
            }
            else {
                fields[key] = { doubleValue: value };
            }
        }
        else if (value instanceof Date) {
            fields[key] = { timestampValue: value.toISOString() };
        }
        else if (Array.isArray(value)) {
            fields[key] = {
                arrayValue: {
                    values: value.map(function (item) {
                        // Simple array conversion, can be expanded
                        if (typeof item === 'string')
                            return { stringValue: item };
                        if (typeof item === 'number')
                            return { doubleValue: item };
                        return { stringValue: String(item) };
                    })
                }
            };
        }
        else if (typeof value === 'object') {
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
function clearKiotVietTokenCache() {
    try {
        var cache = CacheService.getScriptCache();
        cache.remove("kiotviet_token");
        if (SpreadsheetApp.getUi()) {
            Browser.msgBox("Success!", "KiotViet token has been cleared from the cache.", Browser.Buttons.OK);
        }
        Logger.log("KiotViet token cleared from cache.");
    }
    catch (e) {
        if (SpreadsheetApp.getUi()) {
            Browser.msgBox("Error!", "Could not clear token from cache. Details: " + e.toString(), Browser.Buttons.OK);
        }
        Logger.log("Error clearing token cache: ".concat(e.toString()));
    }
}
