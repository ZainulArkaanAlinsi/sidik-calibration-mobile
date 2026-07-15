import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bahasa aktif aplikasi. Default **Indonesia** — mayoritas teknisi lapangan
/// berbahasa Indonesia; Inggris disediakan buat calon klien/investor.
///
/// Pilihan bahasa dipersist lewat `SharedPreferences` biar nggak balik ke
/// default tiap app dibuka. Kalau plugin-nya nggak ada (mis. di widget test),
/// semua akses storage ditelan diam-diam dan locale tetap di default ID —
/// jadi test nggak perlu nyetel mock storage.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'locale_code';
  static const _default = Locale('id');
  static const _supported = {'id', 'en'};

  @override
  Locale build() {
    // Muat pilihan tersimpan di background; sampai kelar, pakai default.
    _muat();
    return _default;
  }

  Future<void> _muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kode = prefs.getString(_key);
      if (kode != null && _supported.contains(kode) && kode != state.languageCode) {
        state = Locale(kode);
      }
    } catch (_) {
      // Plugin nggak tersedia / gagal baca → biarin default.
    }
  }

  /// Set bahasa eksplisit (dipakai switcher). Diabaikan kalau bukan bahasa
  /// yang didukung.
  Future<void> setLocale(Locale locale) async {
    if (!_supported.contains(locale.languageCode)) return;
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.languageCode);
    } catch (_) {
      // Gagal nyimpen bukan alasan buat nggak ganti bahasa di sesi ini.
    }
  }

  /// Toggle ID ↔ EN.
  Future<void> toggle() =>
      setLocale(state.languageCode == 'id' ? const Locale('en') : _default);
}
