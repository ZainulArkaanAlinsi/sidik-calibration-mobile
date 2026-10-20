import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/review_foto.dart';
import '../../models/worksheet_template.dart';
import '../../providers/sumber_foto_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/aturan_formulir_asli.dart';
import '../../services/jalankan_pindai.dart' show GagalPindai;
import '../../services/jalankan_pindai_asli.dart';
import '../../services/pembaca_halaman.dart'
    show PembacaHalaman, sapuBerkasPindaiLama;
import '../../services/pembaca_sel.dart' show PembacaSel;
import '../../services/peta_tabel_foto.dart' show SelTabelFoto;
import '../../services/potong_sel_foto.dart' show decodeFotoDiIsolate;
import 'foto_review_screen.dart';
import 'lembar_kerja_state.dart';

/// Pemisah `tabelId` dan `fieldId` di kunci baris review (satu layar review
/// untuk semua tabel; pH punya dua tabel dengan titik yang sama).
const _pisah = '@@';

/// Penanda baris review isian Env./header (bukan nama tabel mana pun).
const _kodeIsian = '@isian';

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

  // Sisa berkas sementara pindai yang tertinggal (proses mati di tengah baca)
  // disapu dulu. Tidak ditunggu dan tidak boleh menggagalkan pindai.
  unawaited(
    getTemporaryDirectory()
        .then(sapuBerkasPindaiLama)
        .then<void>((_) {}, onError: (Object _) {}),
  );

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
    hasil = await pakai.baca(citra, template: template, jpegAsli: bita);
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
  //
  // Alamat sel = (tabel_id, baris_ke, repeat_no, field_id) dari server, dibawa
  // di `fieldId` baris review sebagai `tabel@@baris@@field`. Titik ukur TIDAK
  // dipakai sebagai alamat: di lembar bertitik ketik-sendiri semua barisnya
  // bertitik 0. `titikUkur` baris review diisi nomor urut kertas (tabel × 1000
  // + baris) — cuma untuk mengurut dan sebagai kunci unik potongan.
  final sel = <SelTabelFoto>[];
  final potongan = <String, Uint8List>{};
  final urutTabel = [for (final t in template.tabel) t.tabelId];

  // Aturan nalar formulir asli (Anak Timbangan 0541): hanya MENURUNKAN warna.
  // Cuma sel yang punya tempat mendarat di lembar yang ikut dinilai.
  final putusan = AturanFormulirAsli.berlakuUntuk(template.templateId)
      ? AturanFormulirAsli.periksa([
          for (final b in hasil.sel)
            if (isian.alamatFotoAsliAda(
              b.sel.tabelId,
              b.sel.barisKe,
              b.sel.repeatNo,
              tahap: b.sel.tahap,
            ))
              (
                kunci: b.sel.kunci,
                tabelId: b.sel.tabelId,
                barisKe: b.sel.barisKe,
                repeatNo: b.sel.repeatNo,
                teks: b.bacaan.teks?.trim() ?? '',
                gagalDibaca: hasil.gagalDibaca.contains(b.sel.kunci),
                resolusi: b.sel.aturan?.resolusi,
                desimal: b.sel.aturan?.desimal,
                // Nominal blok diketik SEKALI per keping, di tabel Standard
                // pertama — tabel lain punya baris sendiri yang kosong.
                teksNominal: isian.teksNominalFotoAsli(
                  AturanFormulirAsli.tabelNominal,
                  b.sel.barisKe,
                ),
              ),
        ])
      : const <String, PutusanAturan>{};

  for (final b in hasil.sel) {
    final s = b.sel;
    final teks = b.bacaan.teks?.trim() ?? '';
    final gagalDibaca = hasil.gagalDibaca.contains(s.kunci);
    final vonisAturan = putusan[s.kunci]?.vonis ?? VonisAturan.tetap;

    // Sel kosong di kertas = tetap kosong di lembar. Sel yang GAGAL dibaca
    // (galat ML Kit) bukan sel kosong: dia ikut review sebagai MERAH kosong.
    // Begitu juga sel kosong di blok yang terisi sebagian (blok tidak lengkap).
    if (teks.isEmpty && !gagalDibaca && vonisAturan != VonisAturan.merah) {
      continue;
    }

    // Baris kertas yang tidak punya padanan di lembar (kertas mencetak lebih
    // banyak baris/Repeat daripada yang diatur untuk alat ini) tidak ikut
    // review: tidak ada kotak tempat mendaratnya.
    if (!isian.alamatFotoAsliAda(
      s.tabelId,
      s.barisKe,
      s.repeatNo,
      tahap: s.tahap,
    )) {
      continue;
    }

    // Teks bukan angka, atau tulisan keluar kotak → MERAH (nilainya tidak
    // ditampilkan, teknisi mengetik sendiri).
    final nilaiTabel = parseAngka(teks);
    // Batas `aturan` sel dari server dicek DI HP juga: angka di luar pita
    // (atau rasio ke nominal meleset) = MERAH dan dikosongkan, bukan usulan.
    final bisaDibaca =
        b.bacaan.didalamKotak &&
        nilaiTabel != null &&
        (s.aturan?.lolos(nilaiTabel) ?? true);
    final urut = (urutTabel.indexOf(s.tabelId) + 1) * 1000.0 + s.barisKe;
    final fieldId = '${s.tabelId}$_pisah${s.barisKe}$_pisah${s.fieldId}';

    final usulan = AturanFormulirAsli.terapkan(
      vonisAturan,
      teks: bisaDibaca ? teks : '',
      keyakinan: bisaDibaca ? b.bacaan.keyakinan : 0.0,
    );
    sel.add((
      titikUkur: urut,
      repeatNo: s.repeatNo,
      fieldId: fieldId,
      teks: usulan.teks,
      keyakinan: usulan.keyakinan,
    ));
    final crop = hasil.potongan[s.kunci];
    if (crop != null) {
      potongan[kunciSelFoto(urut, s.repeatNo, fieldId)] = crop;
    }
  }

  // Isian Env./header: baris review juga, ditaruh paling atas dalam golongan
  // vonisnya (urut negatif). Di luar rentang wajar = MERAH.
  var noIsian = 0;
  for (final b in hasil.isian) {
    final kode = b.isian.kode;
    final teks = b.bacaan.teks?.trim() ?? '';
    noIsian++;
    if (teks.isEmpty && !hasil.gagalDibaca.contains(kunciPotonganIsian(kode))) {
      continue;
    }

    final nilai = parseAngka(teks);
    final bisaDibaca =
        b.bacaan.didalamKotak &&
        nilai != null &&
        wajarIsianLingkungan(kode, nilai);
    final urut = -1000.0 + noIsian;
    final fieldId = '$_kodeIsian$_pisah$noIsian$_pisah$kode';

    sel.add((
      titikUkur: urut,
      repeatNo: 1,
      fieldId: fieldId,
      teks: bisaDibaca ? teks : '',
      keyakinan: bisaDibaca ? b.bacaan.keyakinan : 0.0,
    ));
    final crop = hasil.potongan[kunciPotonganIsian(kode)];
    if (crop != null) {
      potongan[kunciSelFoto(urut, 1, fieldId)] = crop;
    }
  }

  if (sel.isEmpty) {
    kabar(l10n.lkAsliTakAdaSel);
    return 0;
  }

  String judul(SelTabelFoto s) {
    final bagian = s.fieldId.split(_pisah);

    if (bagian.first == _kodeIsian) {
      return [
        l10n.lkAsliKondisiLingkungan,
        isian.labelFieldIsian(bagian.last) ?? bagian.last,
      ].join(' · ');
    }

    final barisKe = int.tryParse(bagian[1]) ?? 0;
    final tahapTabel = template.tabel
        .where((t) => t.tabelId == bagian.first)
        .map((t) => t.tahap)
        .firstOrNull;
    final tabel = isian.tabelUntukId(bagian.first, tahap: tahapTabel);
    final judulTabel =
        template.tabel
            .where((t) => t.tabelId == bagian.first)
            .map((t) => t.judul)
            .firstOrNull ??
        tabel?.judul ??
        bagian.first;
    final fieldId = bagian.last;
    final kolom = tabel?.kolom
        .where((k) => k.kode == fieldId)
        .map((k) => k.label)
        .firstOrNull;

    return [
      judulTabel,
      isian.labelBarisFotoAsli(bagian.first, barisKe, tahap: tahapTabel) ??
          'Baris $barisKe',
      'Repeat ${s.repeatNo}',
      kolom ?? fieldId,
    ].join(' · ');
  }

  final baris = susunReviewFoto(sel: sel, potongan: potongan, judul: judul);

  final disetujui = await Navigator.of(context).push<List<SelTabelFoto>>(
    MaterialPageRoute(builder: (_) => FotoReviewScreen(baris: baris)),
  );
  if (disetujui == null) return 0;

  final tabelDisetujui =
      <
        ({
          String tabelId,
          String? tahap,
          int barisKe,
          int repeatNo,
          String fieldId,
          String teks,
          double? keyakinan,
        })
      >[];
  final isianDisetujui = <String, String>{};

  for (final s in disetujui) {
    final bagian = s.fieldId.split(_pisah);

    if (bagian.first == _kodeIsian) {
      isianDisetujui[bagian.last] = s.teks;
      continue;
    }

    tabelDisetujui.add((
      tabelId: bagian.first,
      tahap: template.tabel
          .where((t) => t.tabelId == bagian.first)
          .map((t) => t.tahap)
          .firstOrNull,
      barisKe: int.tryParse(bagian[1]) ?? 0,
      repeatNo: s.repeatNo,
      fieldId: bagian.last,
      teks: s.teks,
      keyakinan: s.keyakinan,
    ));
  }

  final terisi =
      isian.terapkanHasilFotoAsli(tabelDisetujui) +
      isian.terapkanIsianFotoAsli(isianDisetujui);
  kabar(
    terisi == 0
        ? l10n.lkAsliTakAdaSel
        : template.centang.isEmpty
        ? l10n.lkAsliTerisi(terisi)
        : l10n.lkAsliTerisiCentangManual(terisi),
  );

  return terisi;
}

/// Pita wajar isian kondisi lingkungan — angka di luarnya MERAH, bukan usulan.
///
/// Angkanya salinan yang sudah dipegang server (jangan diubah di sini saja):
/// suhu = `ocr.suhu.min/maks` 5–45 °C, kelembaban =
/// `CalibrationValidator::KELEMBABAN_MIN/MAKS` 20–90 %RH, tekanan udara =
/// `CalibrationRequest::TEKANAN_MIN_HPA/MAKS_HPA` 300–1100 hPa (penangkap salah
/// satuan kPa/Pa). Kode di luar ketiga keluarga itu tidak punya pita → tidak
/// pernah dibuka server untuk pindai, jadi di sini juga ditolak.
bool wajarIsianLingkungan(String kode, double nilai) {
  final ujung = kode.contains('.') ? kode.split('.').last : kode;
  final (min, maks) = switch (ujung) {
    final k when k.startsWith('suhu_') => (5.0, 45.0),
    final k when k.startsWith('kelembaban_') => (20.0, 90.0),
    final k when k.startsWith('tekanan_') => (300.0, 1100.0),
    _ => (double.nan, double.nan),
  };

  return nilai >= min && nilai <= maks;
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
      GagalPindaiAsli.revisiTidakTerbaca => l10n.lkAsliRevisiTidakTerbaca,
      GagalPindaiAsli.jangkarKurang => l10n.lkAsliJangkarKurang(e.jumlah ?? 0),
      GagalPindaiAsli.jangkarTidakMenyebar => l10n.lkAsliJangkarTidakMenyebar,
      GagalPindaiAsli.fotoTerbalik => l10n.lkAsliFotoTerbalik,
      GagalPindaiAsli.pembacaMati => l10n.lkAsliPembacaMati,
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
