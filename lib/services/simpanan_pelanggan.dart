import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer_lookup.dart';

/// Isi simpanan berikut kapan dia diambil dari server.
typedef IsiSimpananPelanggan = ({
  List<CustomerLookup> daftar,
  DateTime diambil,
});

/// Salinan daftar pelanggan di dalam HP, supaya mencari pelanggan tetap jalan
/// waktu server mati atau sinyal habis.
///
/// ## Kenapa ini ada
///
/// Teknisi berdiri di dalam pabrik — beton, mesin, dan sering nol sinyal. Kalau
/// pemilih pelanggan cuma bisa jalan waktu server bisa dihubungi, dia mentok di
/// tempat yang justru paling sering dia datangi. Pelanggannya sendiri jarang
/// berubah: yang kemarin ada, hari ini hampir pasti masih ada.
///
/// ## Batas akun — ini bagian yang paling gampang salah
///
/// Satu APK dipakai teknisi dan admin, dan HP lab dipakai gantian. Isi
/// SharedPreferences **nggak ikut auto-dispose Riverpod sama sekali**: dia
/// bertahan melewati logout, melewati aplikasi ditutup, melewati HP dimatikan.
///
/// Jadi nama pelanggan lab A bisa muncul di layar orang lab B — kebocoran antar
/// pelanggan yang nggak ninggalin satu pun error, dan yang nggak akan ketahuan
/// siapa pun yang mengetes cuma dengan satu akun.
///
/// Dua lapis, dan dua-duanya sengaja:
///
///  1. **Kuncinya memuat id organisasi.** Lab yang beda baca laci yang beda.
///  2. **[bersihkan] dipanggil di jalur logout** — dua-duanya, `logout()` DAN
///     `logoutAll()`. Lapis pertama sudah cukup buat lab yang beda; yang kedua
///     menutup akun yang beda di lab yang SAMA, dan menutup lapis pertama kalau
///     suatu saat ada yang mengubah bentuk kuncinya.
///
/// Organisasi yang `null` **nggak disimpan sama sekali**. Menaruhnya di satu
/// laci bersama bikin semua akun tanpa organisasi saling melihat daftar
/// pelanggan — persis hal yang dicegah kelas ini.
class SimpananPelanggan {
  const SimpananPelanggan();

  /// Versi ikut di kunci: bentuk datanya berubah → laci lama ditinggal, bukan
  /// dibaca setengah-setengah lalu meledak di lapangan.
  static const _awalan = 'pelanggan.v1.';

  String _kunci(int organisasiId) => '$_awalan$organisasiId';

  Future<void> simpan(int? organisasiId, List<CustomerLookup> daftar) async {
    if (organisasiId == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _kunci(organisasiId),
      jsonEncode({
        'diambil': DateTime.now().toUtc().toIso8601String(),
        'daftar': [for (final p in daftar) p.toJson()],
      }),
    );
  }

  Future<IsiSimpananPelanggan?> baca(int? organisasiId) async {
    if (organisasiId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final mentah = prefs.getString(_kunci(organisasiId));
    if (mentah == null) return null;

    try {
      final isi = jsonDecode(mentah) as Map<String, dynamic>;
      final daftar = (isi['daftar'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CustomerLookup.fromJson)
          .toList();

      return (
        daftar: daftar,
        diambil:
            DateTime.tryParse(isi['diambil'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
    } catch (_) {
      // Simpanan rusak diperlakukan sebagai TIDAK ADA, bukan bikin layarnya
      // gagal. Yang hilang cuma jalur cadangan; jalur utama ke server tetap
      // dicoba, dan ketik tangan tetap jalan.
      return null;
    }
  }

  /// Buang SEMUA laci pelanggan, bukan cuma milik satu organisasi.
  ///
  /// Dipanggil waktu logout, dan di situ id organisasinya sudah nggak bisa
  /// diandalkan — tokennya keburu dibuang. Menebak satu kunci berarti
  /// meninggalkan sisa waktu tebakannya meleset, dan sisa itu berisi nama
  /// pelanggan.
  Future<void> bersihkan() async {
    final prefs = await SharedPreferences.getInstance();

    for (final kunci in prefs.getKeys().where((k) => k.startsWith(_awalan))) {
      await prefs.remove(kunci);
    }
  }

  /// Saring daftar simpanan dengan aturan yang SAMA dengan server.
  ///
  /// Nama ATAU alamat, dan tahan tanda baca — `CustomerController::lookup()`
  /// mencari begitu, dan hasil yang beda antara online dan offline bikin
  /// teknisi mengira pelanggannya hilang.
  List<CustomerLookup> saring(List<CustomerLookup> daftar, String? cari) {
    final kata = (cari ?? '').trim();
    if (kata.isEmpty) return daftar;

    final biasa = kata.toLowerCase();
    final normal = normalkan(kata);

    return daftar
        .where(
          (c) =>
              c.nama.toLowerCase().contains(biasa) ||
              (c.alamat ?? '').toLowerCase().contains(biasa) ||
              (normal.isNotEmpty && normalkan(c.nama).contains(normal)),
        )
        .toList();
  }

  /// Sama dengan `Customer::normalkanNama()` di server: huruf besar-kecil,
  /// tanda baca, dan spasi ganda diratakan. Bentuk badan usaha (PT/CV) SENGAJA
  /// nggak dibuang — `PT Maju` dan `CV Maju` dua badan hukum berbeda.
  static String normalkan(String nama) => nama
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
