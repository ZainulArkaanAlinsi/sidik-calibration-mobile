import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/worksheet_template.dart';
import '../services/jenis_lembar.dart';
import '../services/layout/detektor_layout.dart';
import '../services/layout/detektor_layout_ocrkit.dart';
import '../services/layout/model_layout.dart';
import '../services/layout/permukaan_ocr_kit.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'worksheet_scan_provider.dart';

/// Layout detection hanya Android (`flutter_ocr_kit` tidak punya Windows;
/// iOS/web di luar cakupan). Lewat provider supaya test bisa memaksa kedua
/// sisi tanpa bergantung pada mesin yang menjalankannya.
final layoutDidukungPlatformProvider = Provider<bool>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;

  return Platform.isAndroid;
});

/// Pengelola model: unduh sekali ke direktori dukungan aplikasi (privat,
/// tidak dibersihkan sistem seperti cache), sha256 dikunci di
/// `SpesifikasiModelLayout.ppDocLayoutL`.
final pengelolaModelLayoutProvider = Provider<PengelolaModelLayout>((ref) {
  final klien = http.Client();
  ref.onDispose(klien.close);

  return PengelolaModelLayout(
    klien: klien,
    direktori: () async {
      final dasar = await getApplicationSupportDirectory();

      return Directory('${dasar.path}/model_layout');
    },
  );
});

/// Detektor yang dipakai alur pindai. Di luar Android: [DetektorLayoutTakTersedia]
/// (alur langsung memakai jalur ML Kit yang ada, tanpa pesan galat).
final detektorLayoutProvider = Provider<DetektorLayout>((ref) {
  if (!ref.watch(layoutDidukungPlatformProvider)) {
    return const DetektorLayoutTakTersedia();
  }

  return DetektorLayoutOcrKit(
    model: ref.watch(pengelolaModelLayoutProvider),
    mesin: const MesinLayoutIsolate(PermukaanOcrKitAsli.new),
    direktoriSementara: getTemporaryDirectory,
    platformDidukung: true,
  );
});

/// `true` bila terhubung lewat WiFi/Ethernet (unduhan 123 MB aman tanpa
/// bertanya). Provider fungsi supaya test dapat menggantinya.
final jaringanTakBerbayarProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final hasil = await Connectivity().checkConnectivity();

    return hasil.contains(ConnectivityResult.wifi) ||
        hasil.contains(ConnectivityResult.ethernet);
  },
);

/// Formulir yang dikenal server (`GET /worksheet-templates`), bahan
/// `detectWorksheetType`. Gagal/tanpa token -> dilempar; pemanggil
/// memperlakukannya sebagai "tidak ada petunjuk".
final formulirDikenalProvider = FutureProvider<List<FormulirDikenal>>((
  ref,
) async {
  ref.watch(authProvider);

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();

  final daftar = await ref
      .read(worksheetScanServiceProvider)
      .daftarTemplate(token);

  return [for (final WorksheetTemplate t in daftar) formulirDikenalDari(t)];
}, retry: (retryCount, error) => null);
