import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';

/// Ngunci pembacaan respons `GET /api/calibrations/{id}` versi pH.
///
/// Mock di `history_service.dart` ngerakit [CalibrationDetail] langsung sebagai
/// objek, jadi jalur `fromJson`-nya nggak pernah kelewatan di test layar. Di
/// sini JSON-nya disuapin apa adanya — kalau backend ganti nama field, yang
/// gagal test ini, bukan layar yang diam-diam nampilin "—".
void main() {
  /// Potongan respons sesi 012-CAL-524, disalin dari handoff backend.
  Map<String, dynamic> responsPh() => {
    'id': 3,
    'nomor_sesi': 'KAL/2024/05/0012',
    'status': 'disetujui',
    'tanggal_kalibrasi': '2024-05-26T00:00:00Z',
    'equipment': {'nama_alat': 'pH Meter Mettler Toledo'},
    'teknisi': {'nama': 'Andi'},
    'hasil': {'keputusan': 'PASS'},
    'suhu_ruang': 21.4,
    'kelembaban': 54.5,
    'kondisi_lingkungan': {
      'suhu': {
        'awal': 21.3,
        'akhir': 21.5,
        'rata_rata': 21.4,
        'koreksi': -0.43,
        'nilai_terkoreksi': 20.97,
        'u95': 1.7117,
        'satuan': '°C',
      },
      'kelembaban': {
        'awal': 53,
        'akhir': 56,
        'rata_rata': 54.5,
        'koreksi': -2.55,
        'nilai_terkoreksi': 51.95,
        'u95': 5.6604,
        'satuan': '%RH',
      },
      'thermohygro': 'TH-3',
    },
    'titik': [
      {
        'titik_ke': 1,
        'titik_ukur': 4.0092,
        'rata_rata': 4.0,
        'error': -0.0092,
        'koreksi': 0.0092,
        'standar_deviasi': 0,
        'ketidakpastian_diperluas': 0.023432,
        'faktor_cakupan_k': 1.968535,
        'keputusan': 'PASS',
        'metode': 'SIDIK-IK-CAL-0506',
        'type_b_components': [
          {
            'sumber': 'ketidakpastian_standar',
            'keterangan': 'Sertifikat standar pH Buffer Solution 4',
            'distribusi': 'normal',
            'nilai': 0.01,
          },
        ],
      },
    ],
    'titik_sebelum': [
      {
        'titik_ke': 1,
        'titik_ukur': 4.0092252,
        'rata_rata': 4.232,
        'koreksi': 0.2228,
        'standar_deviasi': 0.4293,
        'jumlah_pengulangan': 5,
      },
    ],
    'pembacaan_mentah': [
      {
        'id': 1,
        'titik_ke': 1,
        'pembacaan_ke': 1,
        'tahap': 'sesudah_adjustment',
        'pembacaan': 4.0,
        'suhu': 22.2,
        'input_source': 'manual',
        'is_verified': true,
      },
      {
        'id': 2,
        'titik_ke': 1,
        'pembacaan_ke': 1,
        'tahap': 'sebelum_adjustment',
        'pembacaan': 4.04,
        'suhu': 22.2,
        'input_source': 'manual',
        'is_verified': true,
      },
    ],
    'perlu_verifikasi': false,
  };

  test('kondisi lingkungan kebaca lengkap sampai U95%', () {
    final detail = CalibrationDetail.fromJson(responsPh());
    final suhu = detail.kondisiLingkungan!.suhu!;

    expect(suhu.awal, 21.3);
    expect(suhu.akhir, 21.5);
    expect(suhu.rataRata, 21.4);
    expect(suhu.koreksi, -0.43);
    expect(suhu.nilaiTerkoreksi, 20.97);
    expect(suhu.u95, 1.7117);
    expect(suhu.satuan, '°C');

    expect(detail.kondisiLingkungan!.kelembaban!.u95, 5.6604);
    expect(detail.kondisiLingkungan!.thermohygro, 'TH-3');
  });

  test('pembacaan mentah kepisah per tahap, dan bawa suhu larutan', () {
    final detail = CalibrationDetail.fromJson(responsPh());

    final sesudah = detail.pembacaanMentah
        .where((p) => p.tahap == TahapPembacaan.sesudahAdjustment)
        .toList();
    final sebelum = detail.pembacaanMentah
        .where((p) => p.tahap == TahapPembacaan.sebelumAdjustment)
        .toList();

    expect(sesudah, hasLength(1));
    expect(sebelum, hasLength(1));
    expect(sesudah.single.pembacaan, 4.0);
    expect(sebelum.single.pembacaan, 4.04);
    expect(sesudah.single.suhu, 22.2);
  });

  test('ringkasan as-found kebaca terpisah dari hasil yang disertifikasi', () {
    final detail = CalibrationDetail.fromJson(responsPh());

    expect(detail.titikSebelum, hasLength(1));
    expect(detail.titikSebelum.single.rataRata, 4.232);
    expect(detail.titikSebelum.single.standarDeviasi, 0.4293);
    expect(detail.titikSebelum.single.jumlahPengulangan, 5);

    // Yang masuk sertifikat tetap yang di `titik`, bukan yang as-found.
    expect(detail.titik.single.rataRata, 4.0);
    expect(detail.titik.single.metode, 'SIDIK-IK-CAL-0506');
    expect(detail.titik.single.faktorCakupanK, 1.968535);
  });

  test('respons alat non-pH tanpa field baru tetap kebaca', () {
    // Sesi lama cuma punya satu angka suhu/kelembaban dan nggak punya
    // `kondisi_lingkungan`, `titik_sebelum`, atau `tahap` sama sekali.
    final detail = CalibrationDetail.fromJson({
      'id': 9,
      'status': 'disetujui',
      'tanggal_kalibrasi': '2026-07-20T00:00:00Z',
      'equipment': {'nama_alat': 'Jangka Sorong Mitutoyo'},
      'teknisi': {'nama': 'Andi'},
      'suhu_ruang': 23.5,
      'kelembaban': 55,
      'pembacaan_mentah': [
        {
          'id': 1,
          'titik_ke': 1,
          'pembacaan_ke': 1,
          'pembacaan': 50.02,
          'input_source': 'manual',
          'is_verified': true,
        },
      ],
    });

    expect(detail.kondisiLingkungan, isNull);
    expect(detail.titikSebelum, isEmpty);
    expect(detail.suhuRuang, 23.5);
    expect(detail.perluVerifikasi, isFalse);

    // Tanpa `tahap`, barisnya dianggap tahap yang disertifikasi — kalau nggak,
    // pembacaan alat non-pH ilang dari layar detail.
    expect(
      detail.pembacaanMentah.single.tahap,
      TahapPembacaan.sesudahAdjustment,
    );
    expect(detail.pembacaanMentah.single.suhu, isNull);
  });

  group('MAX STDEV', () {
    /// Angka STDEV asli dari worksheet `DATA HASIL KALIBRASI` sesi 012-CAL-524
    /// — tiga buffer, tabel before & after adjustment. Numpang fixture pH yang
    /// udah lengkap di atas, cuma titiknya yang ditimpa.
    Map<String, dynamic> responsTigaTitik() => {
      ...responsPh(),
      'titik': [
        {'titik_ke': 1, 'standar_deviasi': 0.000},
        {'titik_ke': 2, 'standar_deviasi': 0.005},
        {'titik_ke': 3, 'standar_deviasi': 0.000},
      ],
      'titik_sebelum': [
        {'titik_ke': 1, 'standar_deviasi': 0.018},
        {'titik_ke': 2, 'standar_deviasi': 0.014},
        {'titik_ke': 3, 'standar_deviasi': 0.144},
      ],
    };

    test('diambil dari sebaran terburuk, bukan dari titik terakhir', () {
      final detail = CalibrationDetail.fromJson(responsTigaTitik());

      // Sesuai kotak MAX STDEV di worksheet: 0,005 (as-left) & 0,144
      // (as-found). Kalau yang keambil titik terakhir, as-found bakal jadi
      // 0,144 secara kebetulan tapi as-left salah jadi 0,000.
      expect(detail.maxStdev, 0.005);
      expect(detail.maxStdevSebelum, 0.144);
    });

    test('as-found yang jelek nggak nyampur ke angka as-left', () {
      final detail = CalibrationDetail.fromJson(responsTigaTitik());

      // Yang disertifikasi cuma as-left. Kalau dua tabel digabung dulu baru
      // di-`max()`, angkanya jadi 0,144 — sesi rapi kebaca kayak sesi kacau.
      expect(detail.maxStdev, isNot(detail.maxStdevSebelum));
    });

    test('sesi yang belum dihitung backend -> null, bukan 0', () {
      final detail = CalibrationDetail.fromJson({
        ...responsPh(),
        'status': 'draft',
        'titik': <dynamic>[],
        'titik_sebelum': <dynamic>[],
      });

      // `0` bakal kebaca "sebarannya nol" alias sempurna — padahal datanya
      // belum ada sama sekali.
      expect(detail.maxStdev, isNull);
      expect(detail.maxStdevSebelum, isNull);
    });
  });
}
