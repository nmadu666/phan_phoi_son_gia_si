import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to manage the application's global, non-user-specific state.
///
/// It can handle both volatile (in-memory) and persisted (saved to local storage) state.
/// Use this for session-specific data like the currently selected branch,
/// which might differ from a user's default settings but should be remembered
/// across app restarts on the same device.
class AppStateService with ChangeNotifier {
  late SharedPreferences _prefs;

  // In-memory cache for all state values.
  final Map<String, dynamic> _state = {};

  // A set of keys that should be persisted to local storage.
  final Set<String> _persistedKeys = {
    selectedBranchIdKey,
    // Add other keys here that you want to persist.
  };

  // --- State Keys ---
  /// Key for the currently selected KiotViet branch ID. This is persisted locally.
  static const String selectedBranchIdKey = 'selectedBranchId';

  /// Indicates if the service has finished loading persisted state.
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes the service by loading SharedPreferences and persisted state.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPersistedState();
    _isInitialized = true;
    // Notify listeners that initialization is complete and state is ready.
    notifyListeners();
  }

  /// Loads all keys marked as persisted from SharedPreferences into the in-memory state.
  Future<void> _loadPersistedState() async {
    for (final key in _persistedKeys) {
      final value = _prefs.get(key);
      if (value != null) {
        _state[key] = value;
      }
    }
  }

  /// Retrieves a state value by its key.
  ///
  /// Returns `null` if the key does not exist.
  T? get<T>(String key) {
    return _state[key] as T?;
  }

  /// Sets a state value for a given key.
  ///
  /// [key]: The key for the state variable.
  /// [value]: The new value.
  /// [persisted]: If `true`, the key-value pair will be saved to local storage.
  ///              If `false`, it will only exist in memory for the current session.
  ///
  /// Note: For a key to be persisted, it must also be added to the `_persistedKeys` set.
  Future<void> set(String key, dynamic value, {bool persisted = false}) async {
    _state[key] = value;

    if (persisted && _persistedKeys.contains(key)) {
      await _saveToPrefs(key, value);
    }

    notifyListeners();
  }

  /// Saves a key-value pair to SharedPreferences based on its type.
  Future<void> _saveToPrefs(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else if (value == null) {
      await _prefs.remove(key);
    } else {
      // For complex types, consider JSON serialization.
      if (kDebugMode) {
        print(
          'AppStateService: Cannot persist value of type ${value.runtimeType} for key "$key".',
        );
      }
    }
  }
}
