import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/temporary_order.dart';
import 'package:phan_phoi_son_gia_si/core/services/app_user_service.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_product.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../models/kiotviet_sale_channel.dart';
import '../models/kiotviet_user.dart';

/// A service to manage temporary orders, providing persistence across app sessions.
///
/// It uses `shared_preferences` to save and load orders.
class TemporaryOrderService with ChangeNotifier {
  static const _storageKey = 'temporary_orders';
  final Uuid _uuid = const Uuid();
  AppUserService _appUserService;
  AuthService _authService;

  List<TemporaryOrder> _orders = [];
  String? _activeOrderId;
  bool _isInitialized = false;

  List<TemporaryOrder> get orders => _orders;
  String? get activeOrderId => _activeOrderId;
  bool get isInitialized => _isInitialized;

  /// A convenient getter for the currently active order.
  /// Returns null if no order is active or found.
  TemporaryOrder? get activeOrder {
    if (_activeOrderId == null) return null;
    try {
      return _orders.firstWhere((o) => o.id == _activeOrderId);
    } catch (e) {
      return null; // Not found
    }
  }

  TemporaryOrderService({
    required AppUserService appUserService,
    required AuthService authService,
  }) : _appUserService = appUserService,
       _authService = authService {
    loadOrders();
  }

  /// Updates the service's dependencies when they change.
  void updateDependencies({
    required AppUserService appUserService,
    required AuthService authService,
  }) {
    _appUserService = appUserService;
    _authService = authService;
    // Could potentially reload orders if user changes, but for now it's simple.
  }

  /// Loads orders from persistent storage.
  Future<void> loadOrders() async {
    _isInitialized = false;
    notifyListeners(); // Notify UI that we are loading
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_storageKey);

    if (ordersJson != null) {
      final List<dynamic> decoded = jsonDecode(ordersJson);
      _orders.clear(); // Clear existing orders before loading new ones
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
          customer: customerData != null
              ? KiotVietCustomer.fromJson(customerData)
              : null,
          seller: sellerData != null ? KiotVietUser.fromJson(sellerData) : null,
          saleChannel: saleChannelData != null
              ? KiotVietSaleChannel.fromJson(saleChannelData)
              : null,
        );
      }).toList();
    } else {
      _orders = []; // Ensure list is empty if nothing is loaded
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
      print('Maximum number of temporary orders (20) reached.');
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
    );
    _orders.add(newOrder);
    _activeOrderId = newOrder.id;

    if (withSave) {
      await _saveOrders();
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

    await _saveOrders();
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
    _updateAndSave(() {
      _ensureActiveOrder();
      final order = activeOrder;
      if (order == null) {
      print("Failed to add product: Could not determine an active order.");
      return;
    }

      // Try to find an existing "master" item for this product.
      final existingItemIndex = order.items.indexWhere(
        (item) => item.productId == product.id && item.isMaster,
      );

      if (existingItemIndex != -1) {
        // Item exists, increment quantity.
        order.items[existingItemIndex].quantity++;
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
        order.items.add(newItem);
      }
    });
  }

  /// Finds an item in the active order by its unique cart item ID.
  CartItem? _findItemInActiveOrder(String cartItemId) {
    final order = activeOrder;
    try {
      return order?.items.firstWhere((item) => item.id == cartItemId);
    } catch (e) {
      return null; // Order or item not found
    }
  }

  /// Updates the quantity of an item in the active order.
  void updateItemQuantity(String cartItemId, double newQuantity) {
    _updateAndSave(() {
      final item = _findItemInActiveOrder(cartItemId);
      if (item != null) {
        if (newQuantity <= 0) {
          // If quantity is zero or less, remove the item
          activeOrder?.items.removeWhere((i) => i.id == cartItemId);
        } else {
          item.quantity = newQuantity;
        }
        // When quantity changes, the overridden total might no longer be valid.
        item.overriddenLineTotal = null;
      }
    });
  }

  /// Updates the unit price of an item in the active order.
  void updateItemUnitPrice(String cartItemId, double newUnitPrice) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null && newUnitPrice >= 0) {
      item.unitPrice = newUnitPrice;
      // When unit price changes, the overridden total might no longer be valid.
      item.overriddenLineTotal = null;
      _updateAndSave(() {}); // Save and notify
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
    _updateAndSave(() {
      if (item != null && discountValue >= 0) {
        item.discount = discountValue;
        item.isDiscountPercentage = isPercentage;
        // When discount changes, the overridden total might no longer be valid.
        item.overriddenLineTotal = null;
      }
    });
  }

  /// Overrides the line total for an item.
  /// When this is set, it bypasses all other calculations for the item's total.
  /// To remove the override, set [newTotal] to null.
  void overrideItemLineTotal(String cartItemId, double? newTotal) {
    final item = _findItemInActiveOrder(cartItemId);
    _updateAndSave(() {
      if (item != null) {
        if (newTotal != null && newTotal < 0) {
          return; // Cannot have negative total
        }

        item.overriddenLineTotal = newTotal;

        // If override is removed, reset discount to 0
        if (newTotal == null) {
          item.discount = 0;
          item.isDiscountPercentage = false;
        }
      }
    });
  }

  /// Removes an item from the active order.
  void removeItem(String cartItemId) {
    _updateAndSave(() {
      final order = activeOrder;
      if (order == null) return;
      order.items.removeWhere((item) => item.id == cartItemId);
    });
  }

  /// Duplicates an item in the active order.
  /// The new item will have a new unique ID and will be marked as not a master item.
  void duplicateItem(CartItem itemToDuplicate) {
    _updateAndSave(() {
      final order = activeOrder;
      if (order == null) return;

      // Create a new item by copying the original and assigning a new ID.
      final newItem = itemToDuplicate.copyWith(
        id: _uuid.v4(),
        isMaster: false, // The duplicated item is not a master
      );

      order.items.add(newItem);
    });
  }

  /// Updates the note of an item in the active order.
  void updateItemNote(String cartItemId, String? newNote) {
    final item = _findItemInActiveOrder(cartItemId);
    if (item != null) {
      // Set note to null if it's an empty string, otherwise use the new note.
      item.note = (newNote != null && newNote.trim().isEmpty) ? null : newNote;
      _updateAndSave(() {});
    }
  }

  /// Reorders an item in the active order's item list.
  void reorderItem(int oldIndex, int newIndex) {
    _updateAndSave(() {
      final order = activeOrder;
      if (order == null) return;

      // If the item is moved to a lower position in the list,
      // the new index needs to be adjusted.
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = order.items.removeAt(oldIndex);
      order.items.insert(newIndex, item);
    });
  }

  /// Sets the customer for the active order.
  void setCustomerForActiveOrder(KiotVietCustomer customer) {
    _updateAndSave(() {
      final order = activeOrder;
      if (order != null) {
        order.customer = customer;
      }
    });
  }

  /// Removes the customer from the active order.
  void removeCustomerFromActiveOrder() {
    _updateAndSave(() {
      final order = activeOrder;
      if (order != null) {
        order.customer = null;
      }
    });
  }

  /// Sets or removes the seller for the active order.
  ///
  /// Pass a [KiotVietUser] object to set the seller, or `null` to remove them.
  void setSellerForActiveOrder(KiotVietUser? seller) {
    _updateAndSave(() {
      final order = activeOrder;
      // Only update if the seller has actually changed to avoid unnecessary rebuilds.
      if (order != null && order.seller?.id != seller?.id) {
        order.seller = seller;
      }
    });
  }

  /// Sets the sale channel for the active order.
  void setSaleChannelForActiveOrder(KiotVietSaleChannel channel) {
    if (_activeOrderId == null) return;
    try {
      final activeOrder = _orders.firstWhere((o) => o.id == _activeOrderId);
      if (activeOrder.saleChannel?.id != channel.id) {
        activeOrder.saleChannel = channel;
        _saveOrders();
        notifyListeners();
      }
    } catch (e) {
      print("Error setting sale channel for active order: $e");
    }
  }

  // --- Private Helper Methods ---

  /// A wrapper to perform an update, then save and notify listeners.
  void _updateAndSave(void Function() updateFn) {
    updateFn();
    _saveOrders();
    notifyListeners();
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
