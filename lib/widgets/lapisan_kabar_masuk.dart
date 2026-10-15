import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion/app_motion.dart';
import '../l10n/app_localizations.dart';
import '../models/kabar_toast.dart';
import '../providers/kabar_masuk_provider.dart';

/// Lapisan toast kabar masuk — dipasang SEKALI di `MaterialApp.builder`.
///
/// - Di ATAS layar dan di dalam safe area: tombol aksi utama app ini ada di
///   bawah (floating nav, tombol Kirim/Simpan), jadi toast tidak pernah
///   menutupnya.
/// - Masuk geser-turun + pudar 240 ms ([AppMotion.sedang], batasnya 300 ms);
///   "kurangi gerak" nyala → tanpa animasi sama sekali.
/// - Satu kabar = judul + isi; lebih dari satu = satu kartu "n kabar baru".
/// - Hilang sendiri 5 detik (diatur [KabarMasukNotifier]); ketukan membuka
///   tujuan, atau daftar notifikasi bila banyak.
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _KartuKabar(kabar: _terakhir, onTap: _ketuk),
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
  const _KartuKabar({required this.kabar, required this.onTap});

  final List<KabarToast> kabar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final banyak = kabar.length > 1;
    final judul = banyak
        ? l10n.kabarBaruJumlah(kabar.length)
        : kabar.first.judul;
    final isi = banyak ? l10n.kabarBaruKetuk : kabar.first.isi;

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$judul. $isi',
      child: Material(
        color: tema.colorScheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('kartu_kabar_masuk'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Logo Sidik berwarna, bukan ikon generik: kartu ini harus
                // terbaca "dari Sidik" sekilas.
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      'assets/images/logo_pt_sidik.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 28, height: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.titleSmall?.copyWith(
                          color: tema.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isi.isNotEmpty)
                        Text(
                          isi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onInverseSurface,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
