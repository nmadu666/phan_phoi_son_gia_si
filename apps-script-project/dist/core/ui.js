/**
 * Safely displays a toast notification if the script is running in a spreadsheet context.
 * Otherwise, it logs the message to the Apps Script logger.
 * @param {string} title The title of the toast notification.
 * @param {string} message The message to display.
 * @param {number} [timeoutSeconds=5] The duration to display the toast.
 */
function showToast(title, message, timeoutSeconds = 5) {
    const activeSpreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    if (activeSpreadsheet) {
        activeSpreadsheet.toast(message, title, timeoutSeconds);
    }
    else {
        // If not running in a spreadsheet, log to the console instead.
        Logger.log(`[${title}] ${message}`);
    }
}
