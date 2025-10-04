import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
import 'package:uuid/uuid.dart';

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
        return TemporaryOrder(
          id: item['id'],
          name: item['name'],
          description: item['description'],
          createdAt: DateTime.parse(item['createdAt']),
          items: itemsList,
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
      };
    }).toList();
    await prefs.setString(_storageKey, jsonEncode(ordersToSave));
  }

  /// Creates a new, empty temporary order and sets it as active.
  void createNewOrder() {
    // Enforce a limit of 20 temporary orders.
    if (_orders.length >= 20) {
      // In a real app, you might want to signal this to the UI.
      print('Maximum number of temporary orders (20) reached.');
      return;
    }
    final newOrder = TemporaryOrder(
      id: _uuid.v4(),
      name: 'Đơn tạm ${_orders.length + 1}',
    );
    _orders.add(newOrder);
    _activeOrderId = newOrder.id;
    _saveOrders();
    notifyListeners();
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

  /// Generic private method to add an item to the active order.
  /// This avoids code duplication.
  void _addItemToActiveOrder({
    required String productId,
    required String productName,
    required String productCode,
    required double unitPrice,
  }) {
    if (_activeOrderId == null) return;

    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

    // Check if item already exists using a safer method.
    final existingItemIndex = activeOrder.items.indexWhere(
      (item) => item.productId == productId,
    );

    if (existingItemIndex != -1) {
      // Item exists, increment quantity.
      activeOrder.items[existingItemIndex].quantity++;
    } else {
      // Item does not exist, add a new one.
      final newItem = CartItem(
        productId: productId,
        productName: productName,
        productCode: productCode,
        unitPrice: unitPrice,
      );
      activeOrder.items.add(newItem);
    }

    _saveOrders();
    notifyListeners();
  }

  void addKiotVietProductToActiveOrder(KiotVietProduct product) {
    _addItemToActiveOrder(
      productId: product.id,
      productName: product.name,
      productCode: product.code,
      unitPrice: product.basePrice,
    );
  }

  /// Finds an item in the active order by its product ID.
  CartItem? _findItemInActiveOrder(String productId) {
    if (_activeOrderId == null) return null;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      return activeOrder.items.firstWhere(
        (item) => item.productId == productId,
      );
    } catch (e) {
      return null; // Order or item not found
    }
  }

  /// Updates the quantity of an item in the active order.
  /// Quantity can be a double.
  void updateItemQuantity(String productId, double newQuantity) {
    final item = _findItemInActiveOrder(productId);
    if (item != null) {
      // Ensure quantity is not negative
      if (newQuantity <= 0) {
        // If quantity is zero or less, remove the item
        final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
        activeOrder.items.removeWhere((i) => i.productId == productId);
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
  void updateItemUnitPrice(String productId, double newUnitPrice) {
    final item = _findItemInActiveOrder(productId);
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
    String productId,
    double discountValue, {
    required bool isPercentage,
  }) {
    final item = _findItemInActiveOrder(productId);
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
  void overrideItemLineTotal(String productId, double? newTotal) {
    final item = _findItemInActiveOrder(productId);
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
  void removeItem(String productId) {
    if (_activeOrderId == null) return;
    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
    final originalLength = activeOrder.items.length;
    activeOrder.items.removeWhere((item) => item.productId == productId);

    // Only notify if an item was actually removed
    if (activeOrder.items.length < originalLength) {
      _saveOrders();
      notifyListeners();
    }
  }
}
