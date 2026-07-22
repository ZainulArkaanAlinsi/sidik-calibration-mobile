import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/calibration/live_scan_screen.dart';

import '../services/ocr_service.dart';
import '../services/photo_source.dart';
import '../services/worksheet_ocr.dart';

/// Sumber foto buat semua alur scan. Di-override di test pakai
/// [MockSumberFoto] biar kameranya nggak pernah kepanggil.
final sumberFotoProvider = Provider<SumberFoto>(
  (ref) => const KameraSumberFoto(),
);

/// OCR layar pH meter (per sel pembacaan).
///
/// `TextRecognizer` bawaan ML Kit megang resource native, jadi ditutup lewat
/// `onDispose` — bukan ditutup manual di layar. Waktu servicenya masih di-`new`
/// di dalam widget, tiap tap tombol bikin instance baru dan gampang bocor
/// kalau layarnya ditutup pas OCR masih jalan.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.dispose);
  return service;
});

/// Buka pemindai langsung, balikin tabel yang dipilih teknisi (`null` = mundur).
///
/// Dilewatin provider **supaya alur gerbangnya tetap bisa di-widget-test**.
/// `LiveScanScreen` beneran nyalain kamera perangkat — di test itu mustahil,
/// dan kalau dipanggil langsung, satu-satunya bagian yang bisa diuji tinggal
/// parser angkanya lagi. Persis masalah yang baru aja dibenerin.
typedef ScanLangsung = Future<HasilTabelOcr?> Function(
  BuildContext context, {
  int jumlahTitik,
});

final scanLangsungProvider = Provider<ScanLangsung>((ref) {
  return (context, {int jumlahTitik = 3}) {
    return Navigator.of(context).push<HasilTabelOcr>(
      MaterialPageRoute(
        builder: (_) => LiveScanScreen(jumlahTitik: jumlahTitik),
      ),
    );
  };
});

/// OCR satu tabel worksheet penuh (3 buffer × 5 pengulangan sekaligus).
final worksheetOcrServiceProvider = Provider<WorksheetOcrService>((ref) {
  final service = MlKitWorksheetOcrService();
  ref.onDispose(service.dispose);
  return service;
});
