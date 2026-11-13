import 'dart:io';

import 'package:flutter/widgets.dart';

import 'petunjuk_kamera.dart';

/// Awalan nama berkas jepretan kamera sendiri di cache app. Foto itu lembar
/// kerja pelanggan: normalnya dihapus begitu terbaca, dan kalau proses mati
/// sebelum itu, `sapuBerkasPindaiLama` menyapunya lewat awalan ini.
const awalanBerkasKamera = 'pindai-kamera-';

/// Kenapa kamera sendiri tidak bisa dipakai — dan alur jatuh ke cadangan
/// (`image_picker`, kamera sistem).
enum SebabKameraGagal {
  /// Izin kamera ditolak (atau dibatasi sistem).
  izinDitolak,

  /// Perangkat tidak punya kamera.
  tidakAda,

  /// Kamera ada tapi gagal dibuka/diinisialisasi (dipakai app lain, driver,
  /// kombinasi resolusi tidak didukung, dst.).
  gagalMulai,
}

class KameraGagal implements Exception {
  const KameraGagal(this.sebab, [this.detail]);

  final SebabKameraGagal sebab;

  /// Galat mentah — HANYA untuk log, tidak pernah ke layar.
  final Object? detail;

  @override
  String toString() => 'KameraGagal(${sebab.name})';
}

/// Hasil satu kali layar kamera dibuka.
sealed class HasilKamera {
  const HasilKamera();
}

/// Teknisi memotret. [berkas] JPEG apa adanya dari kamera, di cache app.
class KameraFoto extends HasilKamera {
  const KameraFoto(this.berkas);

  final File berkas;
}

/// Teknisi menutup kamera tanpa memotret. Bukan galat.
class KameraDibatalkan extends HasilKamera {
  const KameraDibatalkan();
}

/// Kamera sendiri tidak bisa dipakai → pemanggil jatuh ke cadangan.
class KameraTakBisa extends HasilKamera {
  const KameraTakBisa(this.sebab, [this.detail]);

  final SebabKameraGagal sebab;
  final Object? detail;
}

/// Antarmuka KECIL ke kamera, supaya layar kamera bisa diuji dengan tiruan:
/// plugin `camera` tidak jalan di `flutter test`.
///
/// Satu objek = satu sesi kamera yang sudah terbuka. [lepas] wajib dipanggil
/// saat sesi selesai (layar dibuang, app ke latar).
abstract class KontrolKamera {
  /// Pratinjau langsung. [lapisan] digambar DI ATAS pratinjau dalam ruang
  /// koordinat yang sama (ukuran = ukuran pratinjau), jadi titik ketuk di
  /// [lapisan] bisa langsung dinormalkan ke 0..1 untuk [fokusDi].
  Widget bangunPratinjau(BuildContext context, {Widget? lapisan});

  /// Perangkat (tampaknya) punya senter yang bisa dinyalakan. Bisa berubah
  /// menjadi `false` setelah [aturSenter] gagal.
  bool get senterTersedia;

  bool get senterNyala;

  /// Nyalakan/matikan senter (torch). `false` = gagal/tidak didukung; keadaan
  /// senter tidak berubah dan [senterTersedia] menjadi `false`.
  Future<bool> aturSenter(bool nyala);

  /// Fokus dan ukur eksposur di [titik] (0..1 terhadap pratinjau, pojok kiri
  /// atas = 0,0). Gagal didukung → diam (fokus otomatis tetap jalan).
  Future<void> fokusDi(Offset titik);

  /// Platform mengirim contoh frame ([ambilContoh]).
  bool get bisaContoh;

  /// Satu contoh frame untuk petunjuk. `null` = tidak ada frame tepat waktu.
  /// Sengaja SATU frame per panggilan: aliran frame terus-menerus memindahkan
  /// puluhan MB per detik ke Dart, terlalu mahal untuk HP murah.
  Future<FrameLuma?> ambilContoh();

  /// Jepret. JPEG langsung dari kamera (tidak dikodekan ulang) di cache app.
  Future<File> jepret();

  /// Lepas kamera. Aman dipanggil berkali-kali.
  Future<void> lepas();
}

/// Membuka sesi kamera. Melempar [KameraGagal] kalau tidak bisa.
typedef PabrikKontrolKamera = Future<KontrolKamera> Function();

/// Membuka layar kamera dan menunggu hasilnya.
typedef BukaLayarKamera = Future<HasilKamera> Function({double? rasioKertas});
