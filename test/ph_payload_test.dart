import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/ph_calibration_draft.dart';

/// Ngunci bentuk payload pH.
///
/// Ini gampang banget balik ke bentuk lama tanpa ketahuan: `titik_ukur` itu
/// field yang wajar dikirim buat semua alat lain, jadi orang yang nggak tahu
/// konteksnya bakal nambahin balik dengan niat baik. Kalau kekirim, backend
/// bakal pakai nilai tetap itu dan **ngabaikan koreksi suhu** — hasilnya
/// meleset diam-diam, nggak error, cuma angkanya salah.
void main() {
  PhCalibrationDraft draftTitikPenuh() {
    final draft = PhCalibrationDraft(
      equipmentId: 5,
      standardId: 1,
      tanggalKalibrasi: DateTime(2026, 7, 20),
      thermohygroId: 'TH-3',
    )
      ..suhuAwal = 21.4
      ..suhuAkhir = 21.5
      ..kelembabanAwal = 53
      ..kelembabanAkhir = 56;

    // Ketiga titik diisi, sama kayak alur asli — form nolak submit kalau ada
    // titik yang standar buffernya belum dipilih.
    const nominal = [('4', 3.99, 3), ('7', 6.9889, 4), ('10', 9.9789, 5)];
    for (var t = 0; t < nominal.length; t++) {
      final (label, nilai, standarId) = nominal[t];
      final titik = PhBufferPoint(
        label: label,
        nilaiStandar: nilai,
        standardId: standarId,
      );
      for (var i = 0; i < 5; i++) {
        titik.sesudahAdjustment[i] = PhReading(
          ph: nilai,
          suhu: 22.2 - (i * 0.05),
        );
        titik.sebelumAdjustment[i] = PhReading(ph: nilai + 0.1, suhu: 22.2);
      }
      draft.points[t] = titik;
    }

    return draft;
  }

  test('pH kirim suhu_larutan, BUKAN titik_ukur', () {
    final json = draftTitikPenuh()
        .toGenericDraft(clientRequestId: 'uji-1')
        .toJson();

    final titik = (json['measurements'] as List).first as Map<String, dynamic>;

    expect(
      titik.containsKey('titik_ukur'),
      isFalse,
      reason:
          'Nilai acuan buffer pH geser ikut suhu — backend yang nurunin dari '
          'kurva sertifikat. Kalau titik_ukur kekirim, koreksi suhunya '
          'diabaikan dan hasilnya meleset tanpa error.',
    );
    expect(titik['suhu_larutan'], isA<List<dynamic>>());
    expect(titik['satuan'], 'pH');
    expect(titik['standard_id'], 3);
  });

  test('jumlah suhu_larutan sama persis dengan jumlah pembacaan', () {
    final json = draftTitikPenuh()
        .toGenericDraft(clientRequestId: 'uji-2')
        .toJson();

    final titik = (json['measurements'] as List).first as Map<String, dynamic>;

    expect(
      (titik['suhu_larutan'] as List).length,
      (titik['pembacaan'] as List).length,
      reason: 'Panjangnya beda = backend nolak 422.',
    );
  });

  test('baris yang cuma keisi separuh nggak bikin dua deret beda panjang', () {
    final draft = draftTitikPenuh();
    // Teknisi baru ngisi 3 dari 5 baris — sisanya masih null.
    draft.points[0].sesudahAdjustment[3] = null;
    draft.points[0].sesudahAdjustment[4] = null;

    final json = draft.toGenericDraft(clientRequestId: 'uji-3').toJson();
    final titik = (json['measurements'] as List).first as Map<String, dynamic>;

    expect((titik['pembacaan'] as List).length, 3);
    expect((titik['suhu_larutan'] as List).length, 3);
  });
}
