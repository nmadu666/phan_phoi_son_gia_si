// (Nội dung của các hàm fetchKiotVietApi và fetchAllKiotVietData từ helpers.ts cũ được chuyển vào đây)
/**
 * Performs a GET request to the KiotViet API with retry logic.
 * @param {string} url The full URL to fetch.
 * @returns {GoogleAppsScript.URL_Fetch.HTTPResponse} The HTTP response.
 * @throws {Error} if KiotViet credentials are not set or if the request fails after 3 retries.
 */
function fetchKiotVietApi(url) {
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
            Logger.log(`KiotViet API returned status ${response.getResponseCode()} for URL . Retrying...`);
        }
        catch (e) {
            Logger.log(`Network error calling KiotViet API (Attempt ${i + 1}): ${e.toString()}`);
        }
        if (i < 2) {
            Utilities.sleep(2000); // Wait 2 seconds before retrying
        }
    }
    throw new Error(`Failed to fetch from KiotViet API at  after 3 attempts.`);
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
    (0, ui_1.showToast)("KiotViet Fetch", `Starting data fetch from: ...`, -1);
    const initialUrl = `?currentItem=&pageSize=`;
    const initialResponse = fetchKiotVietApi(initialUrl);
    const initialResult = JSON.parse(initialResponse.getContentText());
    if (initialResult && initialResult.total > 0 && Array.isArray(initialResult.data)) {
        totalItems = initialResult.total;
        allData.push(...initialResult.data);
        currentItem = initialResult.data.length;
        (0, ui_1.showToast)(endpoint, `Fetched / items...`);
    }
    else {
        (0, ui_1.showToast)("Complete", `No data found at .`, 5);
        return [];
    }
    while (currentItem < totalItems) {
        const url = `?currentItem=&pageSize=`;
        const response = fetchKiotVietApi(url);
        const result = JSON.parse(response.getContentText());
        if (result && Array.isArray(result.data) && result.data.length > 0) {
            allData.push(...result.data);
            currentItem += result.data.length;
            (0, ui_1.showToast)(endpoint, `Fetching data... /`);
        }
        else {
            break;
        }
    }
    (0, ui_1.showToast)("Complete", `Finished fetching ${allData.length} items from .`, 5);
    return allData;
}
