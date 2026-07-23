import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/floating_nav_bar.dart';
import '../dashboard/dashboard_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../folder/folder_manager_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

/// Rangka utama app: navbar bawah + tab-nya.
///
/// **Notifikasi nggak di navbar bawah lagi** (spesifikasi poin 4 & 8). Ikonnya
/// pindah ke atas layar dengan badge angka ([NotificationBell]) dan buka
/// halaman sendiri; tempatnya di navbar diambil **Folder Manager** (poin 3).
/// Alasannya: navbar bawah cuma buat menu yang beneran sering dipakai, dan
/// notifikasi itu pemberitahuan — bukan tempat kerja.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = <Widget>[
    DashboardScreen(),
    EquipmentListScreen(),
    HistoryScreen(),
    FolderManagerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);
    final l10n = AppLocalizations.of(context);

    final items = <FloatingNavItem>[
      FloatingNavItem(
        icon: Icons.space_dashboard_outlined,
        activeIcon: Icons.space_dashboard,
        label: l10n.navDashboard,
      ),
      FloatingNavItem(
        icon: Icons.straighten_outlined,
        activeIcon: Icons.straighten,
        label: l10n.navEquipment,
      ),
      FloatingNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: l10n.navHistory,
      ),
      FloatingNavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: l10n.navFolderManager,
      ),
      FloatingNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: l10n.navProfile,
      ),
    ];

    return Scaffold(
      // IndexedStack, bukan ganti-ganti widget: state tiap tab (posisi scroll,
      // isian form) nggak ilang waktu pindah tab.
      body: IndexedStack(index: selected, children: _tabs),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: selected,
        onSelected: ref.read(selectedTabProvider.notifier).select,
        items: items,
      ),
    );
  }
}
