import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/pelapor_galat.dart';
import 'providers/versi_provider.dart';
import 'services/ketukan_push.dart';
import 'services/mock_store.dart';
import 'services/pembaru_windows.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cuma di build mock: pulihin riwayat sesi yang dibikin di pemakaian
  // sebelumnya. Tanpa ini semua lembar kerja yang diisi waktu ngetes ilang
  // begitu app ditutup — kelihatannya kayak data kehapus, padahal memang nggak
  // pernah disimpan. Lihat [MockStore].
  //
  // Di build asli nggak dipanggil sama sekali: riwayatnya datang dari backend,
  // dan nyimpen salinan lokal di sini cuma bikin dua sumber kebenaran.
  if (AppConfig.useMock) {
    await MockStore.instance.pulihkan(PenyimpanPrefs());
  }

  // Firebase dinyalain SEBELUM `runApp`, dan kegagalannya sengaja didiamkan.
  //
  // Dia cuma dibutuhin buat satu hal: push waktu aplikasi ketutup total. Kalau
  // inisialisasinya gagal — HP tanpa layanan Google Play, `google-services.json`
  // belum disalin di mesin yang lagi ngoding, atau proyeknya salah setel — yang
  // hilang cuma kabar di keadaan itu. Melempar di sini berarti aplikasi kalibrasi
  // nggak bisa dibuka sama sekali gara-gara layanan notifikasi, dan itu jauh
  // lebih parah daripada notifikasi yang nggak nongol.
  //
  // Desktop dilewat: `firebase_messaging` nggak jalan di situ, dan panel admin
  // sudah dikabari lewat websocket Reverb selama aplikasinya kebuka.
  final firebaseHidup = await _nyalakanFirebase();

  // Galat yang lolos dari semua `try` dilaporkan (tanpa isi data) lalu
  // aplikasinya JALAN TERUS; widget yang gagal dibangun tampil sebagai kartu
  // ramah. Lihat [pasangPenangkapGalat].
  pasangPenangkapGalat(pelapor: await _pelaporGalat(firebaseHidup));

  // Pembaruan Windows yang sudah diunduh di pembukaan sebelumnya dipasang di
  // sini, SEBELUM jendela digambar: skrip pemasangnya menunggu proses ini mati
  // lalu menimpa folder instalasi. Lihat [PembaruWindows].
  final pembaru = await _pembaruWindows();
  if (pembaru != null && await pembaru.terapkanKalauSiap()) exit(0);

  runApp(
    ProviderScope(
      overrides: [
        // Bannernya ("versi X siap — mulai ulang") membaca pembaru yang sama.
        if (pembaru != null) pembaruWindowsProvider.overrideWithValue(pembaru),
      ],
      child: const SidikApp(),
    ),
  );

  pembaru?.mulaiCekBerkala();
}

Future<PembaruWindows?> _pembaruWindows() async {
  if (AppConfig.useMock || kIsWeb || !Platform.isWindows) return null;

  try {
    return await PembaruWindows.untukAplikasiIni();
  } catch (e) {
    // Aplikasi kalibrasi tetap harus bisa dibuka walau pembaruannya gagal
    // disiapkan — alasan yang sama dengan Firebase di atas.
    debugPrint('Pembaru Windows nggak nyala: $e');
    return null;
  }
}

/// `true` = Firebase hidup (dipakai juga untuk memutuskan Crashlytics).
Future<bool> _nyalakanFirebase() async {
  if (AppConfig.useMock) return false;
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase nggak nyala: $e');
    return false;
  }

  try {
    // Ketukan pada push — termasuk yang MENYALAKAN aplikasi dari keadaan mati.
    // Dipasang di sini, sesudah Firebase hidup dan sebelum `runApp`, karena
    // `getInitialMessage()` cuma bisa dibaca sekali.
    await KetukanPush.pasang();
  } catch (e) {
    debugPrint('Ketukan push nggak terpasang: $e');
  }
  return true;
}

/// Crashlytics cuma di build RILIS dengan Firebase hidup. Debug/profile
/// mematikan pengumpulannya secara eksplisit supaya crash waktu ngoding tidak
/// mencemari laporan HP teknisi. Gagal menyalakan = tetap jalan, tanpa laporan.
Future<PelaporGalat?> _pelaporGalat(bool firebaseHidup) async {
  if (!firebaseHidup) return null;

  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    return kReleaseMode ? PelaporGalatCrashlytics() : null;
  } catch (e) {
    debugPrint('Crashlytics nggak nyala: $e');
    return null;
  }
}
