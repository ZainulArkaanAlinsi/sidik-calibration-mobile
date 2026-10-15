import 'notification_item.dart';

/// Satu kabar yang tampil sebagai toast di dalam aplikasi.
class KabarToast {
  const KabarToast({
    required this.judul,
    required this.isi,
    this.kategori = NotifKategori.umum,
    this.tautan,
    this.kunci,
  });

  final String judul;
  final String isi;
  final NotifKategori kategori;

  /// Tujuan ketukan (dari `data.tujuan` atau `tautan` notifikasi inbox).
  final NotifTautan? tautan;

  /// Id kabar (UUID notifikasi) kalau ada. Kabar yang sama bisa datang dua
  /// kali: lewat push FCM DAN lewat sinyal realtime → inbox; tanpa dedup
  /// pengguna melihat dua toast untuk satu kejadian.
  final String? kunci;

  String get teks => '$judul|$isi';
}
