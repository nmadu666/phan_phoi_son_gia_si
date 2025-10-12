import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor để tự động làm mới access token khi nó hết hạn.
///
/// Interceptor này sẽ bắt lỗi 401 Unauthorized từ API,
/// sau đó gọi một endpoint đặc biệt trên proxy để yêu cầu token mới.
/// Khi có token mới, nó sẽ tự động thử lại yêu cầu đã thất bại.
class TokenRefreshInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final Future<Response?> Function() _refreshToken;

  TokenRefreshInterceptor(this._dio, this._refreshToken);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Nếu không phải lỗi 401, bỏ qua và để các interceptor khác xử lý.
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Xử lý lỗi 401 Unauthorized
    try {
      // 1. Gọi hàm để refresh token. QueuedInterceptor sẽ tự động
      // xếp hàng các request đến sau trong khi quá trình này diễn ra.
      final response = await _refreshToken();

      // 2. Nếu refresh thành công (proxy trả về 200)
      if (response?.statusCode == 200) {
        // 3. Thực hiện lại yêu cầu ban đầu đã thất bại.
        final responseCloned = await _dio.fetch(err.requestOptions);

        // 4. Hoàn thành yêu cầu với dữ liệu mới.
        handler.resolve(responseCloned);
      } else {
        // Nếu refresh thất bại, trả về lỗi 401 ban đầu.
        handler.next(err);
      }
    } catch (e) {
      // Nếu có lỗi trong quá trình refresh, trả về lỗi 401 ban đầu.
      handler.next(err);
    }
  }
}

class KiotVietApiService {
  final Dio _dio;

  static const String _proxyUrl =
      'https://asia-southeast1-phan-phoi-son-gia-si.cloudfunctions.net/kiotvietProxy';

  KiotVietApiService({Dio? dio}) : _dio = dio ?? Dio() {
    // Thêm interceptor để tự động refresh token.
    // Interceptor này phải được thêm trước LogInterceptor để nó xử lý lỗi 401 trước khi log.
    _dio.interceptors.add(TokenRefreshInterceptor(_dio, refreshToken));

    // Chỉ thêm LogInterceptor trong chế độ debug để dễ dàng theo dõi request/response.
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // Không log lỗi 401 vì nó sẽ được xử lý và thử lại.
          // Điều này giúp console log sạch hơn.
          error: true,
          logPrint: (object) {
            if (object.toString().contains('401')) return;
            debugPrint(object.toString());
          },
        ),
      );
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
      // Xây dựng body cho request đến proxy
      final Map<String, dynamic> requestBody = {
        'method': method,
        'endpoint': endpoint,
      };
      // Chỉ thêm trường 'data' nếu nó không phải là null
      if (data != null) {
        requestBody['data'] = data;
      }

      final response = await _dio.post(_proxyUrl, data: requestBody);
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

  /// Performs a PUT request to a KiotViet API endpoint.
  /// Yêu cầu này được thực hiện thông qua Firebase Function proxy.
  Future<Response?> put(String path, {Map<String, dynamic>? data}) async {
    return _makeProxyRequest('put', path, data: data);
  }

  /// Gửi yêu cầu đặc biệt đến proxy để làm mới KiotViet access token.
  ///
  /// Firebase Function proxy sẽ nhận diện endpoint '/refreshToken' và thực hiện
  /// logic gọi đến KiotViet để lấy token mới.
  Future<Response?> refreshToken() async {
    return _makeProxyRequest('post', '/refreshToken');
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
