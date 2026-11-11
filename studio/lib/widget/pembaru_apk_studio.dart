import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/widgets/banner_update.dart';

/// Apakah pemutakhiran APK dalam-aplikasi berlaku di perangkat ini.
///
/// Hanya Android sungguhan. Windows punya `PembaruWindows`
/// (`BannerPembaruanWindows`), dan widget test Studio berjalan di mesin
/// desktop sehingga otomatis `false` — test yang menguji jalur APK
/// menimpanya menjadi `true`. (Provider bersama `jalurApkProvider` sengaja
/// `true` di bawah `flutter test`; dipakai sendirian ia menyalakan rantai
/// cek-versi di SEMUA widget test cangkang.)
final pembaruApkStudioAktifProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isAndroid,
);

/// Banner "Versi X sudah tersedia" + tombol pasang untuk Studio di Android.
///
/// Memakai provider yang sama dengan app lapangan (`updateTersediaProvider`,
/// `updateSiapProvider`, [BannerUpdate]); yang beda cuma sumber versinya
/// (`ApiVersiServiceStudio`, ditimpa di `inti/penimpaan.dart`).
///
/// ## Yang SENGAJA tidak dibawa dari `PemeriksaPembaruan` lapangan
///
/// - **Pop-up pembaruan otomatis** dan **pemasangan diam saat aplikasi ke
///   latar** (`PemasangOtomatis`). Studio dipakai mengedit master; memasang
///   ulang aplikasi sendiri selagi pengguna pindah aplikasi bisa membuang
///   isian yang belum tersimpan. Pemasangan hanya atas ketukan pengguna di
///   banner.
/// - Banner Windows: sudah dipasang cangkang sendiri.
///
/// ## Yang dibawa
///
/// - Menonton `updateSiapProvider` menyalakan unduhan latar (Wi-Fi saja, aturan
///   provider-nya), jadi ketukan "PASANG" langsung membuka pemasang.
/// - Cek ulang berkala dan saat aplikasi kembali ke depan: tablet lab jarang
///   ditutup total, jadi cek sekali per proses tidak pernah menemukan rilis baru.
///
/// Gagal cek (offline, GitHub mati, belum ada APK Studio di rilis) = widget
/// kosong, tanpa pesan.
class PembaruApkStudio extends ConsumerStatefulWidget {
  const PembaruApkStudio({
    super.key,
    this.jeda = const Duration(hours: 1),
    this.jam,
  });

  /// Jarak minimum antar-cek ulang, juga periode timer selama di depan.
  final Duration jeda;

  /// Disuntikkan di test. Null = `DateTime.now`.
  final DateTime Function()? jam;

  @override
  ConsumerState<PembaruApkStudio> createState() => _PembaruApkStudioState();
}

class _PembaruApkStudioState extends ConsumerState<PembaruApkStudio>
    with WidgetsBindingObserver {
  late DateTime _terakhirDicek;
  Timer? _timer;

  DateTime _sekarang() => (widget.jam ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terakhirDicek = _sekarang();
    _mulaiTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState keadaan) {
    switch (keadaan) {
      case AppLifecycleState.resumed:
        if (_sekarang().difference(_terakhirDicek) >= widget.jeda) {
          _cekUlang();
        }
        _mulaiTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Di latar tidak ada yang melihat banner; jangan bangunkan jaringan.
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _mulaiTimer() {
    _timer?.cancel();
    _timer = null;
    // Windows/test desktop: tidak ada yang dicek, jadi tidak ada timer.
    if (!ref.read(pembaruApkStudioAktifProvider)) return;
    _timer = Timer.periodic(widget.jeda, (_) => _cekUlang());
  }

  void _cekUlang() {
    if (!mounted || !ref.read(pembaruApkStudioAktifProvider)) return;
    _terakhirDicek = _sekarang();

    // Nilai lama tetap terpegang selama cek ulang (Riverpod menyimpan data
    // sebelumnya), jadi banner yang sedang tampil tidak berkedip hilang.
    ref.invalidate(updateTersediaProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(pembaruApkStudioAktifProvider)) {
      return const SizedBox.shrink();
    }

    // Menonton = menyalakan unduhan latar, terlepas dari banner tergambar atau
    // tidak (mis. sudah ditutup pengguna).
    ref.watch(updateSiapProvider);

    return const BannerUpdate();
  }
}
