import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_order.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../services/kiotviet_product_service.dart';
import '../services/kiotviet_customer_service.dart';
import '../services/auth_service.dart';
import '../services/kiotviet_user_service.dart';
import '../models/kiotviet_sale_channel.dart';
import '../models/kiotviet_user.dart';

/// A service to manage temporary orders, providing persistence across app sessions.
///
/// It uses `shared_preferences` to save and load orders.
class TemporaryOrderService with ChangeNotifier {
  static const _storageKey = 'temporary_orders';
  final Uuid _uuid = const Uuid();
  final AppUserService _appUserService;
  final AuthService _authService;
  final KiotVietCustomerService _customerService = KiotVietCustomerService();
  final KiotVietUserService _userService = KiotVietUserService();
  final KiotVietProductService _productService = KiotVietProductService();

  List<TemporaryOrder> _orders = [];
  String? _activeOrderId;
  bool _isInitialized = false;
  Timer? _saveDebounce;

  List<TemporaryOrder> get orders => _orders;
  String? get activeOrderId => _activeOrderId;
  bool get isInitialized => _isInitialized;

  /// A convenient getter for the currently active order.
  /// Returns null if no order is active or found.
  TemporaryOrder? get activeOrder {
    if (_activeOrderId == null) return null;
    try {
      return _orders.firstWhere((o) => o.id == _activeOrderId);
    } on StateError {
      return null; // Not found
    }
  }

  TemporaryOrderService({
    required AppUserService appUserService,
    required AuthService authService,
  }) : _appUserService = appUserService,
       _authService = authService;

  /// Initializes the service by loading orders from storage.
  /// This should be called once when the app starts.
  Future<void> init() async {
    await loadOrders();
  }

  /// Loads orders from persistent storage.
  Future<void> loadOrders() async {
    _isInitialized = false;
    notifyListeners(); // Notify UI that we are loading
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_storageKey);

    if (ordersJson != null) {
      final List<dynamic> decoded = jsonDecode(ordersJson);
      _orders = decoded
          .map((data) => TemporaryOrder.fromJson(data as Map<String, dynamic>))
          .toList();
    } else {
      _orders.clear(); // Ensure list is empty if nothing is loaded
    }

    // If no orders exist after loading, create a default one.
    if (_orders.isEmpty) {
      await _createNewOrderInternal(withSave: false);
    } else {
      // Set the first order as active by default.
      _activeOrderId = _orders.first.id;
    }

    _isInitialized = true;
    notifyListeners(); // Notify that initialization is complete and data is ready.
  }

  /// Saves the current list of orders to persistent storage.
  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> ordersToSave = _orders
        .map((order) => order.toJson())
        .toList();
    debugPrint(
      'TemporaryOrderService: Saving ${_orders.length} orders to SharedPreferences.',
    );
    await prefs.setString(_storageKey, jsonEncode(ordersToSave));
  }

  /// Schedules a save operation with a debounce mechanism to avoid excessive writes.
  void _scheduleSave() {
    // If there's an active debounce timer, cancel it.
    _saveDebounce?.cancel();
    // Start a new timer. After 500ms, call _saveOrders.
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveOrders);
  }

  /// Creates a new, empty temporary order and sets it as active.
  /// Returns the ID of the newly created order.
  Future<String?> createNewOrder() async {
    final newOrderId = await _createNewOrderInternal(withSave: true);
    if (newOrderId != null) {
      notifyListeners();
    }
    return newOrderId;
  }

  /// Internal helper to create a new order without notifying listeners immediately.
  /// This is useful for batch operations.
  Future<String?> _createNewOrderInternal({required bool withSave}) async {
    // Enforce a limit of 20 temporary orders.
    if (_orders.length >= 20) {
      // In a real app, you might want to signal this to the UI.
      debugPrint('Maximum number of temporary orders (20) reached.');
      return null;
    }
    // Get the default seller for the new order
    KiotVietUser? defaultSeller;
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final appUser = await _appUserService.getUser(currentUser.uid);
      if (appUser?.kiotvietUserRef != null) {
        defaultSeller = await _appUserService.getUserFromRef(
          appUser!.kiotvietUserRef,
        );
      }
    }
    final newOrder = TemporaryOrder(
      id: _uuid.v4(),
      name: 'Đơn tạm ${_orders.length + 1}',
      seller: defaultSeller,
      priceBookId: 0, // Mặc định sử dụng Bảng giá chung (ID: 0)
    );
    _orders.add(newOrder);
    _activeOrderId = newOrder.id;

    if (withSave) {
      _scheduleSave();
    }
    return newOrder.id;
  }

  /// Deletes an order by its ID.
  Future<void> deleteOrder(String orderId) async {
    _orders.removeWhere((order) => order.id == orderId);

    // If the deleted order was the active one, we need to select a new active order.
    // If no orders are left, create a new one to ensure there's always at least one.
    if (_activeOrderId == orderId) {
      if (_orders.isNotEmpty) {
        // Select the last order (newest) instead of the first one.
        _activeOrderId = _orders.last.id;
      } else {
        await createNewOrder(); // This will also set the active ID
        return; // Avoid calling notifyListeners twice
      }
    }

    _scheduleSave();
    notifyListeners(); // Notify after saving changes.
  }

  /// Sets the active order.
  void setActiveOrder(String orderId) {
    if (_activeOrderId != orderId) {
      _activeOrderId = orderId;
      notifyListeners();
    }
  }

  /// Adds a product from KiotViet search results to the active order.
  ///
  /// If a 'master' item (one not created by duplication) for this product
  /// already exists in the cart, its quantity is incremented. Otherwise, a new
  /// master `CartItem` is created and added to the order.
  void addKiotVietProductToActiveOrder(KiotVietProduct product) {
    _updateActiveOrder((order) {
      final List<CartItem> updatedItems = List.from(order.items);

      // Try to find an existing "master" item for this product.
      final existingItemIndex = updatedItems.indexWhere(
        (item) => item.productId == product.id && item.isMaster,
      );

      if (existingItemIndex != -1) {
        // Item exists, increment quantity.
        final oldItem = updatedItems[existingItemIndex];
        updatedItems[existingItemIndex] = oldItem.copyWith(
          quantity: oldItem.quantity + 1,
          clearOverriddenLineTotal: true, // Reset override on quantity change
        );
      } else {
        // Item does not exist, add a new "master" item.
        final newItem = CartItem(
          id: _uuid.v4(),
          productId: product.id,
          productFullName: product.fullName,
          productName: product.name,
          productCode: product.code,
          unit: product.unit,
          unitPrice: product.basePrice,
          isMaster: true,
        );
        updatedItems.add(newItem);
      }
      return order.copyWith(items: updatedItems);
    });
  }

  /// Finds an item in the active order by its unique cart item ID.
  /// This is more efficient than iterating the list every time.
  CartItem? findItemInActiveOrder(String cartItemId) {
    return activeOrder?.findItem(cartItemId);
  }

  /// Updates the quantity of an item in the active order.
  void updateItemQuantity(String cartItemId, double newQuantity) {
    _updateActiveOrder((order) {
      final List<CartItem> updatedItems = List.from(order.items);
      final itemIndex = updatedItems.indexWhere((i) => i.id == cartItemId);

      if (itemIndex == -1) return order;

      if (newQuantity <= 0) {
        updatedItems.removeAt(itemIndex);
      } else {
        updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
          quantity: newQuantity,
          clearOverriddenLineTotal: true,
        );
      }
      return order.copyWith(items: updatedItems);
    });
  }

  /// Updates the unit price of an item in the active order.
  void updateItemUnitPrice(String cartItemId, double newUnitPrice) {
    _updateItemInActiveOrder(cartItemId, (item) {
      if (newUnitPrice < 0) return item;
      return item.copyWith(
        unitPrice: newUnitPrice,
        clearOverriddenLineTotal: true,
      );
    });
  }

  /// Applies a discount to an item in the active order.
  ///
  /// - [discountValue]: The value of the discount.
  /// - [isPercentage]: True if the discount is a percentage, false for a fixed amount.
  void applyItemDiscount(
    String cartItemId,
    double discountValue, {
    required bool isPercentage,
  }) {
    _updateItemInActiveOrder(cartItemId, (item) {
      if (discountValue < 0) return item;
      return item.copyWith(
        discount: discountValue,
        isDiscountPercentage: isPercentage,
        clearOverriddenLineTotal: true,
      );
    });
  }

  /// Overrides the line total for an item.
  /// When this is set, it bypasses all other calculations for the item's total.
  /// To remove the override, set [newTotal] to null.
  void overrideItemLineTotal(String cartItemId, double? newTotal) {
    _updateItemInActiveOrder(cartItemId, (item) {
      if (newTotal != null && newTotal < 0) return item;

      // If override is removed, reset discount to 0.
      // Otherwise, set the new total.
      return item.copyWith(
        overriddenLineTotal: newTotal,
        clearOverriddenLineTotal: newTotal == null,
        discount: newTotal == null ? 0 : item.discount,
        isDiscountPercentage: newTotal == null
            ? false
            : item.isDiscountPercentage,
      );
    });
  }

  /// Removes an item from the active order.
  void removeItem(String cartItemId) {
    _updateActiveOrder((order) {
      final updatedItems = order.items
          .where((item) => item.id != cartItemId)
          .toList();
      return order.copyWith(items: updatedItems);
    });
  }

  /// Duplicates an item in the active order.
  /// The new item will have a new unique ID and will be marked as not a master item.
  void duplicateItem(CartItem itemToDuplicate) {
    _updateActiveOrder((order) {
      // Create a new item by copying the original and assigning a new ID.
      final newItem = itemToDuplicate.copyWith(
        id: _uuid.v4(),
        isMaster: false, // The duplicated item is not a master
      );
      final updatedItems = [...order.items, newItem];
      return order.copyWith(items: updatedItems);
    });
  }

  /// Updates the note of an item in the active order.
  void updateItemNote(String cartItemId, String? newNote) {
    _updateItemInActiveOrder(cartItemId, (item) {
      final trimmedNote = newNote?.trim();
      return item.copyWith(
        note: (trimmedNote != null && trimmedNote.isNotEmpty)
            ? trimmedNote
            : null,
        clearNote: (trimmedNote == null || trimmedNote.isEmpty),
      );
    });
  }

  /// Reorders an item in the active order's item list.
  void reorderItem(int oldIndex, int newIndex) {
    _updateActiveOrder((order) {
      final List<CartItem> updatedItems = List.from(order.items);
      // If the item is moved to a lower position in the list,
      // the new index needs to be adjusted.
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = updatedItems.removeAt(oldIndex);
      updatedItems.insert(newIndex, item);
      return order.copyWith(items: updatedItems);
    });
  }

  /// Imports a detailed KiotViet order, creates a new temporary order from it,
  /// and sets it as the active one.
  Future<void> importKiotVietOrder(KiotVietOrder kiotvietOrder) async {
    // 1. Lấy thông tin chi tiết cho từng sản phẩm trong đơn hàng để làm giàu dữ liệu
    final productFutures = kiotvietOrder.orderDetails.map((detail) async {
      // Lấy thông tin đầy đủ của sản phẩm từ Firestore
      final product = await _productService.getProductById(detail.productId);

      return CartItem(
        id: _uuid.v4(),
        productId: detail.productId.toString(),
        productCode: detail.productCode ?? '',
        productName: detail.productName ?? '',
        // Sử dụng fullName từ sản phẩm chi tiết nếu có, nếu không thì dùng productName
        productFullName: product?.fullName ?? detail.productName ?? '',
        // Lấy đơn vị tính từ sản phẩm chi tiết
        unit: product?.unit ?? '',
        quantity: detail.quantity,
        unitPrice: detail.price,
        isMaster: true, // Coi mỗi dòng từ KiotViet là một dòng "master"
        note: detail.note,
        // KiotViet API có thể trả về cả chiết khấu theo % và theo tiền.
        // Ưu tiên chiết khấu theo tiền mặt nếu có, nếu không thì dùng %.
        discount: detail.discount ?? detail.discountRatio ?? 0,
        isDiscountPercentage:
            detail.discount == null &&
            detail.discountRatio != null, // True nếu chỉ có chiết khấu %
      );
    });

    // Chờ tất cả các future lấy thông tin sản phẩm hoàn thành
    final cartItems = await Future.wait(productFutures);

    // 2. Lấy thông tin khách hàng và nhân viên song song một cách an toàn hơn.
    final ({KiotVietCustomer? customer, KiotVietUser? seller}) relatedData =
        await () async {
          final results = await Future.wait([
            if (kiotvietOrder.customerId != null)
              _customerService.getCustomerById(kiotvietOrder.customerId!),
            if (kiotvietOrder.soldById != null)
              _userService.getUserById(kiotvietOrder.soldById!),
          ]);
          return (
            customer: results.isNotEmpty && results.firstOrNull != null
                ? results.firstOrNull as KiotVietCustomer?
                : null,
            seller: results.length > 1 && results[1] != null
                ? results[1] as KiotVietUser?
                : null,
          );
        }();

    // 3. Tạo một đơn hàng tạm mới từ thông tin đã import.
    // Tên của đơn hàng tạm sẽ là mã đơn hàng KiotViet.
    final newOrder = TemporaryOrder(
      id: _uuid.v4(),
      name: kiotvietOrder.code,
      items: cartItems,
      customer: relatedData.customer,
      // Gán các thông tin từ KiotViet để phân biệt
      kiotvietOrderId: kiotvietOrder.id,
      kiotvietOrderCode: kiotvietOrder.code,
      description: kiotvietOrder.description,
      seller: relatedData.seller,
      // saleChannel: saleChannel,
      priceBookId: kiotvietOrder.priceBookId,
    );

    // 4. Thêm vào danh sách, đặt làm đơn hàng hoạt động và lưu lại
    // Giới hạn số lượng đơn tạm
    if (_orders.length >= 20) _orders.removeAt(0);
    _orders.add(newOrder);
    _activeOrderId = newOrder.id;

    _scheduleSave();
    notifyListeners();
  }

  /// Sets the customer for the active order.
  void setCustomerForActiveOrder(KiotVietCustomer customer) {
    _updateActiveOrder((order) => order.copyWith(customer: customer));
  }

  /// Removes the customer from the active order.
  void removeCustomerFromActiveOrder() {
    _updateActiveOrder((order) => order.copyWith(clearCustomer: true));
  }

  /// Sets or removes the seller for the active order.
  ///
  /// Pass a [KiotVietUser] object to set the seller, or `null` to remove them.
  void setSellerForActiveOrder(KiotVietUser? seller) {
    _updateActiveOrder((order) {
      if (order.seller?.id == seller?.id) return order;
      return order.copyWith(seller: seller, clearSeller: seller == null);
    });
  }

  /// Sets the sale channel for the active order.
  void setSaleChannelForActiveOrder(KiotVietSaleChannel channel) {
    _updateActiveOrder((order) {
      if (order.saleChannel?.id == channel.id) return order;
      return order.copyWith(saleChannel: channel);
    });
  }

  /// Sets the price book for the active order.
  void setPriceBookForActiveOrder(int? priceBookId) {
    _updateActiveOrder((order) {
      if (order.priceBookId == priceBookId) return order;
      // TODO: Add logic to re-calculate prices based on the new price book if needed.
      return order.copyWith(
        priceBookId: priceBookId,
        clearPriceBookId: priceBookId == null,
      );
    });
  }

  /// Updates the description of the active order.
  void updateOrderDescription(String? newDescription) {
    _updateActiveOrder((order) {
      final trimmedDescription = newDescription?.trim();
      return order.copyWith(
        description: (trimmedDescription != null && trimmedDescription.isNotEmpty)
            ? trimmedDescription
            : null,
        clearDescription: (trimmedDescription == null || trimmedDescription.isEmpty),
      );
    });
  }
  // --- Private Helper Methods ---
  /// A more robust wrapper for updating the active order with an immutable pattern.
  void _updateActiveOrder(TemporaryOrder Function(TemporaryOrder) updateFn) {
    _ensureActiveOrder();
    final currentOrder = activeOrder;
    if (currentOrder == null) return;

    final newOrder = updateFn(currentOrder);

    final index = _orders.indexWhere((o) => o.id == _activeOrderId);
    if (index != -1) {
      _orders[index] = newOrder;
      _scheduleSave();
      notifyListeners();
    }
  }

  /// A helper to update a single item within the active order.
  void _updateItemInActiveOrder(
    String cartItemId,
    CartItem Function(CartItem) updateFn,
  ) {
    _updateActiveOrder((order) => order.updateItem(cartItemId, updateFn));
  }

  /// Ensures there is an active order. If not, creates one or sets an existing one.
  void _ensureActiveOrder() {
    if (_activeOrderId == null || activeOrder == null) {
      if (_orders.isEmpty) {
        // This will create a new order and set it as active, but without saving yet.
        _createNewOrderInternal(withSave: false);
      } else {
        // If orders exist but none are active, set the last one as active.
        _activeOrderId = _orders.last.id;
      }
    }
  }
}

/// Extension methods for the immutable TemporaryOrder.
extension TemporaryOrderUpdate on TemporaryOrder {
  /// Updates a single item within the order using an immutable pattern.
  TemporaryOrder updateItem(
    String cartItemId,
    CartItem Function(CartItem) updateFn,
  ) {
    final itemIndex = items.indexWhere((i) => i.id == cartItemId);
    if (itemIndex == -1) {
      return this; // Item not found, return original order
    }

    final List<CartItem> updatedItems = List.from(items);
    final oldItem = updatedItems[itemIndex];
    final newItem = updateFn(oldItem);

    updatedItems[itemIndex] = newItem;
    return copyWith(items: updatedItems);
  }
}
