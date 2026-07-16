import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/navigation_provider.dart';
import '../../widgets/floating_nav_bar.dart';
import '../dashboard/dashboard_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../history/history_screen.dart';
import '../notification/notification_screen.dart';
import '../profile/profile_screen.dart';

/// Rangka utama app: bottom nav 5 tab yang sama buat semua role.
/// Yang beda antar role cuma isi tab Profil (lihat README, Prinsip Desain).
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = <Widget>[
    DashboardScreen(),
    EquipmentListScreen(),
    HistoryScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  static const _items = <FloatingNavItem>[
    FloatingNavItem(
      icon: Icons.space_dashboard_outlined,
      activeIcon: Icons.space_dashboard,
      label: 'Dashboard',
    ),
    FloatingNavItem(
      icon: Icons.straighten_outlined,
      activeIcon: Icons.straighten,
      label: 'Alat',
    ),
    FloatingNavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Riwayat',
    ),
    FloatingNavItem(
      icon: Icons.notifications_none,
      activeIcon: Icons.notifications,
      label: 'Notifikasi',
    ),
    FloatingNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);

    return Scaffold(
      // IndexedStack, bukan ganti-ganti widget: state tiap tab (posisi scroll,
      // isian form) nggak ilang waktu pindah tab.
      body: IndexedStack(index: selected, children: _tabs),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: selected,
        onSelected: ref.read(selectedTabProvider.notifier).select,
        items: _items,
      ),
    );
  }
}
