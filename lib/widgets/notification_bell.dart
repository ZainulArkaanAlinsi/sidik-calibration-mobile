import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/notification_provider.dart';
import '../screens/notification/notification_screen.dart';

/// Ikon notifikasi di **atas** layar dengan badge angka (spesifikasi poin 4).
///
/// Ditaruh di `AppBar.actions`, bukan di navbar bawah — notifikasi itu
/// pemberitahuan, bukan menu utama, dan navbar bawah cuma buat menu yang
/// paling sering dipakai (poin 8).
///
/// Angkanya dari [unreadCountProvider] yang nembak `unread-count`, bukan dari
/// daftar penuh: widget ini nempel di hampir semua layar, jadi kalau dia narik
/// 20 baris notifikasi tiap layar kebuka, itu request sia-sia terus-terusan.
///
/// Waktu angkanya NAIK (kabar baru) lonceng berayun sebentar (±14°, 600 ms) —
/// halus, sekali, tanpa bunyi. "Kurangi gerak" nyala → tidak bergerak.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ayun = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _ayun.dispose();
    super.dispose();
  }

  /// Sudut ayunan (radian) pada progres [t] 0..1: peluruhan sinus.
  static double _sudut(double t) =>
      math.sin(t * math.pi * 4) * (1 - t) * (14 * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(unreadCountProvider, (sebelum, sesudah) {
      final lama = sebelum?.value;
      final baru = sesudah.value;
      if (lama == null || baru == null || baru <= lama) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      _ayun.forward(from: 0);
    });

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Gagal ngambil angka badge sengaja dianggap 0, bukan nampilin error:
    // lonceng yang error nggak nolong siapa-siapa, dan halaman notifikasinya
    // sendiri tetap bisa dibuka buat lihat masalahnya.
    final jumlah = ref.watch(unreadCountProvider).value ?? 0;

    return IconButton(
      tooltip: l10n.navNotifications,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationScreen()),
        );
      },
      icon: AnimatedBuilder(
        animation: _ayun,
        builder: (context, anak) => Transform.rotate(
          angle: _sudut(_ayun.value),
          alignment: Alignment.topCenter,
          child: anak,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none),
            if (jumlah > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    // Di atas 99 angkanya nggak muat & nggak nambah info —
                    // yang penting "banyak banget".
                    jumlah > 99 ? '99+' : '$jumlah',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
