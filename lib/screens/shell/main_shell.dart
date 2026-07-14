import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/navigation_provider.dart';
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

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.straighten_outlined),
      selectedIcon: Icon(Icons.straighten),
      label: 'Alat',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'Riwayat',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_none),
      selectedIcon: Icon(Icons.notifications),
      label: 'Notifikasi',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: ref.read(selectedTabProvider.notifier).select,
        destinations: _destinations,
      ),
    );
  }
}
