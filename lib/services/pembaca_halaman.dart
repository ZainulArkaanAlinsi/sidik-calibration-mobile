import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'modul_pembaca_teks.dart';

/// Satu potongan teks hasil OCR berikut kotaknya di citra.
///
/// [keyakinan] `null` = **pengenalnya nggak memberi tahu**, bukan "yakin" dan
/// bukan "nggak yakin". ML Kit menyetel `confidence` per elemen cuma di
/// sebagian versi & perangkat; di sisanya dia pulang null. Bedanya penting:
/// null diperlakukan sebagai TIDAK DIKETAHUI oleh yang menilai, dan sel yang
/// keyakinannya tidak diketahui tidak boleh dinaikkan jadi "aman" — lihat
/// `VonisSelFoto`. Mengisi null dengan 1.0 (atau 0.0) berarti mengarang
/// keyakinan, dan itu persis yang bikin teknisi percaya angka yang belum
/// diperiksa.
typedef TeksTerbaca = ({String teks, Rect kotak, double? keyakinan});

/// JPEG kamera APA ADANYA + orientasi EXIF (1..8) yang memetakan piksel
/// tersimpannya ke bingkai citra yang sedang dibaca.
///
/// Dipakai supaya ML Kit membaca JPEG asli langsung (M01): tanpa encode ulang
/// ke PNG, tanpa menurunkan resolusi. [orientasi] wajib dihitung pemanggil
/// dari cara citranya dibentuk: `1` kalau citranya hasil `decodeImage` mentah
/// (EXIF tidak dipanggang), [orientasiSetelahPutar] kalau EXIF dipanggang lalu
/// diputar. Salah hitung = kotak teks di bingkai lain; [MlKitPembacaHalaman]
/// menjaga dengan [dalamBingkai] dan jatuh ke jalur PNG.
typedef FotoAsli = ({Uint8List jpeg, int orientasi});

/// Orientasi EXIF untuk citra yang EXIF [asal]-nya dipanggang
/// (`bakeOrientation`) lalu diputar [putar] derajat searah jarum jam
/// (`copyRotate`, kelipatan 90).
///
/// Orientasi EXIF = (cermin?, putar r) dengan transformasi `flipH . R(r)`
/// (atau `R(r)` tanpa cermin), persis definisi `bakeOrientation` paket
/// `image` 4.9.1 dan `ImageUtils` ML Kit vision-common 17.3.0 (keduanya
/// diperiksa). Memutar lagi `R(s)`: tanpa cermin `R(r+s)`; dengan cermin
/// `R(s) . flipH = flipH . R(-s)`, jadi `flipH . R(r-s)`.
int orientasiSetelahPutar(int asal, int putar) {
  const tanpaCermin = {1: 0, 6: 90, 3: 180, 8: 270};
  const denganCermin = {2: 0, 5: 90, 4: 180, 7: 270};

  final cermin = denganCermin.containsKey(asal);
  final r = cermin ? denganCermin[asal]! : (tanpaCermin[asal] ?? 0);
  final total = ((cermin ? r - putar : r + putar) % 360 + 360) % 360;
  final peta = cermin ? denganCermin : tanpaCermin;

  return peta.entries.firstWhere((e) => e.value == total).key;
}

/// Bita JPEG yang diserahkan ke ML Kit untuk [asli]: bita aslinya sendiri
/// (identik, tanpa salinan) kalau orientasi EXIF-nya sudah
/// [FotoAsli.orientasi]; kalau beda, salinan yang HANYA blok EXIF-nya ditulis
/// ulang (`injectJpgExif`). Data gambar terkompresinya disalin byte per byte,
/// tidak di-decode, tidak di-encode ulang.
///
/// `null` = bukan JPEG atau EXIF-nya tak bisa ditulis ulang, pemanggil
/// memakai jalur PNG.
@visibleForTesting
Uint8List? jpegUntukMlKit(FotoAsli asli) {
  final b = asli.jpeg;
  if (b.length < 4 || b[0] != 0xff || b[1] != 0xd8) return null;

  try {
    final exif = img.decodeJpgExif(b);
    final sekarang = exif?.imageIfd.orientation ?? 1;
    final sah = sekarang >= 1 && sekarang <= 8 ? sekarang : 1;
    if (sah == asli.orientasi) return b;

    final baru = img.ExifData.from(exif);
    baru.imageIfd.orientation = asli.orientasi;

    return img.injectJpgExif(b, baru);
  } catch (_) {
    return null;
  }
}

/// Semua kotak [terbaca] duduk di dalam citra [lebar] x [tinggi] (toleransi
/// 1% sisi terpanjang, minimal 4 px)?
///
/// Penjaga bingkai: kalau orientasi yang dipakai ML Kit ternyata beda dari
/// citra yang dipegang Dart (EXIF tak terbaca perangkat, dsb.), kotak teks
/// biasanya keluar dari citra yang lebih sempit. Itu harus berhenti di sini,
/// bukan menjadi homografi yang memotong sel di tempat yang salah.
@visibleForTesting
bool dalamBingkai(List<TeksTerbaca> terbaca, int lebar, int tinggi) {
  final sisi = lebar > tinggi ? lebar : tinggi;
  final tol = sisi * 0.01 < 4 ? 4.0 : sisi * 0.01;

  for (final t in terbaca) {
    final k = t.kotak;
    if (k.left < -tol ||
        k.top < -tol ||
        k.right > lebar + tol ||
        k.bottom > tinggi + tol) {
      return false;
    }
  }

  return true;
}

/// Baca SELURUH citra tabel sekaligus, lengkap dengan posisi tiap teksnya.
///
/// ## Bedanya dari [PembacaSel]
///
/// [PembacaSel] membaca satu potongan yang kuncinya sudah ditentukan SEBELUM
/// dibaca — itu jalur lembar bermarker, dan di situ posisi tidak pernah jadi
/// pertanyaan.
///
/// Di sini kebalikannya: yang difoto satu tabel apa adanya, tanpa marker, jadi
/// yang tersedia cuma teks + posisinya. Posisi itu **tidak dipakai buat
/// menebak** baris/kolom dari urutan — dia dipakai buat mengukur jarak ke
/// jangkar yang TERCETAK di tabelnya sendiri (nilai standar di kolom kiri,
/// nomor X1..Xn di kepala kolom). Aturannya ada di `PetaTabelFoto`.
/// Hapus sisa berkas sementara pindai (`tabel-*` dari [MlKitPembacaHalaman],
/// `sel-*` dari `MlKitPembacaSel`) di [dir] yang lebih tua dari [umur].
///
/// Berkas itu potongan/foto lembar kerja pelanggan (JPEG bisa membawa EXIF
/// GPS). Normalnya dihapus di `finally`, tapi kalau proses dimatikan di
/// tengah baca, dia tertinggal di cache app (temuan peninjau M01 #4).
/// Yang masih muda dibiarkan: bisa jadi milik pembacaan yang sedang jalan.
/// Mengembalikan jumlah yang dihapus; galat per berkas ditelan.
Future<int> sapuBerkasPindaiLama(
  Directory dir, {
  Duration umur = const Duration(minutes: 10),
  DateTime? sekarang,
}) async {
  final batas = (sekarang ?? DateTime.now()).subtract(umur);
  var dihapus = 0;

  if (!dir.existsSync()) return 0;

  for (final f in dir.listSync().whereType<File>()) {
    final nama = f.uri.pathSegments.last;
    if (!(nama.startsWith('tabel-') || nama.startsWith('sel-'))) continue;
    if (!(nama.endsWith('.jpg') || nama.endsWith('.png'))) continue;

    try {
      if (f.lastModifiedSync().isBefore(batas)) {
        f.deleteSync();
        dihapus++;
      }
    } catch (_) {
      // Berkas yang sedang dipakai/terkunci: coba lagi di sapuan berikutnya.
    }
  }

  return dihapus;
}

abstract class PembacaHalaman {
  /// Baca [citra]. [asli] (opsional) = JPEG kamera yang menghasilkan [citra];
  /// kalau ada, implementasi boleh membaca JPEG itu langsung asalkan kotak
  /// yang dipulangkan tetap dalam bingkai [citra].
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli});

  Future<void> tutup();
}

class MlKitPembacaHalaman implements PembacaHalaman {
  /// Parameter `@visibleForTesting` hanya untuk test: [proses] menggantikan
  /// ML Kit, [folderSementara] menggantikan `getTemporaryDirectory`,
  /// [jpegLangsung] menggantikan pemeriksaan platform.
  MlKitPembacaHalaman({
    @visibleForTesting Future<RecognizedText> Function(InputImage)? proses,
    @visibleForTesting Future<Directory> Function()? folderSementara,
    @visibleForTesting bool? jpegLangsung,
  }) : _proses = proses,
       _folderSementara = folderSementara ?? getTemporaryDirectory,
       // Hanya Android yang diperiksa: `InputImage.fromFilePath` di sana
       // memanggang EXIF orientasi persis seperti `bakeOrientation`
       // (vision-common 17.3.0 `ImageUtils`). iOS belum diperiksa, jadi tetap
       // PNG yang bingkainya pasti sama dengan citra Dart.
       _jpegLangsung = jpegLangsung ?? Platform.isAndroid;

  final Future<RecognizedText> Function(InputImage)? _proses;
  final Future<Directory> Function() _folderSementara;
  final bool _jpegLangsung;

  TextRecognizer? _pengenal;

  /// Penomor berkas sementara: dua pembacaan yang berdekatan tidak boleh
  /// berbagi nama berkas.
  static int _nomor = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    // JPEG ASLI dulu (M01): ML Kit men-decode sendiri JPEG kamera dengan
    // resolusi penuh, tanpa encode ulang PNG sehalaman yang makan detik.
    final jpeg = asli != null && _jpegLangsung ? jpegUntukMlKit(asli) : null;

    if (jpeg != null) {
      final terbaca = await _bacaBerkas('jpg', jpeg);

      if (dalamBingkai(terbaca, citra.width, citra.height)) return terbaca;
      // Bingkai ML Kit beda dari citra Dart: JANGAN dipakai; baca ulang
      // lewat PNG yang bingkainya pasti sama.
    }

    // Jalur cadangan. PNG foto 12 MP butuh beberapa detik, jadi di isolate
    // latar. PNG lossless: yang dibaca ML Kit sama persis dengan citra Dart.
    return _bacaBerkas('png', await compute(_png, citra));
  }

  Future<List<TeksTerbaca>> _bacaBerkas(String ekstensi, Uint8List bita) async {
    // Ditulis ke folder sementara app, BUKAN galeri atau folder bersama.
    // Isinya lembar kerja pelanggan.
    final dir = await _folderSementara();
    final berkas = File(
      '${dir.path}/tabel-${DateTime.now().microsecondsSinceEpoch}'
      '-${_nomor++}.$ekstensi',
    );

    try {
      await berkas.writeAsBytes(bita);

      final input = InputImage.fromFilePath(berkas.path);
      final proses = _proses;
      // Modul ML Kit unbundled yang belum terunduh → galat bernama sendiri.
      final hasil = await denganModulPembacaTeks(
        () => proses != null
            ? proses(input)
            : (_pengenal ??= TextRecognizer(
                script: TextRecognitionScript.latin,
              )).processImage(input),
      );
      final keluar = <TeksTerbaca>[];

      // Diambil per ELEMENT, bukan per baris atau blok. Satu baris tabel
      // sering kebaca ML Kit sebagai satu `TextLine` berisi seluruh angka di
      // baris itu (`279,6 280,00 280,00 280,00`) — dipakai apa adanya, posisi
      // tiap angkanya hilang dan yang tersisa cuma urutan. Element paling kecil
      // yang masih punya kotaknya sendiri.
      for (final blok in hasil.blocks) {
        for (final baris in blok.lines) {
          for (final e in baris.elements) {
            final teks = e.text.trim();
            if (teks.isEmpty) continue;

            keluar.add((
              teks: teks,
              kotak: Rect.fromLTRB(
                e.boundingBox.left.toDouble(),
                e.boundingBox.top.toDouble(),
                e.boundingBox.right.toDouble(),
                e.boundingBox.bottom.toDouble(),
              ),
              // Dibawa apa adanya, termasuk `null`-nya. ML Kit menyetelnya per
              // elemen cuma di sebagian versi & perangkat, dan yang null WAJIB
              // tetap null sampai ke layar review — di situ dia ditampilkan
              // sebagai "tidak diketahui", bukan disamarkan jadi angka.
              keyakinan: e.confidence,
            ));
          }
        }
      }

      return keluar;
    } finally {
      if (berkas.existsSync()) berkas.deleteSync();
    }
  }

  @override
  Future<void> tutup() async => _pengenal?.close();
}

/// Fungsi puncak buat [compute] — yang dikirim ke isolate cuma citranya.
Uint8List _png(img.Image citra) => img.encodePng(citra);

/// Tiruan buat test — teks & kotaknya dititipin, jadi pemetaannya bisa diuji
/// tanpa ML Kit maupun kamera.
class MockPembacaHalaman implements PembacaHalaman {
  MockPembacaHalaman(this.terbaca);

  final List<TeksTerbaca> terbaca;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async =>
      terbaca;

  @override
  Future<void> tutup() async {}
}
