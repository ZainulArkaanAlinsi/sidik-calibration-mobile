import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'dekoder_ctc.dart';
import 'keputusan_sel.dart' show ambangJalurAwal;

/// Isi `meta.json` model pembaca angka — dibaca dan DIPERIKSA sebelum model
/// dipakai. Berkas contoh: `assets/models/ocr_angka_en.meta.json`.
class MetaModelOcr {
  const MetaModelOcr({
    required this.versi,
    required this.berkas,
    required this.sha256,
    required this.asalData,
    required this.buktiAkurasi,
    required this.kolom,
    required this.ambangJalur,
  });

  /// Nama + revisi model (mis. `en_PP-OCRv5_mobile_rec_onnx@3fafbc3b`).
  final String versi;

  /// Nama berkas model di sebelah meta (tanpa folder).
  final String berkas;
  final String sha256;

  /// Asal bobot model: `publik` (dilatih pihak lain, bukan dengan data kita).
  final String asalData;

  /// Asal BUKTI akurasi/ambang: `SINTETIS` sampai diukur pada foto nyata.
  final String buktiAkurasi;

  /// Indeks kelas keluaran model untuk `[blank, ...alfabet]`.
  final List<int> kolom;

  /// Ambang skor `jalur` yang dipilih untuk model ini.
  final double ambangJalur;

  bool get buktiSintetis => buktiAkurasi.toUpperCase() == 'SINTETIS';

  /// `null` bila bukan JSON, bagian wajib hilang, atau kolom tidak masuk akal.
  static MetaModelOcr? dari(String json) {
    try {
      final m = jsonDecode(json);
      if (m is! Map<String, dynamic>) return null;

      final kolom = (m['kolom'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList();
      final berkas = m['berkas'] as String?;
      final sha = (m['sha256'] as String?)?.toLowerCase();

      if (kolom == null ||
          kolom.length != DekoderCtc.alfabet.length + 1 ||
          kolom.toSet().length != kolom.length ||
          kolom.any((k) => k < 0) ||
          berkas == null ||
          berkas.isEmpty ||
          berkas.contains('/') ||
          berkas.contains(r'\') ||
          sha == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
        return null;
      }
      if (m['alfabet'] != null && m['alfabet'] != DekoderCtc.alfabet) {
        return null;
      }

      return MetaModelOcr(
        versi: m['versi'] as String? ?? '',
        berkas: berkas,
        sha256: sha,
        asalData: m['asal_data'] as String? ?? '',
        buktiAkurasi: m['bukti_akurasi'] as String? ?? '',
        kolom: kolom,
        ambangJalur: _jepitAmbang((m['ambang_jalur'] as num?)?.toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ambang dari berkas meta dijepit ke [ambangMin]..1: meta yang rusak atau
  /// diubah (mis. `0`) tidak boleh membuat semua bacaan lolos jadi usulan.
  static const ambangMin = 0.5;

  static double _jepitAmbang(double? v) {
    if (v == null || !v.isFinite) return ambangJalurAwal;

    return v.clamp(ambangMin, 1.0).toDouble();
  }

  /// Berkas model yang dimuat sama dengan yang dijanjikan meta?
  bool cocokDengan(Uint8List model) => sha256 == sha256Dari(model);
}

/// sha256 heksadesimal huruf kecil.
String sha256Dari(Uint8List b) => crypto.sha256.convert(b).toString();
