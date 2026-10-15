import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/navigasi_global.dart';
import '../models/kabar_toast.dart';
import '../models/notification_item.dart';
import '../screens/notification/notification_screen.dart';
import '../services/kabar_push.dart';
import 'auth_provider.dart';

/// Berapa lama toast bertahan sebelum hilang sendiri.
const jedaTutupKabar = Duration(seconds: 5);

/// Jendela dedup: kabar berkunci sama dalam rentang ini dianggap satu kejadian.
const jendelaDedupKabar = Duration(seconds: 30);

/// Antrean toast yang sedang tampil. Banyak kabar → satu toast "n kabar baru",
/// bukan tumpukan kartu yang menutupi layar.
final kabarMasukProvider =
    NotifierProvider<KabarMasukNotifier, List<KabarToast>>(
      KabarMasukNotifier.new,
    );

class KabarMasukNotifier extends Notifier<List<KabarToast>> {
  Timer? _timer;
  // kunci/teks → kapan terlihat. Teks disimpan bersama penanda "punya id".
  final Map<String, DateTime> _terlihat = {};
  final Map<String, bool> _teksBerId = {};

  @override
  List<KabarToast> build() {
    ref.onDispose(() => _timer?.cancel());
    return const [];
  }

  /// Tambahkan kabar. Tiap kabar baru menyetel ulang hitung mundur 5 detik.
  void tambahkan(Iterable<KabarToast> kabar) {
    final sekarang = DateTime.now();
    _terlihat.removeWhere((kunci, t) {
      final basi = sekarang.difference(t) > jendelaDedupKabar;
      if (basi) _teksBerId.remove(kunci);
      return basi;
    });

    final baru = <KabarToast>[];
    for (final k in kabar) {
      final adaId = k.kunci != null;
      // Sama bila id-nya sama; atau teksnya sama dan salah satu sisi tidak
      // membawa id (push tanpa `notification_id` vs baris inbox).
      final kembar =
          (adaId && _terlihat.containsKey('id:${k.kunci}')) ||
          (_terlihat.containsKey('t:${k.teks}') &&
              (!adaId || !(_teksBerId['t:${k.teks}'] ?? false)));
      if (kembar) continue;
      if (adaId) _terlihat['id:${k.kunci}'] = sekarang;
      _terlihat['t:${k.teks}'] = sekarang;
      _teksBerId['t:${k.teks}'] = adaId;
      baru.add(k);
    }
    if (baru.isEmpty) return;

    state = [...state, ...baru];
    _timer?.cancel();
    _timer = Timer(jedaTutupKabar, tutup);
  }

  void tutup() {
    _timer?.cancel();
    _timer = null;
    if (state.isNotEmpty) state = const [];
  }
}

/// Jalur ketukan toast. Dipisah supaya test bisa mengganti tujuan tanpa
/// Navigator sungguhan.
class PenavigasiKabar {
  const PenavigasiKabar();

  /// Satu kabar → layar tujuannya (tipe tak dikenal: diam, lihat
  /// [bukaTautanNotifikasi]).
  void bukaTujuan(NotifTautan? tautan) => bukaTautanDariLuar(tautan);

  /// Banyak kabar → daftar notifikasi.
  void bukaDaftar() {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationScreen()),
    );
  }
}

final penavigasiKabarProvider = Provider<PenavigasiKabar>(
  (_) => const PenavigasiKabar(),
);

/// Sumber push foreground. Kosong (tanpa langganan sama sekali) kalau Firebase
/// belum jalan — `google-services.json` belum ada, desktop, atau mode mock.
final sumberKabarPushProvider = Provider<SumberKabarPush>((ref) {
  if (AppConfig.useMock || !FcmSumberKabarPush.didukung) {
    return const TanpaKabarPush();
  }
  return FcmSumberKabarPush();
});

/// Menyambung push foreground (`FirebaseMessaging.onMessage`) ke toast.
/// Ditonton dari akar aplikasi; hanya aktif selama ada yang login.
final kabarPushSyncProvider = Provider<void>((ref) {
  final idPengguna = ref.watch(authProvider.select((s) => s.value?.id));
  if (idPengguna == null) return;

  final langganan = ref
      .watch(sumberKabarPushProvider)
      .kabar
      .listen(
        (k) => ref.read(kabarMasukProvider.notifier).tambahkan([k]),
        onError: (_) {},
      );
  ref.onDispose(langganan.cancel);
});
