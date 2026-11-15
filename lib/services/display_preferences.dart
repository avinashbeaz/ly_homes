import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayPreferences extends ChangeNotifier {
  DisplayPreferences({SharedPreferences? storage}) : _storage = storage {
    large = storage?.getBool('largeText') ?? false;
    reduceMotion = storage?.getBool('reduceMotion') ?? false;
    dark = storage?.getBool('darkAppearance') ?? false;
  }
  SharedPreferences? _storage;
  bool get persistent => _storage != null;
  static Future<DisplayPreferences> load() async {
    try {
      return DisplayPreferences(storage: await SharedPreferences.getInstance());
    } catch (_) {
      return DisplayPreferences();
    }
  }

  Future<void> _save(String key, bool value) async {
    try {
      await _storage?.setBool(key, value);
    } catch (_) {
      _storage = null;
      notifyListeners();
    }
  }

  bool large = false;
  bool reduceMotion = false;
  bool dark = false;
  Future<void> setLarge(bool value) async {
    large = value;
    notifyListeners();
    await _save('largeText', value);
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    await _save('reduceMotion', value);
  }

  Future<void> setDark(bool value) async {
    dark = value;
    notifyListeners();
    await _save('darkAppearance', value);
  }
}
