import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/navigasi_global.dart';
import '../models/notification_item.dart';
import '../models/kabar_toast.dart';

/// Sumber kabar push saat aplikasi TERBUKA (foreground).
///
/// Android tidak menggambar notifikasi sistem untuk push yang tiba waktu
/// aplikasinya di depan — kalau tidak ada yang menangkap, kabarnya hilang.
/// Sumber ini menangkapnya untuk toast di dalam aplikasi.
abstract class SumberKabarPush {
  Stream<KabarToast> get kabar;
}

/// Tanpa push: mode mock, desktop, dan semua keadaan saat Firebase tidak hidup.
class TanpaKabarPush implements SumberKabarPush {
  const TanpaKabarPush();

  @override
  Stream<KabarToast> get kabar => const Stream.empty();
}

/// `FirebaseMessaging.onMessage` → [KabarToast].
///
/// Satu-satunya tempat `onMessage` disebut. DIJAGA: `FirebaseMessaging.instance`
/// melempar kalau `Firebase.initializeApp()` belum/tidak berhasil (mis.
/// `google-services.json` belum ada), dan aplikasi tidak boleh ikut mati karena
/// itu. Begitu berkas itu ada dan Firebase hidup, sumber ini menyala sendiri.
class FcmSumberKabarPush implements SumberKabarPush {
  FcmSumberKabarPush({
    Stream<RemoteMessage>? aliran,
    bool Function()? firebaseHidup,
  }) : _aliran = aliran,
       _firebaseHidup = firebaseHidup ?? _adaFirebase;

  final Stream<RemoteMessage>? _aliran;
  final bool Function() _firebaseHidup;

  static bool get didukung => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _adaFirebase() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<KabarToast> get kabar {
    if (!_firebaseHidup()) return const Stream.empty();

    try {
      return (_aliran ?? FirebaseMessaging.onMessage)
          .map(dariPesan)
          .where((k) => k != null)
          .cast<KabarToast>();
    } catch (e) {
      debugPrint('onMessage nggak tersambung: $e');
      return const Stream.empty();
    }
  }

  /// `notification.title/body` + `data.kategori` + `data.tujuan`.
  /// `null` kalau pesannya tidak punya teks yang bisa ditampilkan (mis. pesan
  /// data-only untuk sinkronisasi).
  @visibleForTesting
  static KabarToast? dariPesan(RemoteMessage pesan) {
    final judul = pesan.notification?.title ?? '${pesan.data['judul'] ?? ''}';
    final isi = pesan.notification?.body ?? '${pesan.data['isi'] ?? ''}';
    if (judul.isEmpty && isi.isEmpty) return null;

    final id = pesan.data['notification_id'] ?? pesan.data['id'];

    return KabarToast(
      judul: judul,
      isi: isi,
      kategori: NotifKategori.fromApi('${pesan.data['kategori'] ?? ''}'),
      tautan: bacaTujuan('${pesan.data['tujuan'] ?? ''}'),
      kunci: id == null ? null : '$id',
    );
  }
}
