/// A service class responsible for order-related logic,
/// including the core pricing calculations for paint products as defined in GEMINI.md.
class OrderService {
  /// Calculates the cost of the colorant (Chi Phí Tinh Màu) based on the core business logic.
  ///
  /// This implements the formula from GEMINI.md:
  /// `Chi Phí Tinh Màu = pricePerMl × volumeLiters × hệ số × 1000`
  ///
  /// - [pricePerMl]: The price per milliliter of the colorant, from the 'colors' collection.
  /// - [volumeLiters]: The volume of the base paint can in liters, from the 'products' collection.
  /// - [coefficient]: The system-wide adjustment factor from `SettingsService`.
  static double calculateColoringCost({
    required double pricePerMl,
    required double volumeLiters,
    required double coefficient,
  }) {
    // Basic validation to prevent errors from invalid input.
    if (pricePerMl < 0 || volumeLiters < 0 || coefficient < 0) {
      return 0.0;
    }
    return pricePerMl * volumeLiters * coefficient * 1000;
  }

  /// Calculates the final price of a tinted paint product.
  ///
  /// This implements the final price formula from GEMINI.md:
  /// `Giá cuối = Giá Sơn Gốc + Chi Phí Tinh Màu`
  static double calculateFinalPrice({
    required double basePrice,
    required double pricePerMl,
    required double volumeLiters,
    required double coefficient,
  }) {
    final coloringCost = calculateColoringCost(
      pricePerMl: pricePerMl,
      volumeLiters: volumeLiters,
      coefficient: coefficient,
    );
    return basePrice + coloringCost;
  }
}
