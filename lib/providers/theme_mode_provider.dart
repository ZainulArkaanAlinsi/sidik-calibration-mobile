import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode tema aplikasi. Default **ikut sistem HP**, tapi user bisa override
/// lewat toggle "Dark Mode" di layar auth (seperti gambar acuan neumorphism).
///
/// Pilihan dipersist via `SharedPreferences`. Kalau plugin-nya nggak ada
/// (widget test), akses storage ditelan diam-diam → tetap di default.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _muat();
    return ThemeMode.system;
  }

  Future<void> _muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Plugin nggak tersedia → biarin default.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }

  /// Toggle terang ↔ gelap. [gelapSekarang] = brightness efektif yang lagi
  /// tampil (dihitung dari context di widget), biar toggle dari mode `system`
  /// pun mendarat ke lawan yang benar.
  Future<void> toggle({required bool gelapSekarang}) =>
      setMode(gelapSekarang ? ThemeMode.light : ThemeMode.dark);
}
