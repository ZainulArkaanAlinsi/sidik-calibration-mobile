import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'simpanan_contoh_sel.dart';

/// Kualitas JPEG contoh sel. Potongan abu-abu satu sel; ~70 cukup untuk
/// melatih pengenal digit dan jauh lebih kecil dari PNG berwarna.
const kualitasJpegContoh = 70;

/// Satu sel yang DIKONFIRMASI teknisi di layar review foto.
///
/// [label] = nilai AKHIR yang dia setujui/ketik (bukan bacaan OCR).
/// [png] = potongan sel dari halaman yang sudah diratakan (di memori).
typedef SelTerkonfirmasi = ({
  String label,
  Uint8List png,
  String fieldId,
  String? bacaanOcr,
});

/// PNG potongan → JPEG ABU-ABU q[kualitas]. `null` kalau PNG tak terbaca.
Uint8List? jpegAbuDariPng(Uint8List png, {int kualitas = kualitasJpegContoh}) {
  final c = img.decodePng(png);
  if (c == null) return null;

  return img.encodeJpg(img.grayscale(c), quality: kualitas);
}

/// Konversi banyak potongan sekaligus di isolate latar (decode+encode piksel).
Future<List<Uint8List?>> jpegAbuDariPngDiIsolate(List<Uint8List> png) =>
    Isolate.run(() => [for (final p in png) jpegAbuDariPng(p)]);

/// Simpan contoh sel terkonfirmasi ke [simpanan] — HANYA lokal di HP.
///
/// Tidak ada unggah dan tidak ada ekspor (menunggu Gerbang 0 privasi). Foto
/// penuh TIDAK disimpan: yang ditulis cuma potongan sel abu-abu + label. Sel
/// berlabel kosong dilewati. Mengembalikan jumlah contoh yang tersimpan.
///
/// Pemanggil wajib memeriksa sakelar `kumpulkanContohSel` lebih dulu
/// (bawaan MATI) — fungsi ini sendiri tidak membaca sakelar.
Future<int> simpanContohTerkonfirmasi({
  required SimpananContohSel simpanan,
  required List<SelTerkonfirmasi> sel,
  required String lembar,
}) async {
  final layak = [
    for (final s in sel)
      if (s.label.trim().isNotEmpty && s.png.isNotEmpty) s,
  ];
  if (layak.isEmpty) return 0;

  final jpeg = await jpegAbuDariPngDiIsolate([for (final s in layak) s.png]);
  var n = 0;

  for (var i = 0; i < layak.length; i++) {
    final b = jpeg[i];
    if (b == null) continue;

    final c = await simpanan.simpanBita(
      bita: b,
      ekstensi: 'jpg',
      label: layak[i].label,
      lembar: lembar,
      fieldId: layak[i].fieldId,
      bacaanOcr: layak[i].bacaanOcr,
    );
    if (c != null) n++;
  }

  return n;
}
