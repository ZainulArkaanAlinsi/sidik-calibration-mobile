import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/ph_calibration_draft.dart';

/// Ngunci bentuk payload pH ke kontrak backend (handoff "Kalibrasi pH 100%").
///
/// Dua hal yang gampang meleset diam-diam di sini — nggak ada error, cuma
/// angkanya salah — jadi dua-duanya dijaga test:
///
/// 1. **`titik_ukur` itu nilai buffer yang UDAH dikoreksi suhu**, bukan angka
///    bulat 4/7/10 dan bukan nilai mentah sertifikat. Kalau yang mentah
///    kekirim, koreksi suhunya ilang dari perhitungan.
/// 2. **`suhu` harus sejajar index sama `pembacaan`.** Deret yang bolong bikin
///    suhu nempel ke baris yang salah — lebih buruk daripada nggak ngirim suhu
///    sama sekali, karena angkanya kelihatan wajar.
void main() {
  /// Angka-angkanya diambil dari sesi asli 012-CAL-524 yang direproduksi
  /// backend, bukan karangan — biar kalau bentuknya berubah, yang kelihatan
  /// bareng adalah nilai yang beneran dipakai.
  const acuan = [
    ('4', 4.009244572, 4.0092252, 4),
    ('7', 6.9889072, 6.9889000, 3),
    ('10', 9.9789000, 9.9788500, 5),
  ];

  PhCalibrationDraft draftLengkap() {
    final points = <PhBufferPoint>[];
    for (final (label, titikUkur, titikUkurSebelum, standarId) in acuan) {
      final titik = PhBufferPoint(
        label: label,
        titikUkur: titikUkur,
        titikUkurSebelum: titikUkurSebelum,
        standardId: standarId,
      );
      for (var i = 0; i < 5; i++) {
        titik.sesudahAdjustment[i] = PhReading(
          ph: titikUkur,
          suhu: 22.2 - (i * 0.05),
        );
        titik.sebelumAdjustment[i] = PhReading(ph: titikUkur + 0.1, suhu: 22.2);
      }
      points.add(titik);
    }

    return PhCalibrationDraft(
      equipmentId: 5,
      standardId: 12,
      tanggalKalibrasi: DateTime(2026, 7, 20),
      thermohygroId: 'TH-3',
      points: points,
    )
      ..suhuAwal = 21.3
      ..suhuAkhir = 21.5
      ..kelembabanAwal = 53
      ..kelembabanAkhir = 56
      ..suhuKoreksi = -0.43
      ..kelembabanKoreksi = -2.55
      ..suhuUStd = 1.7
      ..kelembabanUStd = 4.8;
  }

  Map<String, dynamic> titikPertama(PhCalibrationDraft draft) {
    final json = draft.toGenericDraft(clientRequestId: 'uji').toJson();
    return (json['measurements'] as List).first as Map<String, dynamic>;
  }

  test('titik_ukur dikirim, dan isinya nilai TERKOREKSI SUHU', () {
    final titik = titikPertama(draftLengkap());

    expect(
      titik['titik_ukur'],
      4.009244572,
      reason:
          'Ini nilai buffer sesudah koreksi suhu. Angka bulat 4 atau nilai '
          'mentah sertifikat 3.99 di sini bikin hasilnya meleset tanpa error.',
    );
    expect(titik['titik_ukur_sebelum'], 4.0092252);
    expect(titik['satuan'], 'pH');
    expect(titik['standard_id'], 4);
  });

  test('suhu per baris kekirim, sejajar index sama pembacaan', () {
    final titik = titikPertama(draftLengkap());

    expect(titik['suhu'], isA<List<dynamic>>());
    expect(
      (titik['suhu'] as List).length,
      (titik['pembacaan'] as List).length,
      reason: 'Panjang beda = suhu nempel ke baris yang salah.',
    );
    expect(
      (titik['suhu_sebelum'] as List).length,
      (titik['pembacaan_sebelum'] as List).length,
    );
  });

  test('baris kosong dibuang, bukan dikirim sebagai 0', () {
    final draft = draftLengkap();
    // Teknisi baru ngisi 3 dari 5 baris.
    draft.points[0].sesudahAdjustment[3] = null;
    draft.points[0].sesudahAdjustment[4] = null;

    final titik = titikPertama(draft);

    expect((titik['pembacaan'] as List).length, 3);
    expect((titik['suhu'] as List).length, 3);
  });

  test('satu suhu kosong → seluruh deret suhu nggak dikirim', () {
    final draft = draftLengkap();
    // Baris ke-3 pH-nya keisi tapi suhunya belum.
    draft.points[0].sesudahAdjustment[2] = const PhReading(ph: 4.01);

    final titik = titikPertama(draft);

    expect(
      (titik['pembacaan'] as List).length,
      5,
      reason: 'Pembacaan pH-nya tetap sah walau suhunya nggak dicatat.',
    );
    expect(
      titik.containsKey('suhu'),
      isFalse,
      reason:
          '`suhu` opsional di backend. Ngirim deret yang bolong bikin suhu '
          'nempel ke baris yang salah — mending nggak dikirim sama sekali.',
    );
  });

  test('kondisi lingkungan dikirim awal & akhir, rata-rata diserahkan server', () {
    final json = draftLengkap().toGenericDraft(clientRequestId: 'uji').toJson();

    expect(json['suhu_ruang_awal'], 21.3);
    expect(json['suhu_ruang_akhir'], 21.5);
    expect(json['kelembaban_awal'], 53);
    expect(json['kelembaban_akhir'], 56);
    expect(json['suhu_ruang_koreksi'], -0.43);
    expect(json['kelembaban_koreksi'], -2.55);
    expect(json['suhu_ruang_u_std'], 1.7);
    expect(json['kelembaban_u_std'], 4.8);
    expect(json['thermohygro'], 'TH-3');

    // Server yang ngerata-ratain DAN nurunin U95% lingkungan dari angka di
    // atas. Kalau mobile ikut ngirim rata-rata, ada dua sumber buat angka yang
    // sama dan nggak ada yang tahu mana yang menang waktu keduanya beda.
    expect(json.containsKey('suhu_ruang'), isFalse);
    expect(json.containsKey('kelembaban'), isFalse);
  });
}
