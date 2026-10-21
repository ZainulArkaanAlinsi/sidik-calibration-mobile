import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/versi_provider.dart';
import 'banner_pembaruan_windows.dart';
import 'banner_update.dart';
import 'pemasang_otomatis.dart';
import 'readable_width.dart';

/// Lapisan pembaruan di level SHELL — dipasang membungkus isi `MainShell` dan
/// `DesktopShell`, jadi berlaku untuk semua peran (super admin, admin,
/// teknisi, viewer) dan semua varian beranda.
///
/// ## Kenapa di shell (22 Okt 2026)
///
/// Sebelum ini banner pembaruan cuma ada di dalam isi dashboard admin/viewer:
/// super admin punya beranda sendiri dan teknisi tidak punya tab dashboard,
/// jadi dua peran itu TIDAK PERNAH melihat banner — dan karena unduhan latar
/// dipicu oleh banner yang digambar, HP mereka juga tidak pernah mengunduh
/// apa pun.
///
/// ## Yang dikerjakan
///
/// 1. **Unduhan latar lepas dari banner**: [updateSiapProvider] ditonton di
///    sini, bukan cuma oleh banner yang bisa ditutup atau tidak tergambar.
/// 2. **Cek ulang berkala**: waktu aplikasi kembali ke depan (sesudah minimal
///    [jeda] sejak cek terakhir) dan tiap [jeda] selama di depan. Sebelumnya
///    versi dicek sekali per proses — HP yang tidak pernah ditutup tidak
///    pernah tahu ada rilis baru.
/// 3. **Banner**: [BannerUpdate] (APK) dan [BannerPembaruanWindows] (zip
///    Windows), di DASAR isi — terlihat di tab mana pun, tanpa mengurusi
///    status bar.
/// 4. **Pop-up & pasang diam** ([PemasangOtomatis]) ikut pindah ke sini dari
///    dashboard, supaya teknisi juga mendapatkannya.
class PemeriksaPembaruan extends ConsumerStatefulWidget {
  const PemeriksaPembaruan({
    super.key,
    required this.child,
    this.jeda = const Duration(hours: 1),
    this.jam,
  });

  final Widget child;

  /// Jarak minimum antar-cek ulang, juga periode timer selama di depan.
  final Duration jeda;

  /// Disuntikkan di test. Null = `DateTime.now`.
  final DateTime Function()? jam;

  @override
  ConsumerState<PemeriksaPembaruan> createState() => _PemeriksaPembaruanState();
}

class _PemeriksaPembaruanState extends ConsumerState<PemeriksaPembaruan>
    with WidgetsBindingObserver {
  late DateTime _terakhirDicek;
  Timer? _timer;

  DateTime _sekarang() => (widget.jam ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pemeriksaan pertama terjadi sendiri waktu provider-nya pertama dibaca
    // di `build` di bawah.
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
          _cekUlang(termasukWindows: true);
        }
        _mulaiTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Di latar tidak ada yang melihat bannernya; timer berhenti supaya
        // tidak membangunkan jaringan. Cek ulangnya menunggu `resumed`.
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _mulaiTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.jeda, (_) => _cekUlang());
  }

  void _cekUlang({bool termasukWindows = false}) {
    if (!mounted) return;
    _terakhirDicek = _sekarang();

    // Nilai lama tetap terpegang selama pemeriksaan ulang berjalan (Riverpod
    // menyimpan data sebelumnya), jadi banner yang sedang tampil tidak
    // berkedip hilang.
    // Desktop/web tidak memakai jalur APK — provider-nya selalu null, jadi
    // menghitungnya ulang cuma membangunkan rantai provider tanpa guna.
    if (ref.read(jalurApkProvider)) ref.invalidate(updateTersediaProvider);

    // Windows punya timer jam-an sendiri di `PembaruWindows`; di sini cuma
    // disusulkan waktu kembali ke depan.
    if (termasukWindows) {
      unawaited(ref.read(pembaruWindowsProvider)?.siapkan());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menonton = menyalakan unduhan latar (Wi-Fi saja, lihat provider-nya),
    // terlepas dari apakah bannernya sedang tergambar.
    ref.watch(updateSiapProvider);

    return Column(
      children: [
        Expanded(child: PemasangOtomatis(child: widget.child)),
        // Tanpa `SafeArea`: di HP navbar bawah shell sudah menanggung inset
        // bawah, dan `SafeArea` yang kosong (tidak ada pembaruan) akan
        // menyisakan pita kosong permanen di tablet mode rail.
        const ReadableWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [BannerUpdate(), BannerPembaruanWindows()],
          ),
        ),
      ],
    );
  }
}
