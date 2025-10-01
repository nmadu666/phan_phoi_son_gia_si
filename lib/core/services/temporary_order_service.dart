import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phan_phoi_son_gia_si/core/models/product.dart';
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

  /// Adds a product (as a CartItem) to the currently active order.
  /// If the item already exists, its quantity is incremented.
  void addItemToActiveOrder(Product product) {
    if (_activeOrderId == null) return;
    if (product.variants.isEmpty) return; // Cannot add product without variants

    // For simplicity, we'll add the first variant.
    // A real app might show a dialog to select a variant.
    final variant = product.variants.first;

    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

    // Check if item already exists
    try {
      final existingItem = activeOrder.items.firstWhere(
        (item) => item.productId == variant.kiotVietId,
      );
      existingItem.quantity++;
    } catch (e) {
      // Item does not exist, add a new one
      final newItem = CartItem(
        productId: variant.kiotVietId, // Using kiotVietId as unique ID
        productName: '${product.name} (${variant.volumeLiters}L)',
        unitPrice: variant.basePrice,
      );
      activeOrder.items.add(newItem);
    }
    _saveOrders();
    notifyListeners();
  }

  void addKiotVietProductToActiveOrder(KiotVietProduct product) {
    if (_activeOrderId == null) return;

    final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);

    // Check if item already exists
    try {
      final existingItem = activeOrder.items.firstWhere(
        (item) => item.productId == product.id,
      );
      existingItem.quantity++;
    } catch (e) {
      // Item does not exist, add a new one
      final newItem = CartItem(
        productId: product.id, // Using KiotVietProduct.id as unique ID
        productName: product.name,
        unitPrice: product.basePrice,
      );
      activeOrder.items.add(newItem);
    }
    _saveOrders();
    notifyListeners();
  }
}