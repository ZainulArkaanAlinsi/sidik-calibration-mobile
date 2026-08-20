import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'sumber_token_push.dart';

/// Sumber token push dari Firebase Cloud Messaging.
///
/// Satu-satunya tempat `firebase_messaging` disebut di aplikasi ini. Firebase
/// statusnya sementara — kalau nanti diganti, yang dibuang berkas ini dan satu
/// baris di `sumberTokenPushProvider`, bukan penelusuran ke seluruh aplikasi.
///
/// Cuma dipakai di Android & iOS. Panel admin desktop TIDAK: di situ kabarnya
/// sudah sampai lewat websocket Reverb selama aplikasinya jalan, dan aplikasi
/// desktop yang ketutup memang nggak diharapkan menerima apa pun.
class FcmSumberTokenPush implements SumberTokenPush {
  FcmSumberTokenPush({FirebaseMessaging? messaging})
    : _fcm = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _fcm;

  /// Platform yang punya layanan push-nya. Web sengaja nggak masuk: dia butuh
  /// VAPID key sendiri, dan aplikasi ini nggak dipakai lewat browser.
  static bool get didukung =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<String?> token() async {
    if (!didukung) return null;

    try {
      // Izin diminta di sini, bukan waktu aplikasi pertama kebuka: orang yang
      // ditanya sebelum tahu aplikasinya buat apa nolaknya sambil lalu.
      // Android 12 ke bawah nggak punya dialog ini dan langsung `authorized`.
      final izin = await _fcm.requestPermission();

      if (izin.authorizationStatus == AuthorizationStatus.denied) {
        // Menolak izin BUKAN error. Aplikasi tetap jalan; notifikasinya tetap
        // masuk daftar & lonceng, dan selama aplikasi kebuka Reverb tetap
        // ngabarin. Yang hilang cuma kabar waktu aplikasi ketutup total.
        return null;
      }

      return await _fcm.getToken();
    } catch (e) {
      // Layanan Google Play nggak ada (HP tanpa GMS), jaringan mati waktu
      // pendaftaran, atau proyek Firebase salah setel. Semuanya berarti
      // "nggak ada token", bukan "aplikasi rusak".
      debugPrint('Token push nggak kedapat: $e');
      return null;
    }
  }

  @override
  Stream<String> tokenBerubah() {
    if (!didukung) return const Stream.empty();

    // FCM merotasi token tanpa diminta — aplikasi dipasang ulang, data
    // aplikasi dihapus, atau tokennya dianggap basi. Kalau yang baru nggak
    // didaftarkan ulang, notifikasinya berhenti masuk TANPA satu error pun:
    // dari sisi server, token lamanya masih kelihatan sah sampai ada yang
    // mencoba mengirim ke situ.
    return _fcm.onTokenRefresh;
  }
}
