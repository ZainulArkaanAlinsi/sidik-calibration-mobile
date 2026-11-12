import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as img;

/// KUNCI "OCR tidak boleh membaca foto terkompresi" — di kode, bukan di
/// dokumen.
///
/// Kenapa: uji sintetis 11 Nov 2026 menunjukkan kompresi SEBELUM OCR membuat
/// kode formulir hilang pada 5 dari 6 foto, dan artefak JPEG di garis tipis
/// mengubah `4,04` jadi `404`. Kompresi (target <= ±500 KB) hanya sah untuk
/// SALINAN ARSIP / unggahan; yang dibaca mesin OCR harus foto kamera asli atau
/// hasil perataan (warp) dari foto asli.
///
/// Tiga lapis penjaga:
///  1. **Tipe.** Mesin OCR menerima [FotoUntukOcr] ([FotoAsliKamera] atau
///     [FotoHasilWarp]). [SalinanArsip] SENGAJA bukan subtipe-nya, jadi
///     melewatkan keluaran kompresi ke `JalankanPindaiAsli.bacaFoto` tidak
///     lolos kompilasi.
///  2. **Tanda di dalam BYTE.** Salinan arsip (JPEG) membawa penanda
///     [penandaSalinanArsip] di EXIF `ImageDescription`. Pintu masuk OCR
///     memanggil [pastikanBukanSalinanArsip] dan melempar
///     [FotoTerkompresiDitolak] bila byte (`jpegAsli`) memuat penanda itu atau
///     citranya membawa penanda itu di `exif`. Karena tandanya ada di isi
///     byte, salinan yang di-copy (`Uint8List.fromList`), dipotong (`sublist`),
///     atau didekode ulang (`img.decodeJpg`) tetap tertolak. Ditambah tanda
///     identitas objek (Expando) untuk citra turunan.
///  3. **Test arsitektur** (`test/foto_untuk_ocr_test.dart`): berkas OCR tidak
///     boleh meng-impor modul kompresi, dan modul kompresi belum punya
///     pemanggil aktif.
sealed class FotoUntukOcr {
  const FotoUntukOcr(this.citra);

  /// Piksel yang akan dibaca (belum diputar tegak oleh EXIF bila
  /// [FotoAsliKamera]; mesin OCR yang memanggangnya).
  final img.Image citra;

  /// JPEG kamera apa adanya (sebelum EXIF dipanggang), bila ada. ML Kit
  /// membacanya langsung tanpa encode ulang.
  Uint8List? get jpegAsli;
}

/// Foto yang baru keluar dari kamera/galeri: piksel dan byte JPEG-nya belum
/// pernah dikodekan ulang oleh aplikasi.
final class FotoAsliKamera extends FotoUntukOcr {
  const FotoAsliKamera(super.citra, {this.jpegAsli});

  @override
  final Uint8List? jpegAsli;
}

/// Citra hasil meluruskan halaman (page registration / homography) dari
/// [FotoAsliKamera]. Tanpa JPEG: yang dibaca piksel lurusnya.
final class FotoHasilWarp extends FotoUntukOcr {
  const FotoHasilWarp(super.citra);

  @override
  Uint8List? get jpegAsli => null;
}

/// Penanda di dalam byte salinan arsip (EXIF `ImageDescription`, ASCII). Foto
/// kamera tidak pernah memuatnya; test memeriksa foto asli tetap lolos.
const penandaSalinanArsip = 'SIDIK-ARSIP-SALINAN-v1';

/// Salinan foto yang SUDAH dikompresi untuk arsip/unggahan. Bukan
/// [FotoUntukOcr]: tidak boleh sampai ke mesin OCR.
///
/// Hanya dibuat oleh `FotoKompres` (dan test lewat [SalinanArsip.dari]).
class SalinanArsip {
  SalinanArsip._(this.byte, {required this.mime, required this.ekstensi}) {
    _tanda[byte] = true;
  }

  /// [byte] JPEG diberi [penandaSalinanArsip] di EXIF (isi byte berubah; piksel
  /// tidak). Byte non-JPEG (hanya mesin kompresi palsu di test, atau mesin
  /// native non-JPEG kelak) hanya ditandai lewat identitas objek: sebelum ada
  /// mesin non-JPEG sungguhan, penandanya WAJIB ditambahkan untuk format itu.
  factory SalinanArsip.dari(
    Uint8List byte, {
    required String mime,
    required String ekstensi,
  }) {
    final jpeg = byte.length > 2 && byte[0] == 0xff && byte[1] == 0xd8;
    final akhir = jpeg ? _sisipkanPenanda(byte) : byte;

    return SalinanArsip._(akhir, mime: mime, ekstensi: ekstensi);
  }

  final Uint8List byte;
  final String mime;
  final String ekstensi;

  /// Decode salinan untuk keperluan SELAIN OCR (mis. pratinjau). Citra yang
  /// dikembalikan membawa penanda di `exif` dan ditandai identitasnya, sehingga
  /// pintu OCR menolaknya.
  img.Image? dekode() {
    final d = img.decodeImage(byte);
    if (d != null) {
      d.exif.imageIfd.imageDescription = penandaSalinanArsip;
      _tanda[d] = true;
    }

    return d;
  }
}

Uint8List _sisipkanPenanda(Uint8List jpeg) {
  final exif = img.decodeJpgExif(jpeg) ?? img.ExifData();
  exif.imageIfd.imageDescription = penandaSalinanArsip;
  final hasil = img.injectJpgExif(jpeg, exif);
  if (hasil == null) {
    // Salinan tanpa penanda lebih berbahaya daripada gagal.
    throw StateError('Penanda salinan arsip gagal ditulis ke JPEG.');
  }

  return hasil;
}

final _tanda = Expando<bool>('salinan-arsip');

final _byteMarker = Uint8List.fromList(penandaSalinanArsip.codeUnits);

/// EXIF APP1 maksimum 64 KB dan ditaruh tepat setelah SOI; tidak perlu
/// memindai seluruh berkas.
const _batasPindai = 65536;

bool _memuatPenanda(Uint8List b) {
  final akhir =
      (b.length < _batasPindai ? b.length : _batasPindai) - _byteMarker.length;
  for (var i = 0; i <= akhir; i++) {
    if (b[i] != _byteMarker[0]) continue;
    var cocok = true;
    for (var j = 1; j < _byteMarker.length; j++) {
      if (b[i + j] != _byteMarker[j]) {
        cocok = false;
        break;
      }
    }
    if (cocok) return true;
  }

  return false;
}

/// [objek] (img.Image atau Uint8List) berasal dari [SalinanArsip]?
///
/// Identitas objek, ATAU penanda di dalam isi: byte memuat
/// [penandaSalinanArsip], atau citra membawanya di `exif.imageIfd`.
bool apakahDariSalinanArsip(Object? objek) {
  if (objek == null) return false;
  if (_tanda[objek] == true) return true;

  if (objek is Uint8List) return _memuatPenanda(objek);
  if (objek is img.Image) {
    return objek.exif.imageIfd.imageDescription == penandaSalinanArsip;
  }

  return false;
}

/// Dilempar pintu masuk OCR bila diberi citra/byte hasil kompresi.
class FotoTerkompresiDitolak extends StateError {
  FotoTerkompresiDitolak()
    : super(
        'OCR menolak foto terkompresi: kompresi hanya untuk salinan arsip. '
        'Berikan foto kamera asli atau hasil warp.',
      );
}

/// Pintu masuk OCR memanggil ini PERTAMA. Untuk foto biasa hanya memindai awal
/// byte JPEG (≤ 64 KB) dan membaca satu tag EXIF.
void pastikanBukanSalinanArsip({Object? citra, Object? jpeg}) {
  if (apakahDariSalinanArsip(citra) || apakahDariSalinanArsip(jpeg)) {
    throw FotoTerkompresiDitolak();
  }
}

/// Untuk test: tandai [objek] seolah berasal dari [SalinanArsip] (mis. citra
/// turunan lewat jalur lain).
@visibleForTesting
void tandaiSebagaiSalinanArsip(Object objek) => _tanda[objek] = true;
