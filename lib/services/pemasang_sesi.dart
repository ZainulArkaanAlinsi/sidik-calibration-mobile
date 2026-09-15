import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pemasangan APK lewat `PackageInstaller` Android (sisi native:
/// `android/app/src/main/kotlin/com/ptsidik/kalibrasi/PemasangSesi.kt`).
///
/// ## Kenapa ada, di samping `open_filex`
///
/// `open_filex` membuka APK ke layar pemasang sistem: SELALU minta ketukan, dan
/// yang tercatat sebagai pemasang aplikasinya tetap pemasang sistem. Android
/// 12+ hanya mengizinkan pemutakhiran tanpa ketukan kalau pemasangnya aplikasi
/// ini sendiri. Maka pemasangan lewat jalur ini — sekali dengan ketukan — yang
/// membuka jalan buat rilis-rilis berikutnya masuk diam-diam.
abstract class PemasangSesi {
  /// Perangkat ini mengizinkan pemutakhiran berikutnya tanpa layar konfirmasi.
  Future<bool> bisaTanpaKetukan();

  /// `"dimulai"`, `"izin"` (Install unknown apps belum diizinkan),
  /// `"gagal: …"`, atau `null` kalau jalur ini tidak tersedia sama sekali
  /// (bukan Android, atau kanal native belum terpasang).
  Future<String?> pasang(String jalur, {required bool diam});
}

class PemasangSesiAndroid implements PemasangSesi {
  static const _kanal = MethodChannel('com.ptsidik.kalibrasi/pemasang');

  bool get _android => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> bisaTanpaKetukan() async {
    if (!_android) return false;

    try {
      return await _kanal.invokeMethod<bool>('bisaTanpaKetukan') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> pasang(String jalur, {required bool diam}) async {
    if (!_android) return null;

    try {
      return await _kanal.invokeMethod<String>('pasang', {
        'jalur': jalur,
        'diam': diam,
      });
    } on MissingPluginException {
      return null;
    } catch (e) {
      return 'gagal: $e';
    }
  }
}

/// Dipakai di luar Android dan di bawah `flutter test`: tidak pernah memasang.
class PemasangSesiMati implements PemasangSesi {
  const PemasangSesiMati();

  @override
  Future<bool> bisaTanpaKetukan() async => false;

  @override
  Future<String?> pasang(String jalur, {required bool diam}) async => null;
}

final pemasangSesiProvider = Provider<PemasangSesi>((ref) {
  if (kIsWeb) return const PemasangSesiMati();
  // Test yang menguji pemasangan diam menimpa provider ini terang-terangan.
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return const PemasangSesiMati();
  }

  return PemasangSesiAndroid();
});
