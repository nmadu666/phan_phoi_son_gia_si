import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/kiotviet_sale_channel.dart';
import '../models/kiotviet_user.dart';

/// A service to manage temporary orders, providing persistence across app sessions.
///
/// It uses `shared_preferences` to save and load orders.
class TemporaryOrderService with ChangeNotifier {
  static const _storageKey = 'temporary_orders';
  final Uuid _uuid = const Uuid();

  List<TemporaryOrder> _orders = [];
  String? _activeOrderId;

  List<TemporaryOrder> get orders => _orders;
  String? get activeOrderId => _activeOrderId;

  TemporaryOrderService() {
    loadOrders();
  }

  /// Loads orders from persistent storage.
  Future<void> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_storageKey);

    if (ordersJson != null) {
      final List<dynamic> decoded = jsonDecode(ordersJson);
      _orders = decoded.map((item) {
        final itemsList = (item['items'] as List)
            .map((cartItem) => CartItem.fromJson(cartItem))
            .toList();
        final customerData = item['customer'];
        final sellerData = item['seller'];
        final saleChannelData = item['saleChannel'];
        return TemporaryOrder(
          id: item['id'],
          name: item['name'],
          description: item['description'],
          createdAt: DateTime.parse(item['createdAt']),
          items: itemsList,
          customer:
              customerData != null ? KiotVietCustomer.fromJson(customerData) : null,
          seller: sellerData != null ? KiotVietUser.fromJson(sellerData) : null,
          saleChannel: saleChannelData != null
              ? KiotVietSaleChannel.fromJson(saleChannelData)
              : null,
        );
      }).toList();
    }

    // If no orders exist, create a default one.
    if (_orders.isEmpty) {
      createNewOrder();
    } else {
      // Set the first order as active by default.
      _activeOrderId = _orders.first.id;
    }

    notifyListeners();
  }

  /// Saves the current list of orders to persistent storage.
  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> ordersToSave = _orders.map((order) {
      return {
        'id': order.id,
        'name': order.name,
        'description': order.description,
        'createdAt': order.createdAt.toIso8601String(),
        'items': order.items.map((item) => item.toJson()).toList(),
        'customer': order.customer?.toJson(),
        'seller': order.seller?.toJson(),
        'saleChannel': order.saleChannel?.toJson(),
      };
    }).toList();
    await prefs.setString(_storageKey, jsonEncode(ordersToSave));
  }

  /// Creates a new, empty temporary order and sets it as active.
  /// Returns the ID of the newly created order.
  String? createNewOrder() {
    // Enforce a limit of 20 temporary orders.
    if (_orders.length >= 20) {
      // In a real app, you might want to signal this to the UI.
      print('Maximum number of temporary orders (20) reached.');
      return null;
    }
    final newOrder = TemporaryOrder(
      id: _uuid.v4(),
      name: 'Đơn tạm ${_orders.length + 1}',
    );
    _orders.add(newOrder);
    _activeOrderId = newOrder.id;
    _saveOrders();
    notifyListeners();
    return newOrder.id;
  }

  /// Deletes an order by its ID.
  void deleteOrder(String orderId) {
    _orders.removeWhere((order) => order.id == orderId);

    // If the deleted order was active, select another one or create a new one.
    if (_activeOrderId == orderId) {
      if (_orders.isNotEmpty) {
        // Select the last order (newest) instead of the first one.
        _activeOrderId = _orders.last.id;
      } else {
        createNewOrder(); // This will also set the active ID
        return; // Avoid calling notifyListeners twice
      }
    }

    _saveOrders();
    notifyListeners();
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
    // Sửa lỗi: Đảm bảo luôn có một đơn hàng active trước khi thêm sản phẩm.
    // Nếu không có active order, tạo mới hoặc chọn một cái có sẵn.
    if (_activeOrderId == null) {
      if (_orders.isEmpty) {
        // Tạo một đơn hàng mới và gán ID của nó làm active.
        // createNewOrder bây giờ trả về ID của đơn hàng mới.
        _activeOrderId = createNewOrder();
      } else {
        // Nếu có đơn hàng nhưng không có đơn nào active, đặt đơn cuối cùng làm active.
        _activeOrderId = _orders.last.id;
      }
    }

    // If _activeOrderId is still null (e.g., createNewOrder failed), we cannot proceed.
    if (_activeOrderId == null) {
      print("Failed to add product: Could not determine an active order.");
      return;
    }

    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

      // Try to find an existing "master" item for this product.
      final existingItemIndex = activeOrder.items.indexWhere(
        (item) => item.productId == product.id && item.isMaster,
      );

      if (existingItemIndex != -1) {
        // Item exists, increment quantity.
        activeOrder.items[existingItemIndex].quantity++;
      } else {
        // Item does not exist, add a new "master" item.
        final newItem = CartItem(
          id: _uuid.v4(), // Generate a unique ID for the cart item
          productId: product.id,
          productFullName: product.fullName,
          productName: product.name,
          productCode: product.code,
          unit: product.unit,
          unitPrice: product.basePrice,
          isMaster: true, // This is a master item
        );
        activeOrder.items.add(newItem);
      }

      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error finding active order with ID '$_activeOrderId'. Error: $e");
    }
  }

  /// Finds an item in the active order by its unique cart item ID.
  CartItem? _findItemInActiveOrder(String cartItemId) {
    if (_activeOrderId == null) return null;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      return activeOrder.items.firstWhere((item) => item.id == cartItemId);
    } catch (e) {
      return null; // Order or item not found
    }
  }

  /// Updates the quantity of an item in the active order.
  void updateItemQuantity(String cartItemId, double newQuantity) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null) {
      // Ensure quantity is not negative
      if (newQuantity <= 0) {
        // If quantity is zero or less, remove the item
        final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
        activeOrder.items.removeWhere((i) => i.id == cartItemId);
      } else {
        item.quantity = newQuantity;
      }
      // When quantity changes, the overridden total might no longer be valid.
      item.overriddenLineTotal = null;
      _saveOrders();
      notifyListeners();
    }
  }

  /// Updates the unit price of an item in the active order.
  void updateItemUnitPrice(String cartItemId, double newUnitPrice) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null && newUnitPrice >= 0) {
      item.unitPrice = newUnitPrice;
      // When unit price changes, the overridden total might no longer be valid.
      item.overriddenLineTotal = null;
      _saveOrders();
      notifyListeners();
    }
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
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null && discountValue >= 0) {
      item.discount = discountValue;
      item.isDiscountPercentage = isPercentage;
      // When discount changes, the overridden total might no longer be valid.
      item.overriddenLineTotal = null;
      _saveOrders();
      notifyListeners();
    }
  }

  /// Overrides the line total for an item.
  /// When this is set, it bypasses all other calculations for the item's total.
  /// To remove the override, set [newTotal] to null.
  void overrideItemLineTotal(String cartItemId, double? newTotal) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null) {
      if (newTotal != null && newTotal < 0)
        return; // Cannot have negative total

      item.overriddenLineTotal = newTotal;

      // If override is removed, reset discount to 0
      if (newTotal == null) {
        item.discount = 0;
        item.isDiscountPercentage = false;
      }

      _saveOrders();
      notifyListeners();
    }
  }

  /// Removes an item from the active order.
  void removeItem(String cartItemId) {
    if (_activeOrderId == null) return;
    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
    final originalLength = activeOrder.items.length;
    activeOrder.items.removeWhere((item) => item.id == cartItemId);

    // Only notify if an item was actually removed
    if (activeOrder.items.length < originalLength) {
      _saveOrders();
      notifyListeners();
    }
  }

  /// Duplicates an item in the active order.
  /// The new item will have a new unique ID and will be marked as not a master item.
  void duplicateItem(CartItem itemToDuplicate) {
    if (_activeOrderId == null) return;
    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

    // Create a new item by copying the original and assigning a new ID.
    final newItem = itemToDuplicate.copyWith(
      id: _uuid.v4(),
      isMaster: false, // The duplicated item is not a master
    );

    activeOrder.items.add(newItem);
    _saveOrders();
    notifyListeners();
  }

  /// Updates the note of an item in the active order.
  void updateItemNote(String cartItemId, String? newNote) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null) {
      // Set note to null if it's an empty string, otherwise use the new note.
      item.note = (newNote != null && newNote.trim().isEmpty) ? null : newNote;
      _saveOrders();
      notifyListeners();
    }
  }

  /// Reorders an item in the active order's item list.
  void reorderItem(int oldIndex, int newIndex) {
    if (_activeOrderId == null) return;
    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

    // If the item is moved to a lower position in the list,
    // the new index needs to be adjusted.
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = activeOrder.items.removeAt(oldIndex);
    activeOrder.items.insert(newIndex, item);

    _saveOrders();
    notifyListeners();
  }

  /// Sets the customer for the active order.
  void setCustomerForActiveOrder(KiotVietCustomer customer) {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      activeOrder.customer = customer;
      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error setting customer for active order: $e");
    }
  }

  /// Removes the customer from the active order.
  void removeCustomerFromActiveOrder() {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      activeOrder.customer = null;
      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error removing customer from active order: $e");
    }
  }

  /// Sets the seller for the active order.
  void setSellerForActiveOrder(KiotVietUser seller) {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      activeOrder.seller = seller;
      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error setting seller for active order: $e");
    }
  }

  /// Removes the seller from the active order.
  void removeSellerFromActiveOrder() {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      activeOrder.seller = null;
      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error removing seller from active order: $e");
    }
  }

  /// Sets the sale channel for the active order.
  void setSaleChannelForActiveOrder(KiotVietSaleChannel channel) {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      activeOrder.saleChannel = channel;
      _saveOrders();
      notifyListeners();
    } catch (e) {
      print("Error setting sale channel for active order: $e");
    }
  }
}
