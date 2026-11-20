import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'identifikasi_lembar.dart';
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
/// [sudut]. Teks tiap putaran dinilai dengan bukti berlapis
/// (`identifikasiLembar`: kode formulir, judul, revisi). Pencarian berhenti
/// begitu satu putaran memberi KODE FORMULIR bersih (terkenal server atau
/// tidak) atau bukti berlapis yang cukup kuat untuk memilih-awal satu jenis.
/// Bukti yang masih samar tidak menghentikan pencarian: putaran lain dicoba,
/// dan yang terbaik dikembalikan.
///
/// Hasilnya hanya petunjuk untuk lembar pilihan jenis (lihat
/// `jenis_lembar.dart`): tidak mengunci, tidak mengisi sel, tidak menavigasi.
/// Kalau tidak ada putaran yang menghasilkan bukti sama sekali, `null` dan
/// pemanggil menampilkan daftar manual.
///
/// Pemanggil memegang [halaman] dan wajib menutupnya (`finally`); fungsi ini
/// tidak membuat dan tidak menutup pembaca.
///
/// [jpegAsli] = JPEG kamera apa adanya (dibaca ML Kit langsung, tanpa encode
/// ulang PNG). Orientasinya dihitung dari EXIF [foto] dan [sudut] seperti
/// `JalankanPindaiAsli._kenali`, dan [MlKitPembacaHalaman] menjaga bingkainya.
///
/// [padaTeksHalaman] (opsional) dipanggil SEKALI dengan elemen teks + kotaknya
/// dari putaran yang menghasilkan hasil yang dikembalikan (kertas sudah tegak).
/// Itu bahan membaca identitas kertas (`bacaIdentitasKertas`) tanpa membaca
/// halaman kedua kali; tidak dipanggil bila tidak ada petunjuk sama sekali.
/// Teks hanya dipegang di memori; tidak ada citra yang keluar dari sini.
Future<HasilJenisLembar?> kenaliJenisLembar({
  required img.Image foto,
  required PembacaHalaman halaman,
  required List<FormulirDikenal> dikenal,
  Uint8List? jpegAsli,
  PutarFoto putar = putarFotoDiIsolate,
  List<int> sudut = urutanSudutKenali,
  void Function(List<TeksTerbaca> terbaca)? padaTeksHalaman,
}) async {
  final ifd = foto.exif.imageIfd;
  final orientasiAsal = ifd.hasOrientation ? ifd.orientation ?? 1 : 1;

  HasilJenisLembar? terbaik;
  List<TeksTerbaca>? teksTerbaik;

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

    final hasil = identifikasiLembar(teksHalaman(terbaca), dikenal: dikenal);
    if (hasil == null) continue;
    if (_cukupUntukBerhenti(hasil)) {
      padaTeksHalaman?.call(terbaca);

      return hasil;
    }

    if (terbaik == null || _lebihBaik(hasil, terbaik)) {
      terbaik = hasil;
      teksTerbaik = terbaca;
    }
  }

  if (teksTerbaik != null) padaTeksHalaman?.call(teksTerbaik);

  return terbaik;
}

/// Kode bersih (dikenal atau tidak) atau pilih-awal berlapis: tidak ada gunanya
/// memutar lagi (membaca ulang foto 4200 px memakan detik).
bool _cukupUntukBerhenti(HasilJenisLembar h) =>
    h.sumber == SumberJenisLembar.kodeFormulir || h.praPilihTemplateId != null;

/// Antar putaran yang sama-sama belum cukup: bukti kode mengalahkan judul
/// saja, lalu skor teratas yang lebih tinggi, lalu kandidat yang lebih sedikit.
bool _lebihBaik(HasilJenisLembar a, HasilJenisLembar b) {
  final dariKodeA = a.sumber != SumberJenisLembar.judul;
  final dariKodeB = b.sumber != SumberJenisLembar.judul;
  if (dariKodeA != dariKodeB) return dariKodeA;

  final skorA = a.peringkat.isEmpty ? 0.0 : a.peringkat.first.skor;
  final skorB = b.peringkat.isEmpty ? 0.0 : b.peringkat.first.skor;
  if (skorA != skorB) return skorA > skorB;

  return a.kandidat.length < b.kandidat.length;
}

img.Image _putar(({img.Image foto, int sudut}) a) =>
    img.copyRotate(img.bakeOrientation(a.foto), angle: a.sudut);

/// Fungsi puncak yang membungkus `Isolate.run` (bukan closure di dalam metode):
/// yang dikirim ke isolate cuma [foto] dan [sudut].
Future<img.Image> putarFotoDiIsolate(img.Image foto, int sudut) =>
    Isolate.run(() => _putar((foto: foto, sudut: sudut)));
