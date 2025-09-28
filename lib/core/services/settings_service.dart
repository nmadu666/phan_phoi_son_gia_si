import 'package:flutter/foundation.dart';

class SettingsService with ChangeNotifier {
  double _coefficient = 1.0;

  double get coefficient => _coefficient;

  void setCoefficient(double value) {
    _coefficient = value;
    notifyListeners();
  }
}