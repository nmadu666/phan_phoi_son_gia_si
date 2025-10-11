import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/pos_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user-specific settings for the Point of Sale (POS) interface.
///
/// This service persists settings locally using `SharedPreferences`, allowing
/// users to customize their layout and have it remembered across app sessions.
class PosSettingsService with ChangeNotifier {
  static const _storageKey = 'pos_settings';
  late SharedPreferences _prefs;

  PosSettings _settings = PosSettings();
  bool _isInitialized = false;

  PosSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  /// Initializes the service by loading settings from local storage.
  /// This should be called once when the app starts.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    _isInitialized = true;
    notifyListeners();
  }

  /// Loads settings from SharedPreferences. If no settings are found,
  /// it uses the default `PosSettings` object.
  Future<void> _loadSettings() async {
    final String? settingsJson = _prefs.getString(_storageKey);
    if (settingsJson != null) {
      try {
        _settings = PosSettings.fromJson(jsonDecode(settingsJson));
      } catch (e) {
        debugPrint('Error decoding POS settings: $e. Using default settings.');
        _settings = PosSettings();
      }
    }
  }

  /// Updates the current settings and persists them to local storage.
  Future<void> updateSettings(PosSettings newSettings) async {
    _settings = newSettings;
    await _prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
    notifyListeners();
  }
}
