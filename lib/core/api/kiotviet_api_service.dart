import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class KiotVietApiService {
  final Dio _dio;

  static const String _proxyUrl =
      'https://asia-southeast1-phan-phoi-son-gia-si.cloudfunctions.net/kiotvietProxy';

  KiotVietApiService({Dio? dio}) : _dio = dio ?? Dio() {
    // Cho phép inject một Dio instance đã được cấu hình sẵn,
    // ví dụ: với interceptor để ghi log cho mục đích debug.
    if (dio == null) {
      // Chỉ thêm LogInterceptor trong chế độ debug
      if (kDebugMode) {
        _dio.interceptors.add(
          LogInterceptor(requestBody: true, responseBody: true),
        );
      }
    }
  }

  /// Gửi yêu cầu đến KiotViet API thông qua Firebase Function Proxy.
  ///
  /// [method]: Phương thức HTTP ('get', 'post', 'put', 'delete').
  /// [endpoint]: Đường dẫn API của KiotViet (ví dụ: '/products').
  /// [data]: Dữ liệu gửi đi (cho 'post', 'put') hoặc query parameters (cho 'get').
  Future<Response?> _makeProxyRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        _proxyUrl,
        data: {'method': method, 'endpoint': endpoint, 'data': data},
      );
      // Firebase Function proxy sẽ trả về dữ liệu gốc từ KiotViet,
      // và mã trạng thái 200 nếu thành công.
      return response;
    } on DioException catch (e) {
      // Lỗi từ Firebase Function (ví dụ: 500 Internal Server Error)
      // hoặc lỗi mạng.
      debugPrint('DioException on proxy request for $method $endpoint: $e');
      if (e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
      }
      // Trả về response lỗi để bên gọi có thể xử lý.
      return e.response;
    }
  }

  /// Performs a GET request to a KiotViet API endpoint.
  /// Yêu cầu này được thực hiện thông qua Firebase Function proxy.
  Future<Response?> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _makeProxyRequest('get', path, data: queryParameters);
  }

  /// Performs a POST request to a KiotViet API endpoint.
  /// Yêu cầu này được thực hiện thông qua Firebase Function proxy.
  Future<Response?> post(String path, {Map<String, dynamic>? data}) async {
    return _makeProxyRequest('post', path, data: data);
  }

  // Example function to get products
  Future<Response?> getProducts({
    int pageSize = 20,
    int currentItem = 0,
  }) async {
    return get(
      '/products',
      queryParameters: {'pageSize': pageSize, 'currentItem': currentItem},
    );
  }

  // Example function to post an order
  Future<Response?> postOrder(Map<String, dynamic> orderData) async {
    return post('/orders', data: orderData);
  }
}
