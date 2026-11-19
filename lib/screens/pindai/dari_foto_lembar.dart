import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../services/identitas_kertas.dart';

/// Bekal lembar kerja yang dibuka dari foto beranda ("Pindai lembar kerja").
///
/// `null` di `LembarKerjaScreen.dariFoto` = lembar dibuka lewat "Mulai
/// kalibrasi" (jalur manual): tidak ada banner, tidak ada isi otomatis.
///
/// Dipisah dari layar lembar kerja (yang beku, `docs/desain-ulang/BEKU.md`)
/// supaya yang masuk ke sana hanya data dan satu callback, bukan logika alur.
///
/// Alurnya LINEAR: tidak ada alat yang dipilihkan sebelum kertas dibaca.
/// Alatnya ditentukan dari identitas yang TERTULIS di kertas ([identitas]):
/// dicocokkan ke alat terdaftar, atau dibuat lewat panel "Alat baru", dan
/// selalu dengan ketukan teknisi.
class DariFotoLembar {
  const DariFotoLembar({
    required this.jpeg,
    required this.jenis,
    required this.otomatis,
    required this.gantiJenis,
    this.identitas = IdentitasKertas.kosong,
    this.kodeDokumen,
  });

  /// Byte JPEG foto yang SUDAH dipotret di beranda (apa adanya, bukan citra
  /// decode). Dipakai SEKALI untuk membaca isi lembar; hanya di memori, tidak
  /// ditulis ke disk dan tidak diunggah. Memori: byte ini tetap dipegang
  /// widget ini dan closure route selama lembar terbuka (beberapa MB).
  final Uint8List jpeg;

  /// Nama pendek jenis lembar untuk banner ("pH Meter").
  final String jenis;

  /// `true` = jenis dikenali dan DIBUKA otomatis (kode unik + skor tinggi);
  /// `false` = teknisi mengetuk salah satu kandidat. Hanya menentukan kalimat
  /// banner.
  final bool otomatis;

  /// Identitas alat dan pemilik yang terbaca dari kertas (jangkar label cetak).
  /// Hanya USULAN: masuk lembar sebagai isian kuning yang wajib dikonfirmasi.
  final IdentitasKertas identitas;

  /// Kode formulir (`SIDIK-FM-CAL-…`) yang dibaca dari kertas, dikirim sebagai
  /// `kode_dokumen` supaya server memilih peta varian yang benar tanpa alat.
  /// `null` = tidak dikirim (peta bawaan).
  final String? kodeDokumen;

  /// "Ganti jenis" di banner: tampilkan pilihan jenis lain, lalu kembalikan
  /// route lembar pengganti (membawa foto yang sama), atau `null` bila
  /// teknisi membatalkan. Layar lembar yang memutuskan kapan route itu boleh
  /// menggantikan dirinya (menjaga isian yang belum disimpan).
  final Future<Route<void>?> Function(BuildContext context) gantiJenis;
}
