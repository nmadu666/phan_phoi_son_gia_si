import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:phan_phoi_son_gia_si/core/api/kiotviet_api_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/paginated_result.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';

class KiotVietOrderService {
  final KiotVietApiService _apiService;

  KiotVietOrderService({KiotVietApiService? apiService})
    : _apiService = apiService ?? KiotVietApiService();

  /// Fetches a list of orders from the KiotViet API.
  ///
  /// [branchIds]: List of branch IDs to filter by.
  /// [status]: List of order statuses to filter by.
  /// [orderBy]: Field to sort by, e.g., 'purchaseDate'.
  /// [orderDirection]: 'Asc' for ascending, 'Desc' for descending.
  /// [includeOrderDelivery]: Whether to include delivery information.
  /// [pageSize]: Number of items per page.
  /// [currentItem]: The starting index for pagination.
  Future<PaginatedResult<KiotVietOrder>?> getOrders({
    List<int>? branchIds,
    List<int>? status,
    String orderBy = 'purchaseDate',
    String orderDirection = 'Desc', // Default to get the latest orders
    bool includeOrderDelivery = true,
    int pageSize = 30,
    int currentItem = 0,
  }) async {
    const path = '/orders';

    // Build query parameters
    final queryParameters = <String, dynamic>{
      'pageSize': pageSize,
      'currentItem': currentItem,
      'orderBy': orderBy,
      'orderDirection': orderDirection,
      'includeOrderDelivery': includeOrderDelivery,
    };

    if (branchIds != null && branchIds.isNotEmpty) {
      queryParameters['branchIds'] = branchIds;
    }
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }

    try {
      final response = await _apiService.get(
        path,
        queryParameters: queryParameters,
      );

      if (response != null && response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> orderListJson = data['data'];
        final orders = orderListJson
            .map((json) => KiotVietOrder.fromJson(json))
            .toList();

        return PaginatedResult<KiotVietOrder>(
          data: orders,
          total: data['total'] ?? 0,
          currentItem: data['currentItem'] ?? 0,
          pageSize: data['pageSize'] ?? 0,
        );
      } else {
        debugPrint(
          'Failed to get orders. Status: ${response?.statusCode}, Body: ${response?.data}',
        );
        return null;
      }
    } on DioException catch (e) {
      // Bắt lỗi từ Dio (lỗi mạng, lỗi từ proxy function)
      debugPrint('DioException while getting orders: $e');
      if (e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      // Bắt các lỗi không mong muốn khác
      debugPrint('An unexpected error occurred while getting orders: $e');
      return null;
    }
  }

  /// Creates a new order on KiotViet via the API proxy.
  ///
  /// [orderData]: A map representing the order payload.
  /// This should match the structure expected by the KiotViet /orders endpoint.
  Future<KiotVietOrder?> createOrder(Map<String, dynamic> orderData) async {
    const path = '/orders';

    try {
      final response = await _apiService.post(path, data: orderData);

      // KiotViet thường trả về 201 Created hoặc 200 OK khi tạo thành công
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        // Phản hồi có thể chứa toàn bộ đối tượng đơn hàng vừa tạo
        return KiotVietOrder.fromJson(response.data);
      } else {
        debugPrint(
          'Failed to create order. Status: ${response?.statusCode}, Body: ${response?.data}',
        );
        return null;
      }
    } on DioException catch (e) {
      debugPrint('DioException while creating order: $e');
      if (e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      debugPrint('An unexpected error occurred while creating order: $e');
      return null;
    }
  }
}
