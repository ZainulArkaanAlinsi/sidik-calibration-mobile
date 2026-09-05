import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../services/penampung_contoh_sel.dart';
import '../services/simpanan_contoh_sel.dart';

/// Penampung contoh latih — SATU buat seluruh aplikasi.
///
/// ## Kenapa harus satu
///
/// Dua alasan, dan dua-duanya bikin data hilang kalau dilanggar:
///
///  1. [SimpananContohSel] mengantre tulisannya PER INSTANCE. Dua instance
///     yang menunjuk folder sama tetap bisa saling menimpa indeksnya — lihat
///     docblock `simpan()`.
///  2. [PenampungContohSel] menahan potongan di memori dari saat difoto
///     sampai teknisi menekan Simpan. Instance baru tiap kali dibutuhkan
///     berarti potongannya hilang di antara dua langkah itu, dan yang
///     tersimpan cuma nol contoh — tanpa satu pun error.
///
/// `FutureProvider` menyimpan hasilnya, jadi pemanggil kedua dapat instance
/// yang sama selama providernya belum dibuang.
///
/// ## Kenapa `getApplicationSupportDirectory`
///
/// Bukan folder sementara: isinya justru harus BERTAHAN antar sesi — itu
/// seluruh gunanya, data latih yang menumpuk sendiri tiap kalibrasi. Folder
/// sementara dibersihkan sistem kapan saja.
///
/// Bukan juga folder dokumen: di iOS folder itu bisa kelihatan dari aplikasi
/// Files kalau app menyalakannya, dan isinya di sini potongan lembar kerja
/// pelanggan. Folder dukungan aplikasi privat dan nggak dijelajahi pengguna.
///
/// Nggak ada yang keluar dari HP — lihat
/// `.claude/skills/sidik-fe-ocr-privasi-audit`.
final penampungContohSelProvider = FutureProvider<PenampungContohSel>((
  ref,
) async {
  final dasar = await getApplicationSupportDirectory();

  return PenampungContohSel(
    SimpananContohSel(Directory('${dasar.path}/contoh_sel')),
  );
});
