
import 'package:dio/dio.dart';
// TODO: Consider using flutter_dotenv to load credentials from a .env file
// for better security.

class KiotVietApiService {
  final Dio _dio;

  // Hardcoded OAuth 2.0 configuration
  // WARNING: Storing secrets in source code is not recommended.
  // These should be loaded from a secure configuration file.
  static const String _clientId = 'ca70d033-6a44-4ad1-bbec-d142616ede22';
  static const String _clientSecret = 'EFDECA4A7AC13D65ED054DA26533F7016DDB6C9C';
  static const String _retailer = 'phanphoisongiasi';
  static const String _tokenEndpoint = 'https://id.kiotviet.vn/connect/token';

  String? _accessToken;
  DateTime? _tokenExpiryTime;

  KiotVietApiService({Dio? dio}) : _dio = dio ?? Dio() {
    // This allows for injecting a pre-configured Dio instance,
    // for example with a proxy or logging interceptor for debugging.
    if (dio == null) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      )); // Example interceptor
    }
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null && _tokenExpiryTime != null && DateTime.now().isBefore(_tokenExpiryTime!)) {
      return _accessToken;
    }

    try {
      final response = await _dio.post(
        _tokenEndpoint,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'client_credentials',
          'scope': 'PublicApi',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Retailer': _retailer,
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        _accessToken = responseData['access_token'];
        final expiresIn = responseData['expires_in'] as int;
        // Store the expiry time, with a small buffer (e.g., 60 seconds)
        _tokenExpiryTime = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      } else {
        // Handle non-200 status code
        print('Failed to get access token: ${response.statusCode}');
        print('Response: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors (network, etc.)
      print('Error getting access token: $e');
      if (e.response != null) {
        print('Error response data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      // Handle other errors
      print('An unexpected error occurred: $e');
      return null;
    }
  }
}
