import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/review_foto.dart';
import '../../models/worksheet_template.dart';
import '../../providers/sumber_foto_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/jalankan_pindai.dart' show GagalPindai;
import '../../services/jalankan_pindai_asli.dart';
import '../../services/pembaca_halaman.dart' show PembacaHalaman;
import '../../services/pembaca_sel.dart' show PembacaSel;
import '../../services/peta_tabel_foto.dart' show SelTabelFoto;
import '../../services/potong_sel_foto.dart' show decodeFotoDiIsolate;
import 'foto_review_screen.dart';
import 'lembar_kerja_state.dart';

/// Pemisah `tabelId` dan `fieldId` di kunci baris review (satu layar review
/// untuk semua tabel; pH punya dua tabel dengan titik yang sama).
const _pisah = '@@';

/// "Foto lembar kerja" — SEMUA diproses di HP (K-50-11): foto seluruh lembar →
/// kenali formulir (kode tercetak) → luruskan → ML Kit per sel → layar review
/// → angka masuk lembar. Foto, potongan, dan citra lurus hanya di memori;
/// tidak ada yang diunggah. Hasil OCR hanyalah USULAN: tulisan tangan tidak
/// pernah hijau, merah wajib diketik, kuning wajib dicek satu per satu.
///
/// Mengembalikan jumlah sel yang masuk lembar (0 = dibatalkan/gagal; pesan
/// sudah ditampilkan).
Future<int> pindaiFormulirAsli({
  required BuildContext context,
  required WidgetRef ref,
  required LembarKerjaState isian,
  required WorksheetTemplate template,
  JalankanPindaiAsli? mesin,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  void kabar(String pesan) =>
      messenger.showSnackBar(SnackBar(content: Text(pesan)));

  // Foto penuh: TANPA maxWidth/imageQuality — tiap piksel yang dibuang di sini
  // hilang dari angka yang terbaca.
  final berkas = await ref.read(sumberFotoProvider).ambil();
  if (berkas == null) return 0;

  final bita = await berkas.readAsBytes();
  try {
    await berkas.delete();
  } catch (_) {
    // Sampah yang tak terhapus bukan alasan menolak foto.
  }

  final citra = await decodeFotoDiIsolate(bita);
  if (citra == null) {
    kabar(l10n.lkPindaiGagalFoto);
    return 0;
  }

  if (!context.mounted) return 0;

  // Dialog progres: pekerjaan berat jalan di Isolate, layar tetap hidup.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.lkAsliMemproses)),
          ],
        ),
      ),
    ),
  );

  // Pembaca ML Kit memegang sumber daya native: dibuat hanya kalau perlu dan
  // SELALU ditutup. [mesin] disuntik hanya oleh test.
  PembacaHalaman? halaman;
  PembacaSel? pembaca;
  HasilBacaAsli? hasil;
  String? galat;

  try {
    JalankanPindaiAsli pakai;
    if (mesin != null) {
      pakai = mesin;
    } else {
      final pabrik = ref.read(pabrikPembacaPindaiProvider);
      pakai = JalankanPindaiAsli(
        halaman: halaman = pabrik.halaman(),
        pembaca: pembaca = pabrik.sel(),
      );
    }
    hasil = await pakai.baca(citra, template: template);
  } on PindaiAsliGagal catch (e) {
    galat = pesanGagalAsli(l10n, e);
  } catch (_) {
    galat = l10n.lkAsliGagalUmum;
  } finally {
    await halaman?.tutup();
    await pembaca?.tutup();
    if (navigator.mounted) navigator.pop(); // tutup dialog progres
  }

  if (galat != null || hasil == null) {
    kabar(galat ?? l10n.lkAsliGagalUmum);
    return 0;
  }

  if (!context.mounted) return 0;

  // ---- Susun baris review ---------------------------------------------------
  final sel = <SelTabelFoto>[];
  final potongan = <String, Uint8List>{};

  for (final b in hasil.sel) {
    final s = b.sel;
    final titik = s.titikUkur;
    final teks = b.bacaan.teks?.trim();

    // Sel kosong di kertas = tetap kosong di lembar. Tanpa titik ukur, sel
    // tidak punya alamat yang pasti: dibuang, bukan ditebak.
    if (titik == null || teks == null || teks.isEmpty) continue;

    // Teks bukan angka, atau tulisan keluar kotak → MERAH (nilainya tidak
    // ditampilkan, teknisi mengetik sendiri).
    final bisaDibaca = b.bacaan.didalamKotak && parseAngka(teks) != null;

    sel.add((
      titikUkur: titik,
      repeatNo: s.repeatNo,
      fieldId: '${s.tabelId}$_pisah${s.fieldId}',
      teks: bisaDibaca ? teks : '',
      keyakinan: bisaDibaca ? b.bacaan.keyakinan : 0.0,
    ));
    final crop = hasil.potongan[s.kunci];
    if (crop != null) {
      potongan[kunciSelFoto(
            titik,
            s.repeatNo,
            '${s.tabelId}$_pisah${s.fieldId}',
          )] =
          crop;
    }
  }

  if (sel.isEmpty) {
    kabar(l10n.lkAsliTakAdaSel);
    return 0;
  }

  String judul(SelTabelFoto s) {
    final bagian = s.fieldId.split(_pisah);
    final tabel = isian.tabelUntukId(bagian.first);
    final fieldId = bagian.last;
    final kolom = tabel?.kolom
        .where((k) => k.kode == fieldId)
        .map((k) => k.label)
        .firstOrNull;

    return [
      tabel?.judul ?? bagian.first,
      '${s.titikUkur}',
      'Repeat ${s.repeatNo}',
      kolom ?? fieldId,
    ].join(' · ');
  }

  final baris = susunReviewFoto(sel: sel, potongan: potongan, judul: judul);

  final disetujui = await Navigator.of(context).push<List<SelTabelFoto>>(
    MaterialPageRoute(builder: (_) => FotoReviewScreen(baris: baris)),
  );
  if (disetujui == null) return 0;

  final perTabel = <String, List<SelTabelFoto>>{};
  for (final s in disetujui) {
    final bagian = s.fieldId.split(_pisah);
    (perTabel[bagian.first] ??= []).add((
      titikUkur: s.titikUkur,
      repeatNo: s.repeatNo,
      fieldId: bagian.last,
      teks: s.teks,
      keyakinan: s.keyakinan,
    ));
  }

  final terisi = isian.terapkanHasilFotoBanyakTabel(perTabel);
  kabar(terisi == 0 ? l10n.lkAsliTakAdaSel : l10n.lkAsliTerisi(terisi));

  return terisi;
}

/// Alasan berhenti → kalimat untuk teknisi. Formulir salah = berhenti dengan
/// pesan jelas, tidak pernah menebak.
String pesanGagalAsli(AppLocalizations l10n, PindaiAsliGagal e) =>
    switch (e.sebab) {
      GagalPindaiAsli.belumSiap => l10n.lkAsliBelumSiap,
      GagalPindaiAsli.geometriBelumLengkap => l10n.lkAsliGeometriBelumLengkap,
      GagalPindaiAsli.kodeTidakTerbaca => l10n.lkAsliKodeTidakTerbaca,
      GagalPindaiAsli.formulirLain => l10n.lkAsliFormulirLain(e.terbaca ?? '?'),
      GagalPindaiAsli.revisiBeda => l10n.lkAsliRevisiBeda(e.terbaca ?? '?'),
      GagalPindaiAsli.jangkarKurang => l10n.lkAsliJangkarKurang(e.jumlah ?? 0),
      GagalPindaiAsli.jangkarTidakMenyebar => l10n.lkAsliJangkarTidakMenyebar,
      GagalPindaiAsli.mutu => switch (e.mutu) {
        GagalPindai.mutuBuram => l10n.lkPindaiBuram,
        GagalPindai.mutuGelap => l10n.lkPindaiGelap,
        GagalPindai.mutuSilau => l10n.lkPindaiSilau,
        GagalPindai.mutuPantulan => l10n.lkPindaiPantulan,
        GagalPindai.mutuMiring => l10n.lkPindaiTerlaluMiring,
        GagalPindai.mutuKejauhan => l10n.lkPindaiKejauhan,
        _ => l10n.lkAsliGagalUmum,
      },
    };
