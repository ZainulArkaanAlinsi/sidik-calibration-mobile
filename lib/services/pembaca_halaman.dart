import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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
abstract class PembacaHalaman {
  Future<List<TeksTerbaca>> baca(img.Image citra);

  Future<void> tutup();
}

class MlKitPembacaHalaman implements PembacaHalaman {
  MlKitPembacaHalaman();

  final _pengenal = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra) async {
    // Ditulis ke folder sementara app — BUKAN galeri atau folder bersama.
    // Isinya lembar kerja pelanggan.
    final dir = await getTemporaryDirectory();
    final berkas = File(
      '${dir.path}/tabel-${DateTime.now().microsecondsSinceEpoch}.png',
    );

    try {
      await berkas.writeAsBytes(img.encodePng(citra));

      final hasil = await _pengenal.processImage(InputImage.fromFile(berkas));
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
  Future<void> tutup() => _pengenal.close();
}

/// Tiruan buat test — teks & kotaknya dititipin, jadi pemetaannya bisa diuji
/// tanpa ML Kit maupun kamera.
class MockPembacaHalaman implements PembacaHalaman {
  MockPembacaHalaman(this.terbaca);

  final List<TeksTerbaca> terbaca;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra) async => terbaca;

  @override
  Future<void> tutup() async {}
}
