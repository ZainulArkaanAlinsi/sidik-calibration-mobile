import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img show Image;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/beku_lembar_kerja.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/kesiapan_pindai_lembar_provider.dart';
import '../../providers/sumber_foto_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/foto_tertinggal.dart';
import '../../services/jenis_lembar.dart';
import '../../services/kenali_jenis_lembar.dart';
import '../../services/modul_pembaca_teks.dart';
import '../../services/pembaca_halaman.dart'
    show PembacaHalaman, sapuBerkasPindaiLama;
import '../../services/pesan_galat_pindai.dart';
import '../../services/potong_sel_foto.dart' show decodeFotoDiIsolate;
import '../../widgets/konfirmasi_foto_tertinggal.dart';
import '../../widgets/pilih_jenis_lembar_sheet.dart';
import '../calibration/lembar_kerja_screen.dart';
import '../calibration/pindai_formulir_asli_flow.dart' show batasSisiFotoAsli;

/// "Pindai lembar kerja" dari beranda (Opsi A): foto lembar -> aplikasi
/// MENYARANKAN jenisnya -> teknisi konfirmasi -> lembar kerja jenis itu
/// terbuka KOSONG.
///
/// Urutannya, dan apa yang TIDAK dilakukannya:
///
///  1. Daftar jenis dari cache `kesiapanPindaiLembarProvider` (tidak meminta
///     server lagi); gagal = pesan butuh koneksi, tanpa kamera.
///  2. Kamera, lalu decode di isolate (foto 4200 px ≈ puluhan MB, dibuang
///     dari memori sebelum lembar kerja dibuka).
///  3. Pembaca halaman ML Kit di perangkat, putaran 0/90/180/270 sampai kode
///     formulir terbaca (`kenaliJenisLembar`). Pembaca SELALU ditutup.
///  4. SATU lembar pilihan (`tampilkanPilihJenisLembar`): usulan hanya
///     memilih-awal baris bila kode cocok tepat satu jenis; pilih manual
///     selalu ada; menutup lembar = selesai tanpa membuka apa pun.
///  5. Jenis yang dikonfirmasi belum boleh dipindai server = pesan, tanpa
///     navigasi. Selain itu `LembarKerjaScreen` jenis itu dibuka — dibungkus
///     `BekuLembarKerja` seperti pemanggil lembar kerja lain.
///
/// Tidak ada isian, navigasi, atau pilihan jenis tanpa konfirmasi teknisi;
/// tidak ada satu sel pun yang terisi dari foto ini (sel kosong tetap kosong).
/// Foto tidak diunggah dan tidak disimpan: hanya ada di memori selama dibaca,
/// berkas kameranya dihapus begitu bitanya terbaca. Teknisi memotret LAGI di
/// dalam lembar kerja lewat alur "Foto lembar kerja" yang sudah ada (butuh
/// alat dipilih dulu), yang memeriksa ulang kode formulir terhadap jenis yang
/// dipilih.
///
/// [setelahKembali] dipanggil sesudah lembar kerja ditutup (mis. menyegarkan
/// daftar draf beranda teknisi).
Future<void> pindaiLembarKerja({
  required BuildContext context,
  required WidgetRef ref,
  Future<void> Function()? setelahKembali,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  void kabar(String pesan) =>
      messenger.showSnackBar(SnackBar(content: Text(pesan)));

  // ---- 1. daftar jenis (cache sesi) ------------------------------------------
  final KesiapanPindaiLembar kesiapan;
  try {
    kesiapan = await ref.read(kesiapanPindaiLembarProvider.future);
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-daftar', e, st);
    kabar(l10n.pindaiLembarButuhKoneksi);
    return;
  }
  if (!kesiapan.adaYangBoleh) {
    kabar(l10n.lkAsliBelumSiap);
    return;
  }
  if (!context.mounted) return;

  // ---- 2-3. foto + pengenalan (memori berat hanya hidup di sini) -------------
  final kenal = await _ambilDanKenali(
    context: context,
    ref: ref,
    kesiapan: kesiapan,
  );
  if (kenal == null || !context.mounted) return;

  // ---- 4. satu konfirmasi ----------------------------------------------------
  final pilihan = await tampilkanPilihJenisLembar(
    context,
    petunjuk: kenal.petunjuk,
    dikenal: kesiapan.dikenal,
  );
  if (pilihan == null || !context.mounted) return;

  // ---- 5. buka lembar kerja --------------------------------------------------
  if (!kesiapan.bolehDipindai(pilihan.templateId)) {
    kabar(l10n.lkAsliBelumSiap);
    return;
  }

  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => BekuLembarKerja(
        child: LembarKerjaScreen(
          profil: pilihan.templateId,
          judulTambahan: namaPendekJudul(pilihan.judul),
        ),
      ),
    ),
  );

  if (context.mounted) await setelahKembali?.call();
}

/// Hasil pengenalan; `petunjuk == null` = tidak ada petunjuk sama sekali
/// (lembar pilihan menampilkan daftar manual).
typedef _Pengenalan = ({HasilJenisLembar? petunjuk});

/// Kamera -> decode -> pembaca halaman. `null` = berhenti (dibatalkan atau
/// gagal; pesan sudah ditampilkan). Fungsi terpisah supaya foto dan citra
/// hasil decode (puluhan MB) lepas dari memori sebelum lembar pilihan dan
/// lembar kerja dibuka.
Future<_Pengenalan?> _ambilDanKenali({
  required BuildContext context,
  required WidgetRef ref,
  required KesiapanPindaiLembar kesiapan,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  void kabar(String pesan) =>
      messenger.showSnackBar(SnackBar(content: Text(pesan)));

  // Sisa berkas sementara pindai yang tertinggal (proses mati di tengah baca)
  // disapu dulu. Tidak ditunggu dan tidak boleh menggagalkan pindai.
  unawaited(
    getTemporaryDirectory()
        .then(sapuBerkasPindaiLama)
        .then<void>((_) {}, onError: (Object _) {}),
  );

  final File? berkas;
  try {
    berkas = await ambilFotoAtauPulihkan(
      ref.read(sumberFotoProvider),
      pakaiTertinggal: (f) => konfirmasiFotoTertinggal(context, f),
      // Sama dengan "Foto lembar kerja": batas sisi 4200 px, mutu JPEG 100
      // (artefak JPEG di tulisan kecil kaki formulir menurunkan bacaan kode).
      maxWidth: batasSisiFotoAsli,
      maxHeight: batasSisiFotoAsli,
      imageQuality: 100,
      // Jenis lembar belum diketahui, jadi bingkai panduan tidak bisa
      // mengikuti bentuk halamannya.
      rasioKertas: null,
    );
  } catch (e, st) {
    // Izin kamera ditolak, kamera tidak ada, dsb.
    catatGalatPindai('pindai-lembar-kamera', e, st);
    kabar(pesanGalatPindai(l10n, e, umum: l10n.lkAsliGagalUmum));
    return null;
  }
  if (berkas == null) return null; // Teknisi mundur dari kamera.

  final bita = await berkas.readAsBytes();
  try {
    await berkas.delete();
  } catch (_) {
    // Sampah yang tak terhapus bukan alasan menolak foto.
  }

  final img.Image? citra;
  try {
    citra = await decodeFotoDiIsolate(bita);
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-decode', e, st);
    kabar(pesanGalatPindai(l10n, e, umum: l10n.lkPindaiGagalFoto));
    return null;
  }
  if (citra == null) {
    kabar(l10n.lkPindaiGagalFoto);
    return null;
  }

  if (!context.mounted) return null;

  // Dialog progres: pembacaan berat, dan teknisi tidak boleh mengira layar
  // macet. Tidak bisa ditutup sendiri; ditutup di `finally` di bawah.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l10n.pindaiLembarMembaca)),
          ],
        ),
      ),
    ),
  );

  // Pembaca ML Kit memegang sumber daya native: dibuat di sini dan SELALU
  // ditutup, apa pun hasilnya.
  PembacaHalaman? halaman;
  HasilJenisLembar? petunjuk;
  String? galat;

  try {
    halaman = ref.read(pabrikPembacaPindaiProvider).halaman();
    petunjuk = await kenaliJenisLembar(
      foto: citra,
      jpegAsli: bita,
      halaman: halaman,
      dikenal: kesiapan.dikenal,
    );
  } on ModulPembacaTeksBelumSiap {
    // ML Kit unbundled: modul `ocr` belum terunduh. Tidak ada yang berubah.
    galat = l10n.lkModulPembacaTeksDiunduh;
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-baca', e, st);
    galat = pesanGalatPindai(l10n, e, umum: l10n.lkAsliGagalUmum);
  } finally {
    try {
      await halaman?.tutup();
    } catch (e, st) {
      // Gagal menutup pembaca tidak boleh menghentikan alur diam-diam.
      catatGalatPindai('pindai-lembar-tutup', e, st);
    } finally {
      if (navigator.mounted) navigator.pop(); // tutup dialog progres
    }
  }

  if (galat != null) {
    kabar(galat);
    return null;
  }

  return (petunjuk: petunjuk);
}
