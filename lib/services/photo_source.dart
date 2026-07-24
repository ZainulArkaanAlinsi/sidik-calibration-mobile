import 'dart:io';

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

/// Buat test. [file] boleh nunjuk ke path yang nggak ada — layanan OCR tiruan
/// nggak pernah beneran baca isinya.
class MockSumberFoto implements SumberFoto {
  MockSumberFoto({this.file, this.dibatalkan = false});

  final File? file;

  /// Meniru user yang buka kamera lalu mundur tanpa motret.
  final bool dibatalkan;

  @override
  Future<File?> ambil({int? maxWidth, int? imageQuality}) async =>
      dibatalkan ? null : (file ?? File('tes-foto.png'));
}
