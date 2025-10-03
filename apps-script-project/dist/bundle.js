// --- Assign functions to the global object ---
// This makes them visible and runnable in the Google Apps Script editor.
// Expose the setup function
function setupScriptProperties() {
}
// Expose the function to manually refresh the KiotViet access token
function refreshKiotVietAccessToken() {
}
// Expose the main job for syncing products
function syncKiotVietProductsToFirestore() {
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
/* harmony import */ var _core_properties__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./core/properties */ "./src/core/properties.ts");
/**
 * @fileoverview This is the main entry point for the Webpack bundle.
 * All functions that need to be globally available in the Google Apps Script
 * environment should be assigned to the `global` object.
 */



/**
 * A setup function to configure all necessary script properties.
 * Run this function once from the Google Apps Script editor to initialize the script.
 * It will prompt you for each required value.
 */
function setupScriptProperties() {
    const ui = SpreadsheetApp.getUi();
    const properties = [
        'kiotviet_client_id',
        'kiotviet_client_secret',
        'kiotviet_retailer',
        'firestore_client_email',
        'firestore_private_key',
        'firestore_project_id',
    ];
    ui.alert('Script Properties Setup', 'You will be prompted for 6 values. If you want to keep an existing value, press Cancel.', ui.ButtonSet.OK);
    properties.forEach(key => {
        const response = ui.prompt(`Enter value for "${key}"`, `Leave blank and press OK to keep the current value.`, ui.ButtonSet.OK_CANCEL);
        // Process the response
        if (response.getSelectedButton() == ui.Button.OK) {
            const value = response.getResponseText();
            if (value) { // Only set if user entered something
                (0,_core_properties__WEBPACK_IMPORTED_MODULE_2__.setScriptProperty)(key, value);
                Logger.log(`Property "${key}" was set.`);
            }
            else {
                Logger.log(`Property "${key}" was not changed.`);
            }
        }
        else {
            Logger.log(`Cancelled setting property for "${key}".`);
        }
    });
    ui.alert('Setup Complete', 'All properties have been processed.', ui.ButtonSet.OK);
}
// --- Assign functions to the global object ---
// This makes them visible and runnable in the Google Apps Script editor.
// Expose the setup function
__webpack_require__.g.setupScriptProperties = setupScriptProperties;
// Expose the function to manually refresh the KiotViet access token
__webpack_require__.g.refreshKiotVietAccessToken = _api_kiotviet__WEBPACK_IMPORTED_MODULE_0__.refreshKiotVietAccessToken;
// Expose the main job for syncing products
__webpack_require__.g.syncKiotVietProductsToFirestore = _jobs_syncProducts__WEBPACK_IMPORTED_MODULE_1__.syncKiotVietProductsToFirestore;

})();

/******/ })()
;