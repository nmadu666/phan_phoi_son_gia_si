/**
 * @fileoverview Contains maintenance jobs that can be run manually.
 */

/**
 * Sets the KiotViet access token in Script Properties.
 * @param {string} token The new access token to store.
 */
export function setKiotVietAccessToken(token: string): void {
  if (!token || typeof token !== 'string') {
    console.error("Invalid token provided. Please provide a valid access token string.");
    return;
  }
  try {
    const scriptProperties = PropertiesService.getScriptProperties();
    scriptProperties.setProperty("kiotviet_access_token", token);
    console.log("KiotViet access token has been set in Script Properties.");
  } catch(e: any) {
    console.error(`Error setting access token in Properties: ${e.toString()}`);
  }
}


/**
 * Clears the KiotViet access token from Script Properties.
 * Run this function to force the script to fetch or request a new token.
 */
export function clearKiotVietAccessToken(): void {
  try {
    const scriptProperties = PropertiesService.getScriptProperties();
    scriptProperties.deleteProperty("kiotviet_access_token");
    console.log("KiotViet access token cleared from Script Properties.");
  } catch(e: any) {
    console.error(`Error clearing access token from Properties: ${e.toString()}`);
  }
}