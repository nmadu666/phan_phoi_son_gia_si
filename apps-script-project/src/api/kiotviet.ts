/**
 * @fileoverview Contains functions for interacting with the KiotViet API.
 */
import {
  getKiotVietClientId,
  getKiotVietClientSecret,
  getKiotVietRetailer,
} from '../core/config';
import { getScriptProperty, setScriptProperty } from '../core/properties';

/**
 * Fetches a new KiotViet access token and saves it to script properties.
 * This function should be run whenever the old token expires.
 */
export function refreshKiotVietAccessToken(): void {
  const tokenUrl = 'https://id.kiotviet.vn/connect/token';

  const payload = {
    scopes: 'PublicApi.Access',
    grant_type: 'client_credentials',
    client_id: getKiotVietClientId(),
    client_secret: getKiotVietClientSecret(),
  };

  const options: GoogleAppsScript.URL_Fetch.URLFetchRequestOptions = {
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
        setScriptProperty('kiotviet_access_token', newAccessToken);
        Logger.log(
          'Successfully refreshed and saved new KiotViet access token.'
        );
      } else {
        throw new Error('Access token not found in KiotViet response.');
      }
    } else {
      throw new Error(
        `Request failed with status ${responseCode}: ${responseBody}`
      );
    }
  } catch (e: any) {
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
function fetchKiotVietApi(
  url: string
): GoogleAppsScript.URL_Fetch.HTTPResponse {
  let kiotVietAccessToken = getScriptProperty('kiotviet_access_token');

  const headers = {
    Authorization: 'Bearer ' + kiotVietAccessToken,
    Retailer: getKiotVietRetailer(),
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
      // If token is expired (401), try refreshing it
      if (response.getResponseCode() === 401 && i < 2) {
        Logger.log('KiotViet token expired. Refreshing...');
        refreshKiotVietAccessToken();
        // re-fetch the token for the new request
        kiotVietAccessToken = getScriptProperty('kiotviet_access_token');
        headers['Authorization'] = 'Bearer ' + kiotVietAccessToken;
        continue; // Retry the request immediately with the new token
      }
      Logger.log(
        `KiotViet API returned status ${response.getResponseCode()} for URL ${url}. Retrying...`
      );
    } catch (e: any) {
      Logger.log(
        `Network error calling KiotViet API (Attempt ${i + 1}): ${e.toString()}`
      );
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
export function fetchAllKiotVietData(endpoint: string): any[] {
  const allData: any[] = [];
  let currentItem = 0;
  const pageSize = 100;
  let totalItems = -1;

  const baseUrl = 'https://public.kiotapi.com';
  Logger.log(`Starting data fetch from: ${endpoint}`);

  const initialUrl = `${baseUrl}${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
  const initialResponse = fetchKiotVietApi(initialUrl);
  const initialResult = JSON.parse(initialResponse.getContentText());

  if (
    initialResult &&
    initialResult.total > 0 &&
    Array.isArray(initialResult.data)
  ) {
    totalItems = initialResult.total;
    allData.push(...initialResult.data);
    currentItem = initialResult.data.length;
    Logger.log(`Fetched ${currentItem}/${totalItems} items from ${endpoint}...`);
  } else {
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
      Logger.log(
        `Fetching data... ${currentItem}/${totalItems} from ${endpoint}`
      );
    } else {
      break;
    }
  }

  Logger.log(
    `Finished fetching ${allData.length} items from ${endpoint}.`
  );
  return allData;
}