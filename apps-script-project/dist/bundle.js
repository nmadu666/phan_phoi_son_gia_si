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
/* harmony export */   batchWriteToFirestore: () => (/* binding */ batchWriteToFirestore)
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
 */
function batchWriteToFirestore(collectionName, array) {
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
            return {
                update: {
                    name: `projects/${projectId}/databases/(default)/documents/${collectionName}/${docId}`,
                    fields: wrapObjectForFirestore_(item),
                },
            };
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
        if (value === null || value === undefined) {
            fields[key] = { nullValue: null };
        }
        else if (typeof value === 'string') {
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
                        // Simple array conversion, can be expanded
                        if (typeof item === 'string')
                            return { stringValue: item };
                        if (typeof item === 'number')
                            return { doubleValue: item };
                        return { stringValue: String(item) };
                    }),
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
/* harmony export */   generateKeywordsFromText: () => (/* binding */ generateKeywordsFromText)
/* harmony export */ });
/**
 * @fileoverview Contains utility functions for text processing.
 */
/**
 * Generates a clean array of keywords from a given text string.
 * This function performs several normalization steps:
 * 1. Converts the text to lowercase.
 * 2. Removes Vietnamese diacritics (e.g., "sơn màu" -> "son mau").
 * 3. Replaces any non-alphanumeric characters with spaces.
 * 4. Splits the text into individual words.
 * 5. Returns an array of unique, non-empty keywords.
 *
 * @param {string} text The input string to process.
 * @returns {string[]} An array of normalized keywords.
 */
function generateKeywordsFromText(text) {
    if (!text) {
        return [];
    }
    const normalizedText = text
        .toLowerCase()
        .normalize('NFD') // Decompose combined characters (e.g., 'á' -> 'a' + '´')
        .replace(/[\u0300-\u036f]/g, '') // Remove diacritical marks
        .replace(/đ/g, 'd'); // Special case for the Vietnamese letter 'đ'
    // Split by any non-alphanumeric character and filter out empty strings
    const words = normalizedText.split(/[^a-z0-9]+/).filter(word => word.length > 0);
    return Array.from(new Set(words)); // Return unique keywords
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
/**
 * @fileoverview Contains the job for syncing branches from KiotViet to Firestore.
 */


/**
 * Parses a date string from KiotViet API format (e.g., "/Date(1609459200000+0700)/")
 * into a JavaScript Date object.
 * @param {string | null | undefined} kiotVietDate The date string from KiotViet.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
function parseKiotVietDate(kiotVietDate) {
    if (!kiotVietDate || typeof kiotVietDate !== 'string') {
        return null;
    }
    const match = kiotVietDate.match(/\/Date\((\d+).*\)\//);
    if (match && match[1]) {
        return new Date(parseInt(match[1], 10));
    }
    return null;
}
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
            const branchesToSync = allBranches.map(branch => ({
                ...branch,
                createdDate: parseKiotVietDate(branch.createdDate),
                modifiedDate: parseKiotVietDate(branch.modifiedDate),
            }));
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
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
/**
 * @fileoverview Contains the job for syncing customers from KiotViet to Firestore.
 */



/**
 * Parses a date string from KiotViet API format (e.g., "/Date(1609459200000+0700)/")
 * into a JavaScript Date object.
 * @param {string | null | undefined} kiotVietDate The date string from KiotViet.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
function parseKiotVietDate(kiotVietDate) {
    if (!kiotVietDate || typeof kiotVietDate !== 'string') {
        return null;
    }
    const match = kiotVietDate.match(/\/Date\((\d+).*\)\//);
    if (match && match[1]) {
        return new Date(parseInt(match[1], 10));
    }
    return null;
}
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
                const nameKeywords = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateKeywordsFromText)(customer.name);
                const codeKeywords = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateKeywordsFromText)(customer.code);
                const contactNumberKeywords = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateKeywordsFromText)(customer.contactNumber);
                const allKeywords = new Set([
                    ...nameKeywords,
                    ...codeKeywords,
                    ...contactNumberKeywords,
                ]);
                const syncedCustomer = {
                    ...customer,
                    search_keywords: Array.from(allKeywords),
                };
                // Only add date fields if they are valid
                const createdDate = parseKiotVietDate(customer.createdDate);
                if (createdDate)
                    syncedCustomer.createdDate = createdDate;
                const birthDate = parseKiotVietDate(customer.birthDate);
                if (birthDate)
                    syncedCustomer.birthDate = birthDate;
                return syncedCustomer;
            });
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_2__.batchWriteToFirestore)(collectionName, customersToSync);
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
/* harmony import */ var _api_firestore_rest__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../api/firestore_rest */ "./src/api/firestore_rest.ts");
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
                const nameKeywords = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateKeywordsFromText)(product.name);
                const codeKeywords = (0,_core_text__WEBPACK_IMPORTED_MODULE_1__.generateKeywordsFromText)(product.code);
                // Combine keywords from name and code, ensuring uniqueness
                const allKeywords = new Set([...nameKeywords, ...codeKeywords]);
                return { ...product, search_keywords: Array.from(allKeywords) };
            });
            // Step 3: Write the data to Firestore in batches
            Logger.log(`Fetched ${productsWithKeywords.length} products. Starting batch write to Firestore collection: ${collectionName}`);
            (0,_api_firestore_rest__WEBPACK_IMPORTED_MODULE_2__.batchWriteToFirestore)(collectionName, productsWithKeywords);
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
/**
 * @fileoverview Contains the job for syncing users (employees) from KiotViet to Firestore.
 */


/**
 * Parses a date string from KiotViet API format (e.g., "/Date(1609459200000+0700)/")
 * into a JavaScript Date object.
 * @param {string | null | undefined} kiotVietDate The date string from KiotViet.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
function parseKiotVietDate(kiotVietDate) {
    if (!kiotVietDate || typeof kiotVietDate !== 'string') {
        return null;
    }
    const match = kiotVietDate.match(/\/Date\((\d+).*\)\//);
    if (match && match[1]) {
        return new Date(parseInt(match[1], 10));
    }
    return null;
}
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
                const createdDate = parseKiotVietDate(user.createdDate);
                if (createdDate)
                    syncedUser.createdDate = createdDate;
                const birthDate = parseKiotVietDate(user.birthDate);
                if (birthDate)
                    syncedUser.birthDate = birthDate;
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
/* harmony import */ var _core_properties__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./core/properties */ "./src/core/properties.ts");
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
            (0,_core_properties__WEBPACK_IMPORTED_MODULE_6__.setScriptProperty)(key, value);
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

})();

/******/ })()
;