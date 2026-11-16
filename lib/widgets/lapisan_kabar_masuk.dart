import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion/app_motion.dart';
import '../core/theme/token_umpan_balik_biru_awan.dart';
import '../l10n/app_localizations.dart';
import '../models/kabar_toast.dart';
import '../providers/kabar_masuk_provider.dart';
import 'biru_awan/toast_sidik.dart';

/// Lapisan toast kabar masuk — dipasang SEKALI di `MaterialApp.builder`.
///
/// - Di ATAS layar dan di dalam safe area: tombol aksi utama app ini ada di
///   bawah (floating nav, tombol Kirim/Simpan), jadi toast tidak pernah
///   menutupnya.
/// - Masuk geser-turun + pudar 240 ms ([AppMotion.sedang], batasnya 300 ms);
///   "kurangi gerak" nyala → tanpa animasi sama sekali.
/// - Kartu = varian kabar navy `ToastSidik` (Biru Awan, L2): logo, aksi "Buka",
///   tombol tutup. Satu kabar = judul + isi; lebih dari satu = satu kartu
///   "n kabar baru". Dedup per id dan hitung mundur tetap di
///   [KabarMasukNotifier], tidak berubah.
/// - Hilang sendiri 5 detik (diatur [KabarMasukNotifier]); ketukan (kartu atau
///   "Buka") membuka tujuan, atau daftar notifikasi bila banyak.
class LapisanKabarMasuk extends ConsumerStatefulWidget {
  const LapisanKabarMasuk({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LapisanKabarMasuk> createState() => _LapisanKabarMasukState();
}

class _LapisanKabarMasukState extends ConsumerState<LapisanKabarMasuk>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// Salinan terakhir yang tidak kosong, supaya kartu tetap berisi selama
  /// animasi keluar.
  List<KabarToast> _terakhir = const [];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ikuti(List<KabarToast>? _, List<KabarToast> baru) {
    if (baru.isNotEmpty) {
      setState(() => _terakhir = baru);
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  void _ketuk() {
    final nav = ref.read(penavigasiKabarProvider);
    final daftar = ref.read(kabarMasukProvider);
    final isi = daftar.isEmpty ? _terakhir : daftar;
    ref.read(kabarMasukProvider.notifier).tutup();
    if (isi.length > 1) {
      nav.bukaDaftar();
    } else if (isi.isNotEmpty) {
      nav.bukaTujuan(isi.first.tautan);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(kabarMasukProvider, _ikuti);

    _c.duration = AppMotion.hormati(context, AppMotion.sedang);
    _c.reverseDuration = _c.duration;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              if (_c.isDismissed || _terakhir.isEmpty) {
                return const SizedBox.shrink();
              }
              final kurva = CurvedAnimation(
                parent: _c,
                curve: AppMotion.masuk,
                reverseCurve: AppMotion.keluar,
              );
              return SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UkuranUmpanBalikBiruAwan.toastJarakLuar,
                    UkuranUmpanBalikBiruAwan.toastJarakLuar,
                    UkuranUmpanBalikBiruAwan.toastJarakLuar,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: kurva,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.6),
                          end: Offset.zero,
                        ).animate(kurva),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: UkuranUmpanBalikBiruAwan.toastLebarMaks,
                          ),
                          child: _KartuKabar(
                            kabar: _terakhir,
                            onTap: _ketuk,
                            onTutup: () =>
                                ref.read(kabarMasukProvider.notifier).tutup(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KartuKabar extends StatelessWidget {
  const _KartuKabar({
    required this.kabar,
    required this.onTap,
    required this.onTutup,
  });

  final List<KabarToast> kabar;
  final VoidCallback onTap;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final banyak = kabar.length > 1;
    final judul = banyak
        ? l10n.kabarBaruJumlah(kabar.length)
        : kabar.first.judul;
    final isi = banyak ? l10n.kabarBaruKetuk : kabar.first.isi;

    // Kartu navy Biru Awan dengan logo Sidik berwarna (varian kabar `ToastSidik`):
    // harus terbaca "dari Sidik" sekilas. Seluruh kartu bisa diketuk; aksi "Buka"
    // dan tombol tutup berdiri sendiri.
    return ToastSidik(
      key: const ValueKey('kartu_kabar_masuk'),
      jenis: JenisToast.kabar,
      judul: judul,
      isi: isi,
      aksi: l10n.biruAwanBuka,
      onAksi: onTap,
      onTutup: onTutup,
      onKetuk: onTap,
      wilayahHidup: true,
    );
  }
}
