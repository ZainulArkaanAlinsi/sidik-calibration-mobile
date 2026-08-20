import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/navigasi_global.dart';
import '../models/notification_item.dart';

/// Ketukan pada push Firebase → buka layar yang bersangkutan.
///
/// Dua pintu masuk, dan yang kedua paling gampang dilupakan:
///
///  1. [FirebaseMessaging.onMessageOpenedApp] — aplikasi masih hidup di latar,
///     penggunanya mengetuk notifikasi.
///  2. [FirebaseMessaging.getInitialMessage] — aplikasi MATI TOTAL, dan
///     ketukan itulah yang menyalakannya. Tanpa ini, ketukan dari keadaan mati
///     cuma membuka halaman depan, dan orangnya harus mencari sendiri sesi
///     mana yang barusan dikabarkan.
///
/// Yang dibaca cuma `tautan_tipe` & `tautan_id` — muatan push memang sengaja
/// tipis, karena dia mendarat di layar kunci dan terbaca siapa pun yang
/// memegang HP-nya. Isinya ditarik lewat REST ber-otorisasi sesudah layarnya
/// kebuka.
class KetukanPush {
  const KetukanPush._();

  static NotifTautan? _tautan(RemoteMessage? pesan) {
    if (pesan == null) return null;

    final tipe = pesan.data['tautan_tipe'];
    final id = int.tryParse('${pesan.data['tautan_id']}');

    if (tipe is! String || tipe.isEmpty || id == null) return null;

    return NotifTautan(tipe: tipe, id: id);
  }

  /// Pasang sekali, sesudah Firebase nyala.
  static Future<void> pasang() async {
    FirebaseMessaging.onMessageOpenedApp.listen(
      (pesan) => bukaTautanDariLuar(_tautan(pesan)),
    );

    // Aplikasi dinyalakan OLEH ketukan. Dibaca sekali di sini; kalau nggak,
    // pesannya hilang dan nggak akan pernah datang lagi.
    final awal = await FirebaseMessaging.instance.getInitialMessage();
    bukaTautanDariLuar(_tautan(awal));
  }
}
