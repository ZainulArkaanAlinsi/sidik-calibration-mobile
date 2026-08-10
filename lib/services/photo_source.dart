import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Dari mana foto buat OCR diambil.
///
/// Dipisah dari layar **supaya alur kameranya bisa di-widget-test**. Waktu
/// `ImagePicker()` masih dipanggil langsung di dalam widget, satu-satunya yang
/// bisa diuji cuma parser angkanya — bagian yang paling gampang salah justru
/// nggak keuji: apa yang terjadi ke kolom input setelah foto kebaca, dan apa
/// yang terjadi kalau OCR-nya gagal.
abstract class SumberFoto {
  /// `null` = user membatalkan. Bukan error, jadi layar nggak boleh nampilin
  /// pesan gagal buat kasus ini.
  Future<File?> ambil({int? maxWidth, int? imageQuality});
}

/// Kamera beneran — **cuma Android & iOS**.
///
/// `image_picker` nggak punya implementasi kamera buat macOS/Windows sama
/// sekali (nggak ada `image_picker_macos`/`_windows` di `pubspec.lock`), dan
/// app macOS-nya juga nggak minta entitlement kamera. Dipanggil di desktop,
/// ini MELEDAK — bukan kadang-kadang, selalu. Lihat [BerkasSumberFoto].
class KameraSumberFoto implements SumberFoto {
  const KameraSumberFoto();

  @override
  Future<File?> ambil({int? maxWidth, int? imageQuality}) async {
    final hasil = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth?.toDouble(),
      imageQuality: imageQuality,
    );

    return hasil == null ? null : File(hasil.path);
  }
}

/// Desktop: pilih BERKAS gambar, bukan buka kamera.
///
/// Di macOS & Windows nggak ada kamera yang bisa dipanggil `image_picker`, tapi
/// alur "foto tabel lalu dibaca AI" tetap masuk akal di sana — admin biasanya
/// udah punya fotonya dari HP teknisi. Jadi yang diganti sumbernya doang;
/// sisanya (unggah, ekstraksi, pra-isi kolom) sama persis.
///
/// Pakai `file_picker`, bukan `image_picker`: itu yang beneran punya
/// implementasi desktop, dan udah kepakai di layar Import Excel.
class BerkasSumberFoto implements SumberFoto {
  const BerkasSumberFoto();

  @override
  Future<File?> ambil({int? maxWidth, int? imageQuality}) async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'webp'],
    );

    final path = hasil?.files.single.path;
    return path == null ? null : File(path);
  }
}

/// Buat test. [file] boleh nunjuk ke path yang nggak ada — layanan OCR tiruan
/// nggak pernah beneran baca isinya.
class MockSumberFoto implements SumberFoto {
  MockSumberFoto({this.file, this.dibatalkan = false});

  final File? file;

  /// Meniru user yang buka kamera lalu mundur tanpa motret.
  final bool dibatalkan;

  /// Argumen panggilan terakhir — dipakai test buat ngunci batas ukuran foto.
  ///
  /// Bukan detail sepele: tanpa `maxWidth`, foto keluar di resolusi penuh
  /// sensor dan ditolak backend di 8 MB, jadi scan-nya gagal terus padahal
  /// kamera & AI-nya sehat. Yang gagal begini nggak keliatan di test mana pun
  /// kalau argumennya nggak pernah diperiksa.
  int? maxWidthTerakhir;
  int? kualitasTerakhir;

  @override
  Future<File?> ambil({int? maxWidth, int? imageQuality}) async {
    maxWidthTerakhir = maxWidth;
    kualitasTerakhir = imageQuality;

    return dibatalkan ? null : (file ?? File('tes-foto.png'));
  }
}
