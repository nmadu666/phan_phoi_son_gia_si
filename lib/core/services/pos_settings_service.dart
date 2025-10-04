import 'package:flutter/foundation.dart';
import 'package:phan_phoi_son_gia_si/core/models/pos_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to manage user-configurable settings for the POS screen.
///
/// It uses `shared_preferences` for persistence.
class PosSettingsService with ChangeNotifier {
  static const _storageKey = 'pos_screen_settings';
  late PosSettings _settings;

  PosSettings get settings => _settings;

  PosSettingsService() {
    // Initialize with default settings and then load from storage.
    _settings = PosSettings();
    loadSettings();
  }

  /// Loads settings from persistent storage.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_storageKey);

    if (settingsJson != null) {
      try {
        _settings = PosSettings.fromJson(settingsJson);
      } catch (e) {
        debugPrint("Error loading POS settings, using defaults. Error: $e");
        _settings = PosSettings(); // Fallback to defaults on error
      }
    }
    notifyListeners();
  }

  /// Saves the current settings to persistent storage.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _settings.toJson());
  }

  /// Updates the settings and persists the changes.
  Future<void> updateSettings(PosSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }
}

