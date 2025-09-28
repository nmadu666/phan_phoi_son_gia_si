import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/color_pricing.dart';

/// A service class to interact with color-related data in Firestore.
/// As per GEMINI.md, this service fetches data from the 'colors' collection.
class ColorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Use 'colors' collection as defined in GEMINI.md
  late final CollectionReference<Map<String, dynamic>> _colorsCollection;

  ColorService() {
    _colorsCollection = _firestore.collection('colors');
  }

  /// Fetches all colors (which include pricing info) from Firestore.
  Future<List<ColorPricing>> getColorPricings() async {
    try {
      // Note: The model is named ColorPricing, but the collection is 'colors'.
      // This might be something to align in the future for clarity.
      final querySnapshot = await _colorsCollection.get();
      return querySnapshot.docs
          .map((doc) => ColorPricing.fromFirestore(doc))
          .toList();
    } catch (e) {
      // For production, consider using a dedicated logging service.
      print('Error fetching color pricings: $e');
      return [];
    }
  }
}
