import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';

import 'kamera_pindai.dart';

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
  ///
  /// Izin kamera ditolak / kamera tidak ada dilempar sebagai
  /// `PlatformException` (`camera_access_denied`, `no_available_camera`) —
  /// diterjemahkan ke kalimat manusia oleh `pesanGalatPindai`.
  ///
  /// [rasioKertas] (lebar ÷ tinggi halaman lembar kerja, bila templatnya
  /// tahu) hanya dipakai kamera sendiri untuk menggambar bingkai panduan;
  /// sumber lain mengabaikannya.
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  });

  /// Foto yang SUDAH dijepret tapi hasilnya hilang karena Android mematikan
  /// aplikasi selama kamera terbuka (HP RAM kecil). `null` = tidak ada.
  ///
  /// Hanya Android yang bisa begini; sumber lain selalu `null`.
  Future<File?> ambilFotoTertinggal();
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
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    final hasil = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth?.toDouble(),
      maxHeight: maxHeight?.toDouble(),
      imageQuality: imageQuality,
    );

    return hasil == null ? null : File(hasil.path);
  }

  /// `ImagePicker.retrieveLostData()` (image_picker 1.2.x, Android saja —
  /// platform lain melempar `UnimplementedError`). Respons kosong = tidak ada
  /// yang hilang; respons galat (mis. izin ditolak sebelum aplikasi mati)
  /// dicatat lalu dianggap tidak ada foto.
  @override
  Future<File?> ambilFotoTertinggal() async {
    if (!Platform.isAndroid) return null;

    try {
      final r = await ImagePicker().retrieveLostData();
      if (r.isEmpty) return null;
      if (r.exception case final e?) {
        debugPrint('KameraSumberFoto: foto tertinggal gagal: ${e.code}');
        return null;
      }

      final f = r.file ?? r.files?.firstOrNull;
      return f == null ? null : File(f.path);
    } catch (e) {
      debugPrint('KameraSumberFoto: retrieveLostData gagal: $e');
      return null;
    }
  }
}

/// Kamera SENDIRI milik aplikasi (layar kamera dengan senter, ketuk-untuk-
/// fokus, dan petunjuk langsung) — **cuma Android & iOS**.
///
/// ## Kenapa bukan `image_picker`
///
/// `image_picker` hanya melempar intent ke app kamera sistem: tidak bisa
/// menyalakan senter untuk ruang gelap, tidak bisa diberi bingkai panduan, dan
/// di Android men-decode lalu menekan ulang JPEG-nya (`ImageResizer`) sehingga
/// fotonya bukan "apa adanya". Di sini JPEG langsung dari kamera, di cache app
/// (bukan galeri), tidak dikodekan ulang. Batas sisi 4200 px alur pindai
/// dijaga oleh resolusi kamera (3840 px), bukan oleh pengecilan.
///
/// ## Cadangan
///
/// Kamera tidak ada atau gagal diinisialisasi → jatuh ke [cadangan] dengan
/// argumen yang sama, jadi perilakunya persis alur lama. Izin ditolak TIDAK
/// jatuh ke cadangan: layar kamera menjelaskan langkah manualnya sendiri
/// (`image_picker` butuh izin CAMERA yang sama, jadi bukan jalan keluar).
/// Teknisi yang menutup kamera sendiri → `null` (batal), BUKAN jatuh ke
/// cadangan.
///
/// Layar kamera dibuka lewat [bukaLayar] (diisi `sumberFotoProvider`), supaya
/// berkas ini tetap bebas dari UI dan navigasi.
class KameraAplikasiSumberFoto implements SumberFoto {
  const KameraAplikasiSumberFoto({
    required this.bukaLayar,
    this.cadangan = const KameraSumberFoto(),
  });

  final BukaLayarKamera bukaLayar;
  final SumberFoto cadangan;

  @override
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    HasilKamera hasil;
    try {
      hasil = await bukaLayar(rasioKertas: rasioKertas);
    } catch (e) {
      // Layar kamera tidak boleh membuat alur foto mati: cadangan masih ada.
      debugPrint('KameraAplikasiSumberFoto: layar kamera gagal: $e');
      hasil = KameraTakBisa(SebabKameraGagal.gagalMulai, e);
    }

    return switch (hasil) {
      KameraFoto(:final berkas) => berkas,
      KameraDibatalkan() => null,
      KameraTakBisa() => await cadangan.ambil(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      ),
    };
  }

  /// Foto tertinggal hanya mungkin dari kamera sistem (cadangan): kamera
  /// sendiri berjalan di dalam proses aplikasi, jadi kalau proses mati tidak
  /// ada jepretan yang tertinggal.
  @override
  Future<File?> ambilFotoTertinggal() => cadangan.ambilFotoTertinggal();
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
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'webp'],
    );

    final path = hasil?.files.single.path;
    return path == null ? null : File(path);
  }

  @override
  Future<File?> ambilFotoTertinggal() async => null;
}

/// Buat test. [file] boleh nunjuk ke path yang nggak ada — layanan OCR tiruan
/// nggak pernah beneran baca isinya.
class MockSumberFoto implements SumberFoto {
  MockSumberFoto({
    this.file,
    this.dibatalkan = false,
    this.galat,
    this.tertinggal,
  });

  final File? file;

  /// Dilempar oleh [ambil] — meniru izin kamera ditolak, dsb.
  final Object? galat;

  /// Dipulangkan SEKALI oleh [ambilFotoTertinggal], seperti image_picker.
  File? tertinggal;

  /// Berapa kali [ambil] (kamera) benar-benar dipanggil.
  int jumlahAmbil = 0;

  /// Meniru user yang buka kamera lalu mundur tanpa motret.
  final bool dibatalkan;

  /// Argumen panggilan terakhir — dipakai test buat ngunci batas ukuran foto.
  ///
  /// Bukan detail sepele: tanpa `maxWidth`, foto keluar di resolusi penuh
  /// sensor dan ditolak backend di 8 MB, jadi scan-nya gagal terus padahal
  /// kamera & AI-nya sehat. Yang gagal begini nggak keliatan di test mana pun
  /// kalau argumennya nggak pernah diperiksa.
  int? maxWidthTerakhir;
  int? maxHeightTerakhir;
  int? kualitasTerakhir;

  /// Rasio halaman yang dikirim alur ke kamera (bingkai panduan).
  double? rasioKertasTerakhir;

  @override
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    jumlahAmbil++;
    maxWidthTerakhir = maxWidth;
    maxHeightTerakhir = maxHeight;
    kualitasTerakhir = imageQuality;
    rasioKertasTerakhir = rasioKertas;
    if (galat case final g?) throw g;

    return dibatalkan ? null : (file ?? File('tes-foto.png'));
  }

  @override
  Future<File?> ambilFotoTertinggal() async {
    final f = tertinggal;
    tertinggal = null;
    return f;
  }
}
