import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop dapat panel admin, HP dapat rangka lima tab.
///
/// **Dipatok ke platform, bukan ke lebar jendela.** Ini beda dari
/// `MainShell._lebarRail` yang sengaja ngikut lebar: di sana yang dipilih cuma
/// bentuk navigasi buat isi yang sama, jadi tablet landscape pantas dapat rail.
/// Di sini yang dipilih **aplikasi yang beda peruntukan** — desktop itu meja
/// kerja admin, HP itu alat lapangan teknisi. Ngikutin lebar bakal bikin panel
/// admin berubah jadi app HP cuma gara-gara jendelanya dikecilin, dan orang
/// kehilangan menu di tengah kerja.
///
/// Dibungkus provider (bukan `Platform.isWindows` ditembak langsung di widget)
/// supaya test bisa nimpa: tanpa ini, tiap widget test yang ngerender
/// [AuthGate] di mesin Windows bakal dapat panel desktop, termasuk test yang
/// nguji rangka HP.
final pakaiPanelDesktopProvider = Provider<bool>((ref) {
  // Di bawah `flutter test` **selalu** false. Tanpa ini, rangka yang keuji
  // ikut berubah tergantung mesin CI-nya: suite yang sama bakal ngerender
  // panel desktop di Windows dan rangka HP di Linux. Itu jenis ketidakpastian
  // yang sama kayak yang udah bikin golden merah bergantian antar-mesin.
  //
  // Test yang emang nguji panel desktop nimpa provider ini terang-terangan:
  // `pakaiPanelDesktopProvider.overrideWithValue(true)`.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;

  return Platform.isWindows || Platform.isMacOS;
});
