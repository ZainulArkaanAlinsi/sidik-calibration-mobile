import 'package:image/image.dart' as img;

import 'ocr_angka/aturan_format_sel.dart';
import 'ocr_angka/keputusan_sel.dart';
import 'ocr_angka/mesin_angka.dart';
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
/// ## Bentuk keluaran ke alur yang sudah ada
///
/// [BacaanSel] tidak diubah; makna status dipetakan ke aturan yang sudah ada:
///
///  - kosong → `teks: null` (sel tetap kosong, tidak masuk review);
///  - ditahan ([StatusSelAngka.perluCek]) → `keyakinan: 0,0` → vonis MERAH,
///    kotak mulai kosong, teknisi mengetik sendiri;
///  - usulan → `keyakinan` = skor `jalur` (≥ ambang) → vonis KUNING (tulisan
///    tangan tidak pernah hijau). Skor ini BUKAN persen; layar review
///    menyembunyikan angka persen saat sakelar menyala.
class PembacaSelOnnx implements PembacaSelBerformat {
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
  ) async {
    if (aturan == null || _rusak) return _cadangan.baca(potongan);

    final mesin = await _mesin();
    if (mesin == null) {
      _rusak = true;
      return _cadangan.baca(potongan);
    }

    try {
      final hasil = await mesin.baca(potongan, aturan);
      if (hasil.alasan == AlasanSelAngka.keluaranTakValid) {
        // Keluaran model NaN/tak hingga untuk sel ini: bukan usulan, dan sel
        // tidak boleh hilang diam-diam dari review. ML Kit membacanya; mesin
        // tetap aktif untuk sel lain (bisa jadi hanya crop ini yang bermasalah).
        catat?.call('keluaran model tak valid, sel ini dibaca ML Kit');
        return _cadangan.baca(potongan);
      }

      return keBacaanSel(hasil);
    } catch (e) {
      _rusak = true;
      catat?.call('mesin angka gagal membaca sel, pakai ML Kit: $e');
      return _cadangan.baca(potongan);
    }
  }

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
