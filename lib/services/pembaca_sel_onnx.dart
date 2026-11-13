import 'package:image/image.dart' as img;

import 'ocr_angka/aturan_format_sel.dart';
import 'ocr_angka/keputusan_sel.dart';
import 'ocr_angka/mesin_angka.dart';
import 'ocr_angka/pagar_tinta.dart';
import 'ocr_angka/pemotong_sel.dart' show HasilPotongSel;
import 'pembaca_sel.dart';

/// Pembaca sel angka tulisan tangan di atas [MesinAngka], dengan ML Kit sebagai
/// CADANGAN. Dinyalakan hanya lewat sakelar developer `pakaiMesinAngkaOnnx`
/// (bawaan MATI); tanpa itu ML Kit tetap pembaca bawaan.
///
/// ## Kapan mesin angka dipakai
///
/// Hanya untuk sel yang templatnya menyebut jumlah desimalnya
/// ([AturanFormatSel.dari] ≠ `null`). Rig menunjukkan gerbang tanpa jumlah
/// desimal terlalu longgar; sel lain (isian lingkungan, jam, suhu) dibaca ML Kit
/// seperti biasa.
///
/// ## Jatuh ke ML Kit, tanpa crash
///
/// Mesin dimuat sekali, malas (saat sel pertama dibaca). Gagal muat (tidak ada
/// runtime/model, sha256 tak cocok, sesi gagal) atau galat saat membaca satu sel
/// → seluruh sisa lembar dibaca ML Kit. Galat di sini tidak pernah sampai ke
/// pemanggil.
///
/// Dua hal membuat SATU sel (bukan seluruh lembar) dibaca ML Kit, mesin tetap
/// aktif: keluaran model tak valid (`keluaranTakValid`) dan sel BERTINTA yang
/// tak bisa dibaca model ini (`ukuranTakWajar`: crop raksasa, atau hasil resize
/// lebih lebar dari kanvas model berlebar tetap). Sel itu tidak boleh hilang
/// diam-diam dari review. Sel yang memang kosong (di bawah pagar tinta) tetap
/// kosong.
///
/// ## Bentuk keluaran ke alur yang sudah ada
///
/// [BacaanSel] tidak diubah; makna status dipetakan ke aturan yang sudah ada:
///
///  - kosong → `teks: null` (sel tetap kosong, tidak masuk review);
///  - ditahan ([StatusSelAngka.perluCek]) → `keyakinan: 0,0` → vonis MERAH,
///    kotak mulai kosong, teknisi mengetik sendiri;
///  - ditahan TANPA bacaan (tinta tebal tak terbaca, pemotong tak yakin):
///    `teks: null` tetapi [BacaanSelMesin.perluCekTanpaBacaan] `true`. Alur
///    pindai menandainya lewat `HasilBacaAsli.gagalDibaca` (jalur MERAH kosong
///    yang sudah ada). Sel ini BUKAN kosong; dulu ia hilang dari review;
///  - usulan → `keyakinan` = skor `jalur` (≥ ambang) → vonis KUNING (tulisan
///    tangan tidak pernah hijau). Skor ini BUKAN persen; layar review
///    menyembunyikan angka persen saat sakelar menyala.
///
/// ## Dua crop per sel (mesin angka v2)
///
/// [bacaMesin] menerima crop sel apa adanya DAN hasil `PemotongSel`. Mesin angka
/// membaca hasil pemotong (garis tabel dihapus, hanya tulisan milik baris,
/// dipangkas ke kotak tinta); ML Kit (cadangan) tetap membaca crop sel apa
/// adanya, seperti sebelum mesin angka ada. [bacaBerformat] = tanpa pemotong:
/// mesin membaca crop yang diberikan (jalur lama, layar diagnostik).
class PembacaSelOnnx implements PembacaSelMesin {
  PembacaSelOnnx({
    required PembacaSel cadangan,
    required Future<MesinAngka?> Function() muatMesin,
    this.catat,
  }) : _cadangan = cadangan,
       _muatMesin = muatMesin;

  final PembacaSel _cadangan;
  final Future<MesinAngka?> Function() _muatMesin;

  /// Dipanggil (tanpa melempar) saat jatuh ke cadangan; hanya untuk log.
  final void Function(String pesan)? catat;

  Future<MesinAngka?>? _siap;
  bool _rusak = false;

  Future<MesinAngka?> _mesin() => _siap ??= () async {
    try {
      return await _muatMesin();
    } catch (e) {
      catat?.call('mesin angka gagal dimuat: $e');
      return null;
    }
  }();

  @override
  Future<BacaanSel> baca(img.Image potongan) => _cadangan.baca(potongan);

  @override
  Future<BacaanSel> bacaBerformat(
    img.Image potongan,
    AturanFormatSel? aturan,
  ) async => (await bacaMesin(potongan, null, aturan)).bacaan;

  @override
  Future<BacaanSelMesin> bacaMesin(
    img.Image potongan,
    HasilPotongSel? potong,
    AturanFormatSel? aturan,
  ) async {
    Future<BacaanSelMesin> cadangan({required bool bertinta}) async {
      final b = await _cadangan.baca(potongan);
      // ML Kit tidak menemukan apa pun di sel yang BERTINTA (coretan, strip,
      // timpaan): bukan sel kosong, teknisi yang memutuskan.
      final tanpaTeks = (b.teks ?? '').trim().isEmpty;

      return (bacaan: b, perluCekTanpaBacaan: tanpaTeks && bertinta);
    }

    if (aturan == null || _rusak) return cadangan(bertinta: false);

    final mesin = await _mesin();
    if (mesin == null) {
      _rusak = true;
      return cadangan(bertinta: false);
    }

    try {
      final hasil = potong == null
          ? await mesin.baca(potongan, aturan)
          : await mesin.bacaPotongan(potong, aturan);
      if (hasil.alasan == AlasanSelAngka.ukuranTakWajar) {
        // Ada tinta tetapi model ini tak bisa membacanya (mis. lebar hasil
        // resize > 320 px pada TFLite). ML Kit membacanya, seperti sebelum
        // sakelar menyala; bukan teks dari model dan bukan sel kosong.
        catat?.call('sel terlalu lebar/besar untuk mesin angka, dibaca ML Kit');
        return cadangan(bertinta: _adaTinta(potong?.crop ?? potongan));
      }
      if (hasil.alasan == AlasanSelAngka.keluaranTakValid) {
        // Keluaran model NaN/tak hingga untuk sel ini: bukan usulan, dan sel
        // tidak boleh hilang diam-diam dari review. ML Kit membacanya; mesin
        // tetap aktif untuk sel lain (bisa jadi hanya crop ini yang bermasalah).
        catat?.call('keluaran model tak valid, sel ini dibaca ML Kit');
        return cadangan(bertinta: _adaTinta(potong?.crop ?? potongan));
      }

      if (hasil.perluCekTanpaBacaan) {
        return (
          bacaan: (teks: null, keyakinan: null, didalamKotak: true),
          perluCekTanpaBacaan: true,
        );
      }

      return (bacaan: keBacaanSel(hasil), perluCekTanpaBacaan: false);
    } catch (e) {
      _rusak = true;
      catat?.call('mesin angka gagal membaca sel, pakai ML Kit: $e');
      return cadangan(bertinta: false);
    }
  }

  /// Crop punya tinta menurut pagar tinta? Dipakai bila sel dialihkan ke ML Kit.
  static bool _adaTinta(img.Image c) => PagarTinta.adaTinta(PagarTinta.ukur(c));

  /// Baca lengkap (status, bacaan mentah, skor) untuk layar diagnostik.
  /// `null` bila mesin tidak aktif.
  Future<HasilSelAngka?> bacaLengkap(
    img.Image potongan,
    AturanFormatSel aturan, {
    double? ambang,
  }) async {
    final mesin = await _mesin();
    if (mesin == null) return null;

    return mesin.baca(potongan, aturan, ambang: ambang);
  }

  @override
  Future<void> tutup() async {
    final mesin = _siap == null ? null : await _siap;
    await mesin?.tutup();
    await _cadangan.tutup();
  }

  /// Peta status → [BacaanSel] (lihat docblock kelas).
  static BacaanSel keBacaanSel(HasilSelAngka h) => switch (h.status) {
    StatusSelAngka.kosong => (teks: null, keyakinan: null, didalamKotak: true),
    StatusSelAngka.perluCek => (
      teks: h.bacaanMentah,
      keyakinan: 0.0,
      didalamKotak: true,
    ),
    // Skor selalu finit di sini (keputusan menolak NaN), tapi dijaga sekali
    // lagi: nilai tak finit tidak boleh sampai ke JSON atau perbandingan hilir.
    StatusSelAngka.usulanKeyakinanTinggi => (
      teks: h.bacaanMentah,
      keyakinan: h.jalur.isFinite ? h.jalur : 0.0,
      didalamKotak: true,
    ),
  };
}
