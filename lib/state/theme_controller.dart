import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Day / night visual mode, persisted across visits.
class ThemeController extends ChangeNotifier {
  static const _key = 'skylark_night';

  ThemeController._() {
    night = web.window.localStorage.getItem(_key) == '1';
  }

  static final ThemeController instance = ThemeController._();

  bool night = false;

  void setNight(bool v) {
    if (night == v) return;
    night = v;
    web.window.localStorage.setItem(_key, v ? '1' : '0');
    notifyListeners();
  }
}
