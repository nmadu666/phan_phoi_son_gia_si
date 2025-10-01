/**
 * Tự động làm mới access token của KiotViet và lưu vào Script Properties.
 * Hàm này nên được chạy định kỳ (ví dụ: mỗi 50 phút) trước khi token hết hạn.
 * KiotViet token thường có hiệu lực trong 60 phút.
 */
function refreshKiotVietToken() {
    Logger.log('Bắt đầu quá trình làm mới KiotViet access token...');
    var scriptProperties = PropertiesService.getScriptProperties();
    var clientId = scriptProperties.getProperty('kiotviet_client_id');
    var clientSecret = scriptProperties.getProperty('kiotviet_client_secret');
    if (!clientId || !clientSecret) {
        Logger.log('Lỗi: Không tìm thấy kiotviet_client_id hoặc kiotviet_client_secret trong Script Properties.');
        return;
    }
    var tokenUrl = 'https://id.kiotviet.vn/connect/token';
    var payload = {
        'scope': 'PublicApi.Access', // Yêu cầu quyền truy cập Public API
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret
    };
    var options = {
        'method': 'post',
        'contentType': 'application/x-www-form-urlencoded',
        'payload': payload,
        'muteHttpExceptions': true
    };
    try {
        var response = UrlFetchApp.fetch(tokenUrl, options);
        var responseCode = response.getResponseCode();
        var responseBody = JSON.parse(response.getContentText());
        if (responseCode === 200 && responseBody.access_token) {
            scriptProperties.setProperty('kiotviet_access_token', responseBody.access_token);
            Logger.log('Làm mới và lưu KiotViet access token thành công.');
        }
        else {
            Logger.log("L\u1ED7i khi l\u1EA5y token. Status: ".concat(responseCode, ". Body: ").concat(JSON.stringify(responseBody)));
        }
    }
    catch (e) {
        Logger.log('Lỗi nghiêm trọng khi gọi API lấy token: ' + e.toString());
    }
}
