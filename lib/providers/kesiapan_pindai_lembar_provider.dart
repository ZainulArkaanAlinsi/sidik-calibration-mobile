import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/worksheet_template.dart';
import '../screens/calibration/temperatur_indikator_gerbang_screen.dart'
    show namaTemperaturIndikator;
import '../services/jenis_lembar.dart';
import 'auth_provider.dart';
import 'worksheet_scan_provider.dart';

/// Daftar jenis lembar dari server beserta kesiapan pindai-dari-beranda.
///
/// Bahan DUA hal: tombol "Pindai lembar kerja" di tiga beranda (tampil hanya
/// bila [adaYangBoleh]) dan daftar usulan jenis lembar di alur pindai
/// (`dikenal`). Keduanya dari SATU daftar yang sama, jadi alur tidak meminta
/// daftar lagi.
class KesiapanPindaiLembar {
  const KesiapanPindaiLembar._(this.daftar);

  /// Bentuk dari daftar mentah server. Temperatur Indikator (`tits`/`tids`)
  /// dikeluarkan: dua nama alatnya punya lembar yang beda seluruhnya dan
  /// varian dipilih teknisi di gerbangnya (`TemperaturIndikatorGerbangScreen`),
  /// bukan ditebak dari foto. Memasukkannya berarti membuka lembar tanpa
  /// pernah menanyakan sensornya ikut atau tidak.
  factory KesiapanPindaiLembar.dari(List<WorksheetTemplate> mentah) =>
      KesiapanPindaiLembar._([
        for (final t in mentah)
          if (t.templateId.isNotEmpty && !_temperaturIndikator(t)) t,
      ]);

  /// Tidak ada apa-apa: tombol tersembunyi.
  static const kosong = KesiapanPindaiLembar._([]);

  static const _idTemperaturIndikator = {'tits', 'tids'};

  static bool _temperaturIndikator(WorksheetTemplate t) =>
      _idTemperaturIndikator.contains(t.templateId) ||
      namaTemperaturIndikator(t.judul);

  /// Jenis lembar yang dikenal server, tanpa Temperatur Indikator.
  final List<WorksheetTemplate> daftar;

  /// Minimal satu jenis `boleh` dipindai (aturan kontrak di
  /// [AsliDiDaftar.boleh]). Server produksi sekarang menjawab `false` untuk
  /// semuanya, jadi tombol tidak terlihat sampai server menyalakannya.
  bool get adaYangBoleh => daftar.any((t) => t.asli.boleh);

  /// Bahan `detectWorksheetType` dan daftar manual di lembar pilihan. Semua
  /// jenis ikut, bukan hanya yang boleh: kode formulir jenis yang belum siap
  /// tetap harus dikenali (kalau tidak, ia terbaca "kode tidak dikenal" dan
  /// kode yang dipakai bersama beberapa jenis kehilangan kandidatnya).
  List<FormulirDikenal> get dikenal => [
    for (final t in daftar) formulirDikenalDari(t),
  ];

  /// `true` bila jenis [templateId] boleh dipindai. Id tak dikenal = `false`.
  bool bolehDipindai(String templateId) =>
      daftar.any((t) => t.templateId == templateId && t.asli.boleh);
}

/// Kesiapan pindai-dari-beranda: `GET /worksheet-templates` SEKALI per sesi.
///
/// Respons daftar sekarang lebih berat (membaca & mencocokkan peta formulir
/// tiap jenis) dan hanya berubah saat server dideploy, jadi:
///
///  - hasil BERHASIL dipertahankan (`keepAlive` pada provider `autoDispose`)
///    selama sesi: beranda yang dibangun ulang, berpindah tab, atau dibuka
///    lagi tidak memanggil server lagi;
///  - hasil GAGAL (offline, 5xx, token hilang) tidak dipertahankan dan tanpa
///    percobaan ulang otomatis: tombol cukup tidak tampil, tanpa pesan galat,
///    dan jalur "Mulai kalibrasi" tidak terganggu. Dicoba lagi begitu tidak
///    ada beranda yang memantaunya (dibuka ulang) atau saat ditarik-segarkan.
///    Sengaja `autoDispose` EKSPLISIT: `FutureProvider` biasa di Riverpod 3
///    BUKAN autoDispose, dan akan menempelkan galat pertama sepanjang sesi;
///  - dibuang saat akun berganti/keluar (watch ke id pengguna, aturan
///    `sidik-fe-scope-akun`) dan oleh `ref.invalidate` dari tarik-segarkan.
///
/// Saklar [pindaiLembarAktifProvider] mati, atau belum ada pengguna masuk =
/// [KesiapanPindaiLembar.kosong] TANPA memanggil server.
final kesiapanPindaiLembarProvider =
    FutureProvider.autoDispose<KesiapanPindaiLembar>((ref) async {
      final aktif = ref.watch(pindaiLembarAktifProvider);
      final idPengguna = ref.watch(authProvider.select((a) => a.value?.id));
      if (!aktif || idPengguna == null) return KesiapanPindaiLembar.kosong;

      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) return KesiapanPindaiLembar.kosong;

      final daftar = await ref
          .read(worksheetScanServiceProvider)
          .daftarTemplate(token);
      final hasil = KesiapanPindaiLembar.dari(daftar);

      // Hanya yang berhasil: galat tidak boleh menempel sepanjang sesi. Beranda
      // yang sudah ditinggalkan sebelum daftar datang membuang providernya; yang
      // sudah dibuang tidak boleh dipertahankan.
      if (ref.mounted) ref.keepAlive();

      return hasil;
    }, retry: (retryCount, error) => null);
