import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/notification_item.dart';
import '../services/notifikasi_perangkat.dart';

/// Notifikasi sistem operasi. **Mock (no-op)** di mode mock — dev & test nggak
/// boleh nembak plugin native, dan nggak ada yang mau bilah notifikasinya
/// kebanjiran data contoh waktu lagi ngoding.
final notifikasiPerangkatProvider = Provider<NotifikasiPerangkat>((ref) {
  if (AppConfig.useMock) return MockNotifikasiPerangkat();
  return LocalNotifikasiPerangkat();
});

/// Yang mutusin notifikasi mana yang layak nongol di bilah sistem.
///
/// Backend cuma ngabarin "ada yang berubah" lewat websocket; isi notifikasinya
/// tetap ditarik lewat REST. Jadi yang dilakuin di sini: bandingin daftar yang
/// baru ditarik sama yang UDAH pernah diumumkan, lalu umumin selisihnya.
final pengabarNotifikasiProvider = Provider<PengabarNotifikasi>(
  (ref) => PengabarNotifikasi(ref.watch(notifikasiPerangkatProvider)),
);

class PengabarNotifikasi {
  PengabarNotifikasi(this._perangkat);

  final NotifikasiPerangkat _perangkat;

  /// Id yang udah pernah kelihatan — dibaca maupun belum.
  ///
  /// Isinya id notifikasi Laravel (UUID), bukan nomor urut, jadi aman walau
  /// backend nyisipin notifikasi lama yang telat masuk.
  final Set<String> _sudah = {};

  /// Sekali di awal sambungan: catat semua yang UDAH ada tanpa nampilin
  /// apa-apa, lalu minta izin notifikasi.
  ///
  /// Tanpa ini, admin yang login pagi hari dengan 20 notifikasi belum dibaca
  /// bakal kena 20 notifikasi sistem sekaligus — dan yang kayak gitu bukan
  /// bikin dia sadar, tapi bikin dia matiin notifikasi app-nya selamanya.
  ///
  /// Izinnya diminta DI SINI, bukan waktu app pertama kebuka: orang yang
  /// ditanya sebelum tahu app-nya buat apa nolaknya sambil lalu.
  Future<void> mulai(List<NotificationItem> daftar) async {
    _sudah.addAll(daftar.map((n) => n.id));
    await _perangkat.siapkan();
  }

  /// Umumin yang beneran baru. Yang udah dibaca dilewat — kalau orangnya udah
  /// mbuka di HP, laptopnya nggak perlu ikut bunyi.
  Future<void> umumkan(List<NotificationItem> daftar) async {
    final baru = [
      for (final n in daftar)
        if (!n.dibaca && !_sudah.contains(n.id)) n,
    ];

    _sudah.addAll(daftar.map((n) => n.id));

    // Dibalik: daftar dari API urutannya terbaru-duluan, sementara bilah
    // notifikasi numpuk dari bawah — jadi yang dikirim duluan mesti yang
    // paling lama biar yang terbaru berakhir di paling atas.
    for (final n in baru.reversed) {
      await _perangkat.tampilkan(n);
    }
  }
}
