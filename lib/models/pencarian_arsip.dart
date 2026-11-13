import 'calibration_history_item.dart';

/// Saringan layar Arsip: satu kotak cari, rentang tanggal kalibrasi, dan PT.
///
/// Nilainya yang dikirim ke server — app tidak menyaring daftar sendiri
/// (kontrak arsip-cari §0 butir 2). Dibuat sebagai nilai (bukan banyak
/// variabel lepas) supaya sama-dengan bisa dipakai provider memutuskan
/// "saringan berubah, ambil ulang".
class FilterArsip {
  const FilterArsip({
    this.kata = '',
    this.dari,
    this.sampai,
    this.pelangganId,
    this.pelangganNama,
  });

  static const kosong = FilterArsip();

  /// Server menolak (`422`) `q` satu huruf di rute baru, dan satu huruf
  /// mencocokkan hampir semua baris — jadi klien tidak mengirimnya.
  static const minHuruf = 2;

  /// Yang diketik, hanya dipotong spasi di ujungnya. Isinya TIDAK diubah
  /// (`/`, `-`, spasi di tengah, huruf besar/kecil): server yang menyamakan
  /// `CAL/2026/10/0001` dengan `cal-2026-10-0001`.
  final String kata;

  /// Tanggal kalibrasi, kedua ujung termasuk. Tanggal kalender polos.
  final DateTime? dari;
  final DateTime? sampai;

  final int? pelangganId;

  /// Nama PT untuk label chip. Tidak ikut dikirim ke server.
  final String? pelangganNama;

  /// Kata yang boleh dikirim ke server; null kalau kosong atau terlalu
  /// pendek.
  String? get kataKirim => kata.length >= minHuruf ? kata : null;

  bool get adaRentang => dari != null || sampai != null;

  /// Hasil cari berupa daftar sesi (`/calibrations`) — satu-satunya rute yang
  /// mengenal `q` yang menyaring ke daftar datar dan `dari`/`sampai`. Selain
  /// itu layar menampilkan garis waktu.
  bool get modeHasil => kataKirim != null || adaRentang;

  /// Ada saringan apa pun (termasuk kata satu huruf yang belum dikirim).
  bool get adaFilter => kata.isNotEmpty || adaRentang || pelangganId != null;

  FilterArsip denganKata(String mentah) => FilterArsip(
    kata: mentah.trim(),
    dari: dari,
    sampai: sampai,
    pelangganId: pelangganId,
    pelangganNama: pelangganNama,
  );

  /// [dari] dan [sampai] sudah berupa tanggal kalender (jam diabaikan).
  /// Urutannya wajib benar; server menjawab `422` kalau `sampai` < `dari`.
  FilterArsip denganRentang(DateTime? dari, DateTime? sampai) {
    assert(
      dari == null || sampai == null || !_hari(sampai).isBefore(_hari(dari)),
      '`sampai` tidak boleh sebelum `dari`.',
    );
    return FilterArsip(
      kata: kata,
      dari: dari == null ? null : _hari(dari),
      sampai: sampai == null ? null : _hari(sampai),
      pelangganId: pelangganId,
      pelangganNama: pelangganNama,
    );
  }

  FilterArsip denganPelanggan(int? id, String? nama) => FilterArsip(
    kata: kata,
    dari: dari,
    sampai: sampai,
    pelangganId: id,
    pelangganNama: id == null ? null : nama,
  );

  static DateTime _hari(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  bool operator ==(Object other) =>
      other is FilterArsip &&
      other.kata == kata &&
      other.dari == dari &&
      other.sampai == sampai &&
      other.pelangganId == pelangganId &&
      other.pelangganNama == pelangganNama;

  @override
  int get hashCode =>
      Object.hash(kata, dari, sampai, pelangganId, pelangganNama);
}

/// Satu halaman `GET /api/calibrations?bentuk=ringan`.
class HalamanRiwayat {
  const HalamanRiwayat({
    required this.baris,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
  });

  final List<CalibrationHistoryItem> baris;
  final int halaman;

  /// `meta.last_page` — satu-satunya penentu berhenti memuat.
  final int halamanTerakhir;
  final int total;
}

/// Server yang menjawab belum memuat paket arsip-cari terpadu: rute garis
/// waktu tidak ada, atau parameter baru (`per_page`, `q`, `dari`) diabaikan.
///
/// Dipisah dari galat jaringan karena jawabannya beda: mencoba lagi tidak
/// menolong, dan daftar yang diabaikan saringannya TIDAK boleh ditampilkan
/// seolah-olah sudah tersaring.
class ServerBelumMendukungArsipException implements Exception {
  const ServerBelumMendukungArsipException();

  @override
  String toString() => 'Server belum mendukung pencarian arsip terpadu.';
}
