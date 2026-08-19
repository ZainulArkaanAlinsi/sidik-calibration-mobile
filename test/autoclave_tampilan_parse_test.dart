import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';

/// Round-trip lewat JSON biar map-nya `Map<String, dynamic>` persis kayak
/// respons API asli (literal `{}` di Dart itu `Map<dynamic,dynamic>` dan bikin
/// cast di model gagal — bukan bug model).
Map<String, dynamic> _json(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// Lapisan TAMPILAN Autoklaf baca hasil dari dua sumber: snapshot sertifikat
/// (`snapshot.autoclave`) dan detail sesi tersimpan (`detail.autoclave`).
/// Dua-duanya bentuknya `hasil_autoclave` mentah dari backend — test ini
/// mastiin keduanya keparse & mendarat di field yang benar (kalau nggak,
/// sesi/sertifikat Autoklaf tampil sebagai tabel kosong di HP).
void main() {
  final ac = {
    'set_point': 121.0,
    'suhu': {
      'indikator_rata': 121.0,
      'sensor': [
        {'no': 1, 'standar_terkoreksi': 121.396, 'koreksi': 0.396, 'delta_t': 0.02},
      ],
      'kestabilan': 0.045,
      'keseragaman': 0.464,
      'variasi': 0.10,
      'k': 1.9713602363081708,
      'u95': 0.4419439029528431,
    },
    'tekanan': {
      'satuan': 'MPa',
      'uut_setting': 0.112,
      'standar_terkoreksi': 0.1231,
      'koreksi': 0.0111,
      'u95': 0.0059,
      'k': 2.085963447265865,
    },
  };

  test('CertificateSnapshot.autoclave keparse dari key autoclave', () {
    final snap = CertificateSnapshot.fromJson(_json({
      'header': {},
      'hasil': [],
      'catatan': [],
      'standar_digunakan': [],
      'footer': {},
      'autoclave': ac,
    }));

    expect(snap.autoclave, isNotNull);
    expect(snap.hasil, isEmpty);
    expect(snap.autoclave!.suhu!.keseragaman, closeTo(0.464, 1e-9));
    expect(snap.autoclave!.tekanan!.u95, closeTo(0.0059, 1e-9));
  });

  test('CertificateSnapshot alat lain: autoclave null', () {
    final snap = CertificateSnapshot.fromJson(_json({
      'header': {}, 'hasil': [], 'catatan': [], 'standar_digunakan': [], 'footer': {},
    }));
    expect(snap.autoclave, isNull);
  });

  test('CalibrationDetail.autoclave keparse dari hasil_autoclave', () {
    final detail = CalibrationDetail.fromJson(_json({
      'id': 7,
      'tanggal_kalibrasi': '2026-08-19',
      'status': 'menunggu_approval',
      'hasil_autoclave': ac,
      'titik': [],
    }));

    expect(detail.autoclave, isNotNull);
    expect(detail.titik, isEmpty);
    expect(detail.autoclave!.suhu!.u95, closeTo(0.4419439, 1e-6));
    expect(detail.autoclave!.tekanan!.koreksi, closeTo(0.0111, 1e-9));
  });
}
