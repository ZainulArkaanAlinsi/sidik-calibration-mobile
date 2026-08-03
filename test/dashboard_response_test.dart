import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/dashboard_summary.dart';

/// Parsing `GET /api/dashboard` diuji pakai **potongan respons asli server**,
/// bukan map karangan sendiri.
///
/// Ini bukan formalitas: `grafik_pekerjaan` sempat diparse pakai key `periode`
/// padahal server ngirim `bulan`, dan nggak ada satu pun test yang jatuh —
/// karena `MockDashboardService` waktu itu ngisi objeknya langsung lewat
/// constructor, jadi parser yang salah itu nggak pernah kelewatan. Yang
/// kelihatan cuma di HP: sumbu X grafiknya kosong melompong.
void main() {
  // Disalin apa adanya dari handoff backend (§B) — respons live, bukan contoh.
  const responsAsli = <String, dynamic>{
    'total_alat': 6,
    'alat_overdue': 3,
    'kalibrasi_draft': 0,
    'menunggu_approval': 0,
    'kalibrasi_selesai': 3,
    'menunggu_proses': 0,
    'total_sertifikat': 3,
    'sertifikat_bulan_ini': 1,
    'grafik_pekerjaan': [
      {'bulan': '2026-02', 'label': 'Feb 2026', 'masuk': 0, 'selesai': 0},
      {'bulan': '2026-07', 'label': 'Jul 2026', 'masuk': 4, 'selesai': 2},
    ],
  };

  test('angka ringkasan keparse dari nama field server', () {
    final data = DashboardSummary.fromJson(responsAsli);

    expect(data.totalAlat, 6);
    expect(data.alatOverdue, 3);
    expect(data.kalibrasiSelesai, 3);
    expect(data.totalSertifikat, 3);
    expect(data.sertifikatBulanIni, 1);
  });

  test('grafik: `bulan` + `label` keparse, bukan cuma `periode`', () {
    final titik = DashboardSummary.fromJson(responsAsli).grafikPekerjaan;

    expect(titik, hasLength(2));
    expect(titik.first.periode, '2026-02');
    expect(
      titik.first.label,
      'Feb 2026',
      reason: 'label dari server dipakai apa adanya buat sumbu X grafik',
    );
    expect(titik.last.masuk, 4);
    expect(titik.last.selesai, 2);
  });

  test('`periode` dari endpoint tren tetap keparse', () {
    // `GET /dashboard/tren` ngirim `periode`, bukan `bulan` — parser-nya harus
    // nerima dua-duanya, jangan cuma pindah dari salah satu ke yang lain.
    final titik = TitikTren.fromJson(const {
      'periode': '2026-05-04',
      'masuk': 2,
      'selesai': 1,
    });

    expect(titik.periode, '2026-05-04');
    expect(titik.label, isEmpty);
  });

  test('field yang belum dikirim backend nggak bikin crash', () {
    final data = DashboardSummary.fromJson(const {'total_alat': 2});

    expect(data.totalAlat, 2);
    expect(data.grafikPekerjaan, isEmpty);

    // `total_sertifikat` NGGAK dikirim `GET /dashboard` (dicek 31 Jul), jadi
    // hasilnya `null` — BUKAN 0.
    //
    // Dulu di-default ke 0 dan layar nulis "Total sepanjang masa 0" padahal
    // di database ada 32. Itu angka yang salah, bukan angka yang belum ada,
    // dan yang baca nggak punya cara mbedain. Nol itu pernyataan; "belum
    // tahu" bukan nol.
    expect(data.totalSertifikat, isNull);
  });

  test('total_sertifikat yang BENERAN dikirim tetap kebaca', () {
    // Biar kalau backend nanti nambahin field-nya, nggak ada yang perlu
    // diubah di sini.
    expect(
      DashboardSummary.fromJson(const {'total_sertifikat': 32}).totalSertifikat,
      32,
    );
  });

  test('dashboard dianggap kosong cuma kalau semua angkanya nol', () {
    expect(DashboardSummary.fromJson(const <String, dynamic>{}).kosong, isTrue);

    // Sertifikat lab yang udah terbit bikin dashboard nggak "kosong" lagi,
    // walaupun teknisi yang login belum ngerjain sesi apa pun.
    expect(
      DashboardSummary.fromJson(const {'total_sertifikat': 4}).kosong,
      isFalse,
    );
  });
}
