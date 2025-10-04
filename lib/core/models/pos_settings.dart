import 'dart:convert';

/// Model to hold all user-configurable settings for the POS screen.
class PosSettings {
  // Display Tab Settings
  final bool showLineNumber;
  final bool showProductCode;
  final bool showSellingPrice;
  final bool showDiscount;
  final bool showLineTotal;
  final bool allowEditLineTotal;
  final bool showLastPrice;
  final bool showPaymentSuggestion;

  // Other Tab Settings
  final bool showInventory;
  final bool allowDragAndDrop;

  PosSettings({
    this.showLineNumber = true,
    this.showProductCode = true,
    this.showSellingPrice = true,
    this.showDiscount = true,
    this.showLineTotal = true,
    this.allowEditLineTotal = false,
    this.showLastPrice = false,
    this.showPaymentSuggestion = true,
    this.showInventory = true,
    this.allowDragAndDrop = true,
  });

  PosSettings copyWith({
    bool? showLineNumber,
    bool? showProductCode,
    bool? showSellingPrice,
    bool? showDiscount,
    bool? showLineTotal,
    bool? allowEditLineTotal,
    bool? showLastPrice,
    bool? showPaymentSuggestion,
    bool? showInventory,
    bool? allowDragAndDrop,
  }) {
    return PosSettings(
      showLineNumber: showLineNumber ?? this.showLineNumber,
      showProductCode: showProductCode ?? this.showProductCode,
      showSellingPrice: showSellingPrice ?? this.showSellingPrice,
      showDiscount: showDiscount ?? this.showDiscount,
      showLineTotal: showLineTotal ?? this.showLineTotal,
      allowEditLineTotal: allowEditLineTotal ?? this.allowEditLineTotal,
      showLastPrice: showLastPrice ?? this.showLastPrice,
      showPaymentSuggestion:
          showPaymentSuggestion ?? this.showPaymentSuggestion,
      showInventory: showInventory ?? this.showInventory,
      allowDragAndDrop: allowDragAndDrop ?? this.allowDragAndDrop,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showLineNumber': showLineNumber,
      'showProductCode': showProductCode,
      'showSellingPrice': showSellingPrice,
      'showDiscount': showDiscount,
      'showLineTotal': showLineTotal,
      'allowEditLineTotal': allowEditLineTotal,
      'showLastPrice': showLastPrice,
      'showPaymentSuggestion': showPaymentSuggestion,
      'showInventory': showInventory,
      'allowDragAndDrop': allowDragAndDrop,
    };
  }

  factory PosSettings.fromMap(Map<String, dynamic> map) {
    return PosSettings(
      showLineNumber: map['showLineNumber'] ?? true,
      showProductCode: map['showProductCode'] ?? true,
      showSellingPrice: map['showSellingPrice'] ?? true,
      showDiscount: map['showDiscount'] ?? true,
      showLineTotal: map['showLineTotal'] ?? true,
      allowEditLineTotal: map['allowEditLineTotal'] ?? false,
      showLastPrice: map['showLastPrice'] ?? false,
      showPaymentSuggestion: map['showPaymentSuggestion'] ?? true,
      showInventory: map['showInventory'] ?? true,
      allowDragAndDrop: map['allowDragAndDrop'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory PosSettings.fromJson(String source) =>
      PosSettings.fromMap(json.decode(source));

  @override
  String toString() {
    return 'PosSettings(showLineNumber: $showLineNumber, showProductCode: $showProductCode, showSellingPrice: $showSellingPrice, showDiscount: $showDiscount, showLineTotal: $showLineTotal, allowEditLineTotal: $allowEditLineTotal, showLastPrice: $showLastPrice, showPaymentSuggestion: $showPaymentSuggestion, showInventory: $showInventory, allowDragAndDrop: $allowDragAndDrop)';
  }
}

