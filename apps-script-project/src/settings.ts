/**
 * Định nghĩa cấu trúc cho phản hồi từ API token của KiotViet.
 */
interface KiotVietTokenResponse {
  access_token?: string;
  [key: string]: any;
}

/**
 * Tự động làm mới access token của KiotViet và lưu vào Script Properties.
 * Hàm này nên được chạy định kỳ (ví dụ: mỗi 50 phút) trước khi token hết hạn.
 * KiotViet token thường có hiệu lực trong 60 phút.
 */
function refreshKiotVietToken(): void {
  Logger.log('Bắt đầu quá trình làm mới KiotViet access token...');
  const scriptProperties: Properties = PropertiesService.getScriptProperties();
  const clientId: string | null = scriptProperties.getProperty('kiotviet_client_id');
  const clientSecret: string | null = scriptProperties.getProperty('kiotviet_client_secret');

  if (!clientId || !clientSecret) {
    Logger.log('Lỗi: Không tìm thấy kiotviet_client_id hoặc kiotviet_client_secret trong Script Properties.');
    return;
  }

  const tokenUrl = 'https://id.kiotviet.vn/connect/token';
  const payload: { [key: string]: string } = {
    'scope': 'PublicApi.Access', // Yêu cầu quyền truy cập Public API
    'grant_type': 'client_credentials',
    'client_id': clientId,
    'client_secret': clientSecret
  };

  const options: URLFetchRequestOptions = {
    'method': 'post',
    'contentType': 'application/x-www-form-urlencoded',
    'payload': payload,
    'muteHttpExceptions': true
  };

  try {
    const response = UrlFetchApp.fetch(tokenUrl, options);
    const responseCode: number = response.getResponseCode();
    const responseBody: KiotVietTokenResponse = JSON.parse(response.getContentText());

    if (responseCode === 200 && responseBody.access_token) {
      scriptProperties.setProperty('kiotviet_access_token', responseBody.access_token);
      Logger.log('Làm mới và lưu KiotViet access token thành công.');
    } else {
      Logger.log(`Lỗi khi lấy token. Status: ${responseCode}. Body: ${JSON.stringify(responseBody)}`);
    }
  } catch (e: any) {
    Logger.log('Lỗi nghiêm trọng khi gọi API lấy token: ' + e.toString());
  }
}
