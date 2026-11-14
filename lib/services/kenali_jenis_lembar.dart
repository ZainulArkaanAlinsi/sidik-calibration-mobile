import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'jenis_lembar.dart';
import 'pembaca_halaman.dart';

/// Urutan putaran yang dicoba mengenali kode formulir: tegak dulu, lalu 90°,
/// lalu 180° dan 270°. Formulir lanskap yang difoto dengan HP tegak muncul
/// terbaring, dan jenis lembarnya belum diketahui di tahap ini, jadi bentuk
/// halaman tidak bisa dipakai memilih urutan.
const urutanSudutKenali = [0, 90, 180, 270];

/// Memutar [foto] searah jarum jam sebesar [sudut] derajat setelah EXIF
/// orientasinya dipanggang. Default-nya jalan di isolate latar.
typedef PutarFoto = Future<img.Image> Function(img.Image foto, int sudut);

/// Mengenali JENIS lembar dari satu foto seluruh halaman, tanpa tahu dulu
/// jenisnya: pembaca halaman (ML Kit sehalaman) dicoba tiap putaran di
/// [sudut] dan berhenti begitu KODE FORMULIR (`SIDIK-FM-CAL-05xx`) terbaca,
/// terkenal server atau tidak.
///
/// Hasilnya hanya petunjuk untuk lembar pilihan jenis (lihat
/// `jenis_lembar.dart`): tidak mengunci, tidak mengisi sel, tidak menavigasi.
/// Kalau tidak ada putaran yang menghasilkan kode, petunjuk dari JUDUL
/// tercetak (kalau ada) dikembalikan; kalau itu pun tidak ada, `null` dan
/// pemanggil menampilkan daftar manual.
///
/// Pemanggil memegang [halaman] dan wajib menutupnya (`finally`); fungsi ini
/// tidak membuat dan tidak menutup pembaca.
///
/// [jpegAsli] = JPEG kamera apa adanya (dibaca ML Kit langsung, tanpa encode
/// ulang PNG). Orientasinya dihitung dari EXIF [foto] dan [sudut] seperti
/// `JalankanPindaiAsli._kenali`, dan [MlKitPembacaHalaman] menjaga bingkainya.
Future<HasilJenisLembar?> kenaliJenisLembar({
  required img.Image foto,
  required PembacaHalaman halaman,
  required List<FormulirDikenal> dikenal,
  Uint8List? jpegAsli,
  PutarFoto putar = putarFotoDiIsolate,
  List<int> sudut = urutanSudutKenali,
}) async {
  final ifd = foto.exif.imageIfd;
  final orientasiAsal = ifd.hasOrientation ? ifd.orientation ?? 1 : 1;

  HasilJenisLembar? dariJudul;

  for (final s in sudut) {
    // Citra yang dibaca = EXIF dipanggang lalu diputar [s]; foto asli dipakai
    // apa adanya hanya bila itu sudah identik (tanpa salinan puluhan MB).
    final citra = orientasiAsal == 1 && s == 0 ? foto : await putar(foto, s);

    final terbaca = await halaman.baca(
      citra,
      asli: jpegAsli == null
          ? null
          : (
              jpeg: jpegAsli,
              orientasi: orientasiSetelahPutar(orientasiAsal, s),
            ),
    );

    final hasil = detectWorksheetType(teksHalaman(terbaca), dikenal: dikenal);
    if (hasil == null) continue;
    if (hasil.sumber == SumberJenisLembar.kodeFormulir) return hasil;

    dariJudul ??= hasil;
  }

  return dariJudul;
}

img.Image _putar(({img.Image foto, int sudut}) a) =>
    img.copyRotate(img.bakeOrientation(a.foto), angle: a.sudut);

/// Fungsi puncak yang membungkus `Isolate.run` (bukan closure di dalam metode):
/// yang dikirim ke isolate cuma [foto] dan [sudut].
Future<img.Image> putarFotoDiIsolate(img.Image foto, int sudut) =>
    Isolate.run(() => _putar((foto: foto, sudut: sudut)));
