import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/pembaru_windows.dart';

import 'app.dart';
import 'inti/lingkungan_studio.dart';
import 'inti/penimpaan.dart';
import 'tema/font_studio.dart';

/// Titik masuk Sidik Studio.
///
/// Yang SENGAJA tidak ada di sini, beda dari `main.dart` app lapangan:
///  - `Firebase.initializeApp` / ketukan push — Studio tanpa push;
///  - pembaru APK — Studio di Android belum punya jalur rilis.
///
/// Pembaru WINDOWS ada (22 Okt 2026): mesinnya `PembaruWindows` paket
/// bersama, tapi membaca manifest Studio sendiri ([urlManifestStudio]) —
/// tidak pernah manifest app lapangan.
///  - `MockStore` — riwayat sesi mock milik alur lapangan.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sebelum frame pertama: layar bersama menulis nama font polos.
  await daftarkanAliasFont();

  // Build dev: alamat server yang disimpan di layar masuk (tablet lewat
  // Wi-Fi tanpa adb). Build rilis: selalu `null`, tidak dibaca.
  final alamatDev = await bacaAlamatServerDevAwal();

  // Pembaruan yang sudah terunduh di pembukaan sebelumnya dipasang SEBELUM
  // jendela digambar (pola yang sama dengan app lapangan).
  final pembaru = await _pembaruWindows();
  if (pembaru != null && await pembaru.terapkanKalauSiap()) exit(0);

  runApp(
    ProviderScope(
      overrides: [
        ...penimpaanStudio,
        ...penimpaanSesiStudio,
        alamatServerDevAwalProvider.overrideWithValue(alamatDev),
        if (pembaru != null) pembaruWindowsProvider.overrideWithValue(pembaru),
      ],
      child: const SidikStudioApp(),
    ),
  );

  pembaru?.mulaiCekBerkala();
}

/// Hanya build RILIS di Windows. Build debug/profil (`flutter run`) sengaja
/// dilewati: versinya `version:` pubspec yang selalu lebih tua dari rilis CI,
/// jadi pembaru akan menimpa folder build pengembang dengan paket rilis.
Future<PembaruWindows?> _pembaruWindows() async {
  if (!kReleaseMode || kIsWeb || !Platform.isWindows) return null;

  try {
    return await PembaruWindows.untukAplikasiIni(
      urlManifest: urlManifestStudio,
    );
  } catch (e) {
    // Studio tetap harus bisa dibuka walau pembaruannya gagal disiapkan.
    debugPrint('Pembaru Windows Studio tidak menyala: $e');
    return null;
  }
}
