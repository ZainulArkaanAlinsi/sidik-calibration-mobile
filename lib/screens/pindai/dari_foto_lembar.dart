import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../models/equipment_lookup.dart';

/// Bekal lembar kerja yang dibuka dari foto beranda ("Pindai lembar kerja").
///
/// `null` di `LembarKerjaScreen.dariFoto` = lembar dibuka lewat "Mulai
/// kalibrasi" (jalur manual): tidak ada banner, tidak ada isi otomatis.
///
/// Dipisah dari layar lembar kerja (yang beku, `docs/desain-ulang/BEKU.md`)
/// supaya yang masuk ke sana hanya data dan satu callback, bukan logika alur.
class DariFotoLembar {
  const DariFotoLembar({
    required this.jpeg,
    required this.jenis,
    required this.otomatis,
    required this.gantiJenis,
    this.alatAwal,
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

  /// Alat yang sudah ditentukan alur (satu-satunya alat jenis ini, atau yang
  /// diketuk teknisi). `null` = belum ada; teknisi memilih di lembar dan
  /// menekan "Isi dari foto".
  final EquipmentLookup? alatAwal;

  /// "Ganti jenis" di banner: tampilkan pilihan jenis lain, lalu kembalikan
  /// route lembar pengganti (membawa foto yang sama), atau `null` bila
  /// teknisi membatalkan. Layar lembar yang memutuskan kapan route itu boleh
  /// menggantikan dirinya (menjaga isian yang belum disimpan).
  final Future<Route<void>?> Function(BuildContext context) gantiJenis;
}
