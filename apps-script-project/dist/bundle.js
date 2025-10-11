// --- Assign functions to the global object ---
// This makes them visible and runnable in the Google Apps Script editor.
// Expose the setup function
function _MANUAL_SETUP_() {
}
// Expose the function to manually refresh the KiotViet access token
function refreshKiotVietAccessToken() {
}
// Expose the main job for syncing products
function syncKiotVietProductsToFirestore() {
}
// Expose the job for syncing customers
function syncKiotVietCustomersToFirestore() {
}
// Expose the job for syncing users
function syncKiotVietUsersToFirestore() {
}
// Expose the job for syncing sale channels
function syncKiotVietSaleChannelsToFirestore() {
}
// Expose the job for syncing branches
function syncKiotVietBranchesToFirestore() {
}
// Expose the job for fixing incorrect date formats
function fixIncorrectDateFormatsInFirestore() {
}
// Expose the job for syncing price books
function syncKiotVietPriceBooksToFirestore() {
}/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./src/api/firestore_rest.ts":
/*!***********************************!*\
  !*** ./src/api/firestore_rest.ts ***!
  \***********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   batchWriteToFirestore: () => (/* binding */ batchWriteToFirestore),
/* harmony export */   getServiceAccountOAuthToken_: () => (/* binding */ getServiceAccountOAuthToken_)
/* harmony export */ });
/* harmony import */ var _core_config__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../core/config */ "./src/core/config.ts");
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
function getServiceAccountOAuthToken_() {
    const cache = CacheService.getScriptCache();
    const cachedToken = cache.get('firestore_token');
    if (cachedToken) {
        return cachedToken;
    }
    const jwtHeader = {
        alg: 'RS256',
        typ: 'JWT',
    };
    const now = Math.floor(Date.now() / 1000);
    const jwtClaimSet = {
        iss: (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getFirestoreClientEmail)(),
        scope: 'https://www.googleapis.com/auth/datastore',
        aud: 'https://www.googleapis.com/oauth2/v4/token',
        exp: now + 3600, // Token expires in 1 hour
        iat: now,
    };
    const toSign = `${Utilities.base64EncodeWebSafe(JSON.stringify(jwtHeader))}.${Utilities.base64EncodeWebSafe(JSON.stringify(jwtClaimSet))}`;
    const signature = Utilities.computeRsaSha256Signature(toSign, (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getFirestorePrivateKey)());
    const jwt = `${toSign}.${Utilities.base64EncodeWebSafe(signature)}`;
    const tokenResponse = UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v4/token', {
        method: 'post',
        contentType: 'application/x-www-form-urlencoded',
        payload: {
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: jwt,
        },
    });
    const tokenData = JSON.parse(tokenResponse.getContentText());
    const accessToken = tokenData.access_token;
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
 * @param {boolean} [merge=false] - If true, performs a merge (update) instead of a full overwrite.
 */
function batchWriteToFirestore(collectionName, array, merge = false) {
    const token = getServiceAccountOAuthToken_();
    const projectId = (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getFirestoreProjectId)();
    const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
    const batchSize = 500;
    let successCount = 0;
    Logger.log(`Starting batch write of ${array.length} documents to collection '${collectionName}'.`);
    for (let i = 0; i < array.length; i += batchSize) {
        const batch = array.slice(i, i + batchSize);
        const writes = batch
            .map(item => {
            const docId = String(item.id);
            if (!docId || docId === 'undefined')
                return null;
            const writeOperation = {
                update: {
                    name: `projects/${projectId}/databases/(default)/documents/${collectionName}/${docId}`,
                    fields: wrapObjectForFirestore_(item),
                },
            };
            if (merge) {
                // For merge, we need to specify which fields to update.
                // We exclude the 'id' field from the mask.
                const fieldPaths = Object.keys(item).filter(k => k !== 'id');
                if (fieldPaths.length > 0) {
                    writeOperation.updateMask = { fieldPaths: fieldPaths };
                }
            }
            return writeOperation;
        })
            .filter(w => w !== null);
        if (writes.length === 0)
            continue;
        const request = { writes: writes };
        const options = {
            method: 'post',
            contentType: 'application/json',
            headers: { Authorization: 'Bearer ' + token },
            payload: JSON.stringify(request),
            muteHttpExceptions: true,
        };
        const response = UrlFetchApp.fetch(baseUrl, options);
        const responseCode = response.getResponseCode();
        if (responseCode >= 200 && responseCode < 300) {
            successCount += writes.length;
            Logger.log(`Successfully wrote batch ${Math.ceil((i + 1) / batchSize)} (${successCount}/${array.length} items).`);
        }
        else {
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
function wrapObjectForFirestore_(obj) {
    const fields = {};
    for (const key in obj) {
        if (!obj.hasOwnProperty(key))
            continue;
        const value = obj[key];
        // Hoàn toàn bỏ qua các khóa có giá trị null hoặc undefined
        if (value === null || value === undefined)
            continue;
        if (typeof value === 'string') {
            if (value.startsWith('projects/')) {
                // Handle reference values
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
                    values: value.map(item => {
                        // This now correctly handles arrays of strings, which is what we need for search fields.
                        if (typeof item === 'string')
                            return { stringValue: item };
                        // Return null for unsupported types in the array to filter them out later.
                        return null;
                    }).filter(v => v !== null), // Filter out any null values from unsupported types
                },
            };
        }
        else if (typeof value === 'object') {
            fields[key] = { mapValue: { fields: wrapObjectForFirestore_(value) } };
        }
    }
    return fields;
}


/***/ }),

/***/ "./src/api/kiotviet.ts":
/*!*****************************!*\
  !*** ./src/api/kiotviet.ts ***!
  \*****************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   fetchAllKiotVietData: () => (/* binding */ fetchAllKiotVietData),
/* harmony export */   refreshKiotVietAccessToken: () => (/* binding */ refreshKiotVietAccessToken)
/* harmony export */ });
/* harmony import */ var _core_config__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../core/config */ "./src/core/config.ts");
/* harmony import */ var _core_properties__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../core/properties */ "./src/core/properties.ts");
/**
 * @fileoverview Contains functions for interacting with the KiotViet API.
 */


/**
 * Fetches a new KiotViet access token and saves it to script properties.
 * This function should be run whenever the old token expires.
 */
function refreshKiotVietAccessToken() {
    const tokenUrl = 'https://id.kiotviet.vn/connect/token';
    const payload = {
        scopes: 'PublicApi.Access',
        grant_type: 'client_credentials',
        client_id: (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getKiotVietClientId)(),
        client_secret: (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getKiotVietClientSecret)(),
    };
    const options = {
        method: 'post',
        contentType: 'application/x-www-form-urlencoded',
        payload: payload,
        muteHttpExceptions: true,
    };
    try {
        const response = UrlFetchApp.fetch(tokenUrl, options);
        const responseCode = response.getResponseCode();
        const responseBody = response.getContentText();
        if (responseCode === 200) {
            const data = JSON.parse(responseBody);
            const newAccessToken = data.access_token;
            if (newAccessToken) {
                (0,_core_properties__WEBPACK_IMPORTED_MODULE_1__.setScriptProperty)('kiotviet_access_token', newAccessToken);
                Logger.log('Successfully refreshed and saved new KiotViet access token.');
            }
            else {
                throw new Error('Access token not found in KiotViet response.');
            }
        }
        else {
            throw new Error(`Request failed with status ${responseCode}: ${responseBody}`);
        }
    }
    catch (e) {
        Logger.log(`Failed to refresh KiotViet access token: ${e.toString()}`);
        throw new Error(`Failed to refresh KiotViet access token: ${e.toString()}`);
    }
}
/**
 * Performs a GET request to the KiotViet API with retry logic.
 * @param {string} url The full URL to fetch.
 * @returns {GoogleAppsScript.URL_Fetch.HTTPResponse} The HTTP response.
 * @throws {Error} if KiotViet credentials are not set or if the request fails after 3 retries.
 */
function fetchKiotVietApi(url) {
    let kiotVietAccessToken = (0,_core_properties__WEBPACK_IMPORTED_MODULE_1__.getScriptProperty)('kiotviet_access_token');
    const headers = {
        Authorization: 'Bearer ' + kiotVietAccessToken,
        Retailer: (0,_core_config__WEBPACK_IMPORTED_MODULE_0__.getKiotVietRetailer)(),
    };
    const options = {
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
            // If token is expired (401), try refreshing it
            if (response.getResponseCode() === 401 && i < 2) {
                Logger.log('KiotViet token expired. Refreshing...');
                refreshKiotVietAccessToken();
                // re-fetch the token for the new request
                kiotVietAccessToken = (0,_core_properties__WEBPACK_IMPORTED_MODULE_1__.getScriptProperty)('kiotviet_access_token');
                headers['Authorization'] = 'Bearer ' + kiotVietAccessToken;
                continue; // Retry the request immediately with the new token
            }
            Logger.log(`KiotViet API returned status ${response.getResponseCode()} for URL ${url}. Retrying...`);
        }
        catch (e) {
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
function fetchAllKiotVietData(endpoint) {
    const allData = [];
    let currentItem = 0;
    const pageSize = 100;
    let totalItems = -1;
    const baseUrl = 'https://public.kiotapi.com';
    Logger.log(`Starting data fetch from: ${endpoint}`);
    const initialUrl = `${baseUrl}${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
    const initialResponse = fetchKiotVietApi(initialUrl);
    const initialResult = JSON.parse(initialResponse.getContentText());
    if (initialResult &&
        initialResult.total > 0 &&
        Array.isArray(initialResult.data)) {
        totalItems = initialResult.total;
        allData.push(...initialResult.data);
        currentItem = initialResult.data.length;
        Logger.log(`Fetched ${currentItem}/${totalItems} items from ${endpoint}...`);
    }
    else {
        Logger.log(`No data found at ${endpoint}.`);
        return [];
    }
    while (currentItem < totalItems) {
        const url = `${baseUrl}${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
        const response = fetchKiotVietApi(url);
        const result = JSON.parse(response.getContentText());
        if (result && Array.isArray(result.data) && result.data.length > 0) {
            allData.push(...result.data);
            currentItem += result.data.length;
            Logger.log(`Fetching data... ${currentItem}/${totalItems} from ${endpoint}`);
        }
        else {
            break;
        }
    }
    Logger.log(`Finished fetching ${allData.length} items from ${endpoint}.`);
    return allData;
}


/***/ }),

/***/ "./src/core/config.ts":
/*!****************************!*\
  !*** ./src/core/config.ts ***!
  \****************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getFirestoreClientEmail: () => (/* binding */ getFirestoreClientEmail),
/* harmony export */   getFirestorePrivateKey: () => (/* binding */ getFirestorePrivateKey),
/* harmony export */   getFirestoreProjectId: () => (/* binding */ getFirestoreProjectId),
/* harmony export */   getKiotVietClientId: () => (/* binding */ getKiotVietClientId),
/* harmony export */   getKiotVietClientSecret: () => (/* binding */ getKiotVietClientSecret),
/* harmony export */   getKiotVietRetailer: () => (/* binding */ getKiotVietRetailer)
/* harmony export */ });
/* harmony import */ var _properties__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./properties */ "./src/core/properties.ts");
/**
 * @fileoverview Manages retrieval of configuration from script properties.
 * This approach keeps sensitive data out of the source code.
 */

// Functions to get KiotViet credentials from Script Properties
const getKiotVietClientId = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('kiotviet_client_id');
const getKiotVietClientSecret = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('kiotviet_client_secret');
const getKiotVietRetailer = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('kiotviet_retailer');
// Functions to get Firestore credentials from Script Properties
const getFirestoreClientEmail = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('firestore_client_email');
const getFirestorePrivateKey = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('firestore_private_key');
const getFirestoreProjectId = () => (0,_properties__WEBPACK_IMPORTED_MODULE_0__.getScriptProperty)('firestore_project_id');


/***/ }),

/***/ "./src/core/date.ts":
/*!**************************!*\
  !*** ./src/core/date.ts ***!
  \**************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   parseKiotVietDate: () => (/* binding */ parseKiotVietDate)
/* harmony export */ });
/**
 * @fileoverview Contains utility functions for date parsing.
 */
/**
 * Parses a date string from various formats (KiotViet API, ISO 8601) into a JavaScript Date object.
 * Handles formats like:
 * - "/Date(1609459200000+0700)/" (KiotViet)
 * - "2022-08-04T13:08:26.2970000" (ISO 8601 variant)
 * @param {string | null | undefined} dateString The date string to parse.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
function parseKiotVietDate(dateString) {
    if (!dateString || typeof dateString !== 'string')
        return null;
    // 1. Try parsing KiotViet format: /Date(1609459200000+0700)/
    const kiotVietMatch = dateString.match(/\/Date\((\d+).*\)\//);
    if (kiotVietMatch && kiotVietMatch[1]) {
        return new Date(parseInt(kiotVietMatch[1], 10));
    }
    // 2. Try parsing as a standard ISO 8601 string or similar formats
    const date = new Date(dateString);
    // Check if the date is valid. `new Date('invalid string')` returns an Invalid Date object,
    // and its time value is NaN.
    if (!isNaN(date.getTime())) {
        return date;
    }
    // 3. If all parsing fails, return null
    return null;
}


/***/ }),

/***/ "./src/core/properties.ts":
/*!********************************!*\
  !*** ./src/core/properties.ts ***!
  \********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getScriptProperty: () => (/* binding */ getScriptProperty),
/* harmony export */   setScriptProperty: () => (/* binding */ setScriptProperty)
/* harmony export */ });
/**
 * @summary Lấy thuộc tính từ dịch vụ thuộc tính của tập lệnh
 * @param {string} key
 * @returns {string}
 */
const getScriptProperty = (key) => {
    const properties = PropertiesService.getScriptProperties();
    const value = properties.getProperty(key);
    if (!value) {
        throw new Error(`Không tìm thấy thuộc tính tập lệnh cho khóa: ${key}`);
    }
    return value;
};
/**
 * @summary Đặt thuộc tính cho dịch vụ thuộc tính của tập lệnh
 * @param {string} key
 * @param {string} value
 */
const setScriptProperty = (key, value) => {
    const properties = PropertiesService.getScriptProperties();
    properties.setProperty(key, value);
};


/***/ }),

/***/ "./src/core/text.ts":
/*!**************************!*\
  !*** ./src/core/text.ts ***!
  \**************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   generateKeywordsFromText: () => (/* binding */ generateKeywordsFromText),
/* harmony export */   generateSearchables: () => (/* binding */ generateSearchables)
/* harmony export */ });
/**
 * @fileoverview Contains utility functions for text processing.
 */
/**
 * Generates keywords and prefixes from a given text string for Firestore search.
 * - `keywords`: An array of unique, normalized words.
 * - `prefixes`: An array of all possible prefixes for each word, enabling "search-as-you-type".
 *
 * @param {string} text The input string to process.
 * @returns {{keywords: string[], prefixes: string[]}} An object containing keywords and prefixes.
 */
function generateSearchables(text) {
    if (!text || typeof text !== 'string') {
        return { keywords: [], prefixes: [] };
    }
    const normalizedText = text
        .toLowerCase()
        .normalize('NFD') // Decompose combined characters (e.g., 'á' -> 'a' + '´')
        .replace(/[\u0300-\u036f]/g, '') // Remove diacritical marks
        .replace(/đ/g, 'd'); // Special case for the Vietnamese letter 'đ'
    // Split by any non-alphanumeric character and filter out empty strings
    const words = normalizedText.split(/[^a-z0-9]+/).filter(word => word.length > 0);
    const uniqueWords = Array.from(new Set(words));
    const prefixes = new Set();
    uniqueWords.forEach(word => {
        for (let i = 1; i <= word.length; i++) {
            prefixes.add(word.substring(0, i));
        }
    });
    return {
        keywords: uniqueWords,
        prefixes: Array.from(prefixes),
    };
}
/**
 * @deprecated Use generateSearchables instead.
 * Generates a clean array of keywords from a given text string.
 */
function generateKeywordsFromText(text) {
    return generateSearchables(text).keywords;
}


/***/ }),

/***/ "./src/jobs/fixData.ts":
/*!*****************************!*\
  !*** ./src/jobs/fixData.ts ***!
  \*****************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   fixIncorrectDateFormatsInFirestore: () => (/* binding */ fixIncorrectDateFormatsInFirestore)
/* harmony export */ });
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/* harmony import */ var _core_config__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../core/config */ "./src/core/config.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/**
 * @fileoverview Contains functions to fix data integrity issues in Firestore.
 */




/**
 * A utility function to find and fix documents in a specific collection
 * where date fields are stored as strings instead of Timestamps.
 *
 * @param {string} collectionName The name of the Firestore collection to scan.
 * @param {string[]} dateFields An array of field names that should be dates.
 */
function fixDateFieldsInCollection(collectionName, dateFields) {
    const projectId = (0,_core_config__WEBPACK_IMPORTED_MODULE_1__.getFirestoreProjectId)();
    const token = (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_0__.getServiceAccountOAuthToken_)();
    let nextPageToken = undefined;
    const pageSize = 300; // Process 300 docs per page to stay within limits
    let documentsToUpdate = [];
    let totalDocsScanned = 0;
    Logger.log(`Starting to fix date fields for collection: '${collectionName}'...`);
    do {
        let url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionName}?pageSize=${pageSize}`;
        if (nextPageToken) {
            url += `&pageToken=${nextPageToken}`;
        }
        const options = {
            method: 'get',
            contentType: 'application/json',
            headers: { Authorization: `Bearer ${token}` },
            muteHttpExceptions: true,
        };
        const response = UrlFetchApp.fetch(url, options);
        const responseData = JSON.parse(response.getContentText());
        const documents = responseData.documents;
        if (documents && documents.length > 0) {
            totalDocsScanned += documents.length;
            Logger.log(`Scanning page of ${documents.length} documents... (Total scanned: ${totalDocsScanned})`);
            documents.forEach((doc) => {
                var _a, _b;
                const docId = doc.name.split('/').pop();
                let needsUpdate = false;
                const updatePayload = { id: docId };
                for (const field of dateFields) {
                    const fieldValue = (_b = (_a = doc.fields) === null || _a === void 0 ? void 0 : _a[field]) === null || _b === void 0 ? void 0 : _b.stringValue;
                    // Check if the field exists and is a string (indicating it's an incorrect date format)
                    if (typeof fieldValue === 'string') {
                        const parsedDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(fieldValue);
                        // We update if it's a valid KiotViet date string, or set to null if it's some other invalid string
                        if (parsedDate) {
                            Logger.log(`Found invalid date in doc '${docId}', field '${field}'. Fixing value: ${fieldValue}`);
                            updatePayload[field] = parsedDate;
                            needsUpdate = true;
                        }
                        else {
                            // Optional: handle cases where the string is not a KiotViet date, e.g., set to null
                            // updatePayload[field] = null;
                            // needsUpdate = true;
                        }
                    }
                }
                if (needsUpdate) {
                    documentsToUpdate.push(updatePayload);
                }
            });
        }
        nextPageToken = responseData.nextPageToken;
    } while (nextPageToken);
    if (documentsToUpdate.length > 0) {
        Logger.log(`Found ${documentsToUpdate.length} documents to update in '${collectionName}'.`);
        // Using merge=true to only update the specified date fields
        (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_0__.batchWriteToFirestore)(collectionName, documentsToUpdate, true); // Use merge=true
    }
    else {
        Logger.log(`No documents with incorrect date formats found in '${collectionName}'.`);
    }
}
/**
 * Main function to be run from the Apps Script Editor.
 * This will scan all relevant collections and fix any date fields
 * that were incorrectly stored as strings.
 */
function fixIncorrectDateFormatsInFirestore() {
    try {
        Logger.log('--- Starting Data Fix Process ---');
        const collectionsToFix = {
            'kiotviet_products': ['createdDate', 'modifiedDate'],
            'kiotviet_customers': ['createdDate', 'birthDate'],
            'kiotviet_users': ['createdDate', 'birthDate'],
            'kiotviet_branches': ['createdDate', 'modifiedDate'],
        };
        for (const collectionName in collectionsToFix) {
            fixDateFieldsInCollection(collectionName, collectionsToFix[collectionName]);
        }
        Logger.log('--- Data Fix Process Finished ---');
    }
    catch (e) {
        Logger.log(`An error occurred during the data fix process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncBranches.ts":
/*!**********************************!*\
  !*** ./src/jobs/syncBranches.ts ***!
  \**********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietBranchesToFirestore: () => (/* binding */ syncKiotVietBranchesToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/**
 * @fileoverview Contains the job for syncing branches from KiotViet to Firestore.
 */



/**
 * Fetches all branches from the KiotViet API and syncs them to the 'kiotviet_branches'
 * collection in Firestore.
 */
function syncKiotVietBranchesToFirestore() {
    const endpoint = '/branches';
    const collectionName = 'kiotviet_branches';
    Logger.log('Starting KiotViet Branches to Firestore synchronization process.');
    try {
        const allBranches = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(endpoint);
        if (allBranches && allBranches.length > 0) {
            const branchesToSync = allBranches.map(branch => {
                const syncedBranch = { ...branch };
                syncedBranch.createdDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(branch.createdDate);
                syncedBranch.modifiedDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(branch.modifiedDate);
                return syncedBranch;
            });
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__.batchWriteToFirestore)(collectionName, branchesToSync);
        }
        else {
            Logger.log('No branches found to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the branch sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncCustomers.ts":
/*!***********************************!*\
  !*** ./src/jobs/syncCustomers.ts ***!
  \***********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietCustomersToFirestore: () => (/* binding */ syncKiotVietCustomersToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _core_text__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../core/text */ "./src/core/text.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/**
 * @fileoverview Contains the job for syncing customers from KiotViet to Firestore.
 */




/**
 * Fetches all customers from the KiotViet API and syncs them to the 'kiotviet_customers'
 * collection in Firestore, enriching them with search keywords.
 */
function syncKiotVietCustomersToFirestore() {
    const endpoint = '/customers';
    const collectionName = 'kiotviet_customers';
    Logger.log('Starting KiotViet Customers to Firestore synchronization process.');
    try {
        const allCustomers = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(endpoint);
        if (allCustomers && allCustomers.length > 0) {
            const customersToSync = allCustomers.map(customer => {
                const nameSearchables = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateSearchables)(customer.name);
                const codeSearchables = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateSearchables)(customer.code);
                const contactNumberSearchables = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateSearchables)(customer.contactNumber);
                const allKeywords = new Set([...nameSearchables.keywords, ...codeSearchables.keywords, ...contactNumberSearchables.keywords]);
                const allPrefixes = new Set([...nameSearchables.prefixes, ...codeSearchables.prefixes, ...contactNumberSearchables.prefixes]);
                const syncedCustomer = {
                    ...customer,
                    search_keywords: Array.from(allKeywords),
                    search_prefixes: Array.from(allPrefixes),
                };
                // Only add date fields if they are valid
                syncedCustomer.createdDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(customer.createdDate);
                syncedCustomer.birthDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(customer.birthDate);
                return syncedCustomer;
            });
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_3__.batchWriteToFirestore)(collectionName, customersToSync);
        }
        else {
            Logger.log('No customers found to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the customer sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncPriceBooks.ts":
/*!************************************!*\
  !*** ./src/jobs/syncPriceBooks.ts ***!
  \************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietPriceBooksToFirestore: () => (/* binding */ syncKiotVietPriceBooksToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/**
 * @fileoverview Contains the job for syncing price books and their details from KiotViet to Firestore.
 */



/**
 * Fetches all price books from the KiotViet API and syncs them to the 'kiotviet_pricebooks'
 * collection in Firestore. For each price book, it also fetches all associated product
 * prices and syncs them to a 'details' subcollection.
 */
function syncKiotVietPriceBooksToFirestore() {
    const mainEndpoint = '/pricebooks';
    const mainCollectionName = 'kiotviet_pricebooks';
    Logger.log('Starting KiotViet Price Books to Firestore synchronization process.');
    try {
        // Step 1: Fetch all price books (main data)
        const allPriceBooks = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(mainEndpoint);
        if (!allPriceBooks || allPriceBooks.length === 0) {
            Logger.log('No price books found to sync.');
            return;
        }
        // Step 2: Map and prepare main price book data for Firestore
        const priceBooksToSync = allPriceBooks.map(pb => {
            const syncedPriceBook = { ...pb };
            // Parse date fields to ensure they are stored as Timestamps
            syncedPriceBook.startDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(pb.startDate);
            syncedPriceBook.endDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(pb.endDate);
            // Remove fields that are not needed or will be in subcollections
            delete syncedPriceBook.priceBookBranches;
            delete syncedPriceBook.priceBookCustomerGroups;
            delete syncedPriceBook.priceBookUsers;
            return syncedPriceBook;
        });
        // Step 3: Write the main price book data to Firestore
        (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__.batchWriteToFirestore)(mainCollectionName, priceBooksToSync);
        Logger.log(`Successfully synced ${priceBooksToSync.length} main price book documents.`);
        // Step 4: For each price book, fetch its details and sync to a subcollection
        allPriceBooks.forEach(priceBook => {
            const priceBookId = priceBook.id;
            const detailsEndpoint = `/pricebooks/${priceBookId}`;
            const detailsCollectionName = `${mainCollectionName}/${priceBookId}/details`;
            Logger.log(`Fetching details for Price Book ID: ${priceBookId} from endpoint: ${detailsEndpoint}`);
            // The details endpoint returns a flat array of all product prices, not paginated in the same way.
            // We assume `fetchAllKiotVietData` can handle this structure as well.
            const priceBookDetails = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(detailsEndpoint);
            if (priceBookDetails && priceBookDetails.length > 0) {
                // The detail items don't have a unique 'id' field, but 'productId' is unique per price book.
                // We'll map 'productId' to 'id' for `batchWriteToFirestore` to use as the document ID.
                const detailsToSync = priceBookDetails.map(detail => ({
                    ...detail,
                    id: detail.productId, // Use productId as the document ID
                }));
                (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__.batchWriteToFirestore)(detailsCollectionName, detailsToSync);
            }
        });
    }
    catch (e) {
        Logger.log(`An error occurred during the price book sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncProducts.ts":
/*!**********************************!*\
  !*** ./src/jobs/syncProducts.ts ***!
  \**********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietProductsToFirestore: () => (/* binding */ syncKiotVietProductsToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _core_text__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../core/text */ "./src/core/text.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/**
 * @fileoverview Contains the job for syncing products from KiotViet to Firestore.
 */




/**
 * Fetches all products from the KiotViet API and syncs them to the 'kiotviet_products'
 * collection in Firestore, enriching them with search keywords.
 */
function syncKiotVietProductsToFirestore() {
    const endpoint = '/products';
    const collectionName = 'kiotviet_products';
    Logger.log('Starting KiotViet to Firestore synchronization process.');
    try {
        // Step 1: Fetch all product data from KiotViet
        Logger.log(`Fetching all data from KiotViet endpoint: ${endpoint}`);
        const allProducts = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(endpoint);
        if (allProducts && allProducts.length > 0) {
            // Step 2: Enrich products with the search_keywords field
            const productsWithKeywords = allProducts.map(product => {
                const syncedProduct = { ...product };
                const nameSearchables = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateSearchables)(product.name);
                const codeSearchables = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateSearchables)(product.code);
                // Combine keywords and prefixes, ensuring uniqueness
                syncedProduct.search_keywords = Array.from(new Set([...nameSearchables.keywords, ...codeSearchables.keywords]));
                syncedProduct.search_prefixes = Array.from(new Set([...nameSearchables.prefixes, ...codeSearchables.prefixes]));
                // Parse date fields to ensure they are stored as Timestamps
                syncedProduct.createdDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(product.createdDate);
                syncedProduct.modifiedDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(product.modifiedDate);
                return syncedProduct;
            });
            // Step 3: Write the data to Firestore in batches
            Logger.log(`Fetched ${productsWithKeywords.length} products. Starting batch write to Firestore collection: ${collectionName}`);
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_3__.batchWriteToFirestore)(collectionName, productsWithKeywords);
            Logger.log('Successfully completed synchronization.');
        }
        else {
            Logger.log('No products found to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncSaleChannels.ts":
/*!**************************************!*\
  !*** ./src/jobs/syncSaleChannels.ts ***!
  \**************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietSaleChannelsToFirestore: () => (/* binding */ syncKiotVietSaleChannelsToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/**
 * @fileoverview Contains the job for syncing sale channels from KiotViet to Firestore.
 */


/**
 * Fetches all sale channels from the KiotViet API and syncs them to the 'kiotviet_sale_channels'
 * collection in Firestore.
 */
function syncKiotVietSaleChannelsToFirestore() {
    const endpoint = '/salechannel';
    const collectionName = 'kiotviet_sale_channels';
    Logger.log('Starting KiotViet Sale Channels to Firestore synchronization process.');
    try {
        const allSaleChannels = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(endpoint);
        if (allSaleChannels && allSaleChannels.length > 0) {
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__.batchWriteToFirestore)(collectionName, allSaleChannels);
        }
        else {
            Logger.log('No sale channels found to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the sale channel sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ }),

/***/ "./src/jobs/syncUsers.ts":
/*!*******************************!*\
  !*** ./src/jobs/syncUsers.ts ***!
  \*******************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   syncKiotVietUsersToFirestore: () => (/* binding */ syncKiotVietUsersToFirestore)
/* harmony export */ });
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/* harmony import */ var _core_date__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../core/date */ "./src/core/date.ts");
/**
 * @fileoverview Contains the job for syncing users (employees) from KiotViet to Firestore.
 */



/**
 * Fetches all users from the KiotViet API and syncs them to the 'kiotviet_users'
 * collection in Firestore.
 */
function syncKiotVietUsersToFirestore() {
    const endpoint = '/users';
    const collectionName = 'kiotviet_users';
    Logger.log('Starting KiotViet Users to Firestore synchronization process.');
    try {
        const allUsers = (0,_api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.fetchAllKiotVietData)(endpoint);
        if (allUsers && allUsers.length > 0) {
            const usersToSync = allUsers.map(user => {
                const syncedUser = { ...user };
                syncedUser.createdDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(user.createdDate);
                syncedUser.birthDate = (0,_core_date__WEBPACK_IMPORTED_MODULE_2__.parseKiotVietDate)(user.birthDate);
                return syncedUser;
            });
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_1__.batchWriteToFirestore)(collectionName, usersToSync);
        }
        else {
            Logger.log('No users found to sync.');
        }
    }
    catch (e) {
        Logger.log(`An error occurred during the user sync process: ${e.toString()}\n${e.stack}`);
    }
}


/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/global */
/******/ 	(() => {
/******/ 		__webpack_require__.g = (function() {
/******/ 			if (typeof globalThis === 'object') return globalThis;
/******/ 			try {
/******/ 				return this || new Function('return this')();
/******/ 			} catch (e) {
/******/ 				if (typeof window === 'object') return window;
/******/ 			}
/******/ 		})();
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry needs to be wrapped in an IIFE because it needs to be isolated against other modules in the chunk.
(() => {
/*!**********************!*\
  !*** ./src/index.ts ***!
  \**********************/
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./api/kiotviet */ "./src/api/kiotviet.ts");
/* harmony import */ var _jobs_syncProducts__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./jobs/syncProducts */ "./src/jobs/syncProducts.ts");
/* harmony import */ var _jobs_syncCustomers__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./jobs/syncCustomers */ "./src/jobs/syncCustomers.ts");
/* harmony import */ var _jobs_syncUsers__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./jobs/syncUsers */ "./src/jobs/syncUsers.ts");
/* harmony import */ var _jobs_syncSaleChannels__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./jobs/syncSaleChannels */ "./src/jobs/syncSaleChannels.ts");
/* harmony import */ var _jobs_syncBranches__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./jobs/syncBranches */ "./src/jobs/syncBranches.ts");
/* harmony import */ var _jobs_fixData__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./jobs/fixData */ "./src/jobs/fixData.ts");
/* harmony import */ var _jobs_syncPriceBooks__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./jobs/syncPriceBooks */ "./src/jobs/syncPriceBooks.ts");
/* harmony import */ var _core_properties__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! ./core/properties */ "./src/core/properties.ts");
/**
 * @fileoverview This is the main entry point for the Webpack bundle.
 * All functions that need to be globally available in the Google Apps Script
 * environment should be assigned to the `global` object.
 */









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
        }
        else {
            (0,_core_properties__WEBPACK_IMPORTED_MODULE_8__.setScriptProperty)(key, value);
            Logger.log(`Property "${key}" was set successfully.`);
        }
    }
    Logger.log('Manual setup complete. Please remove your secrets from the `_MANUAL_SETUP_` function.');
}
// --- Assign functions to the global object ---
// This makes them visible and runnable in the Google Apps Script editor.
// Expose the setup function
__webpack_require__.g._MANUAL_SETUP_ = _MANUAL_SETUP_;
// Expose the function to manually refresh the KiotViet access token
__webpack_require__.g.refreshKiotVietAccessToken = _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.refreshKiotVietAccessToken;
// Expose the main job for syncing products
__webpack_require__.g.syncKiotVietProductsToFirestore = _jobs_syncProducts__WEBPACK_IMPORTED_MODULE_1__.syncKiotVietProductsToFirestore;
// Expose the job for syncing customers
__webpack_require__.g.syncKiotVietCustomersToFirestore = _jobs_syncCustomers__WEBPACK_IMPORTED_MODULE_2__.syncKiotVietCustomersToFirestore;
// Expose the job for syncing users
__webpack_require__.g.syncKiotVietUsersToFirestore = _jobs_syncUsers__WEBPACK_IMPORTED_MODULE_3__.syncKiotVietUsersToFirestore;
// Expose the job for syncing sale channels
__webpack_require__.g.syncKiotVietSaleChannelsToFirestore = _jobs_syncSaleChannels__WEBPACK_IMPORTED_MODULE_4__.syncKiotVietSaleChannelsToFirestore;
// Expose the job for syncing branches
__webpack_require__.g.syncKiotVietBranchesToFirestore = _jobs_syncBranches__WEBPACK_IMPORTED_MODULE_5__.syncKiotVietBranchesToFirestore;
// Expose the job for fixing incorrect date formats
__webpack_require__.g.fixIncorrectDateFormatsInFirestore = _jobs_fixData__WEBPACK_IMPORTED_MODULE_6__.fixIncorrectDateFormatsInFirestore;
// Expose the job for syncing price books
__webpack_require__.g.syncKiotVietPriceBooksToFirestore = _jobs_syncPriceBooks__WEBPACK_IMPORTED_MODULE_7__.syncKiotVietPriceBooksToFirestore;

})();

/******/ })()
;