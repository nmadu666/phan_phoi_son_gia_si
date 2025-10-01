/**
 * @fileoverview Contains maintenance jobs that can be run manually.
 */

/**
 * Clears the KiotViet token from the script cache.
 * Run this function to force the script to fetch a new token.
 */
function clearKiotVietTokenCache(): void {
  try {
    const cache = CacheService.getScriptCache();
    cache.remove("kiotviet_token"); // Assuming the KiotViet token is cached with this key
    Logger.log("KiotViet token cleared from cache.");
    const ui = SpreadsheetApp.getUi();
    if (ui) {
      ui.alert("Success!", "KiotViet token has been cleared from the cache.", ui.ButtonSet.OK);
    }
  } catch(e: any) {
    Logger.log(`Error clearing token cache: ${e.toString()}`);
  }
}

