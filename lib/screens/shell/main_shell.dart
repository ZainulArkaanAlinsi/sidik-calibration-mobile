import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/floating_nav_bar.dart';
import '../dashboard/dashboard_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../history/history_screen.dart';
import '../notification/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/customer_list_screen.dart';
import '../settings/organization_screen.dart';
import '../settings/standard_list_screen.dart';
import '../settings/technician_list_screen.dart';

/// Dipegang di level library, bukan lewat `Scaffold.of()`, karena tiap tab
/// punya `Scaffold` sendiri — `Scaffold.of()` dari dalam tab bakal nemu
/// Scaffold tab-nya, bukan yang megang Drawer ini.
final mainShellKey = GlobalKey<ScaffoldState>();

/// Buka menu samping dari AppBar tab mana pun.
void bukaMenuUtama() => mainShellKey.currentState?.openDrawer();

/// Rangka utama app: bottom nav 5 tab yang sama buat semua role.
/// Yang beda antar role cuma isi tab Profil (lihat README, Prinsip Desain).
///
/// Bottom nav dipertahankan buat 5 tujuan yang paling sering dipakai; menu
/// samping ([_MenuUtama]) nampung sisanya — master data & pengaturan — yang
/// dibuka sesekali dan nggak layak makan slot bottom nav.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = <Widget>[
    DashboardScreen(),
    EquipmentListScreen(),
    HistoryScreen(),
    NotificationScreen(),
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
        icon: Icons.notifications_none,
        activeIcon: Icons.notifications,
        label: l10n.navNotifications,
      ),
      FloatingNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: l10n.navProfile,
      ),
    ];

    return Scaffold(
      key: mainShellKey,
      drawer: const _MenuUtama(),
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

/// Menu samping. **Cuma berisi tujuan yang layarnya udah ada.** Bagian spec
/// yang belum digarap (Order Kalibrasi, Perhitungan, Laporan, Data Ruangan)
/// sengaja nggak dipasang di sini — menu yang mengarah ke layar kosong lebih
/// bikin bingung daripada menu yang belum lengkap.
class _MenuUtama extends ConsumerWidget {
  const _MenuUtama();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    final admin = user?.role.isAdmin ?? false;

    void keTab(int index) {
      ref.read(selectedTabProvider.notifier).select(index);
      Navigator.of(context).pop();
    }

    void keLayar(Widget layar) {
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => layar));
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.menuUtama, style: theme.textTheme.titleMedium),
                  if (user != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user.nama,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.space_dashboard_outlined),
              title: Text(l10n.navDashboard),
              onTap: () => keTab(0),
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(l10n.navHistory),
              onTap: () => keTab(2),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(l10n.navNotifications),
              onTap: () => keTab(3),
            ),

            const Divider(),
            _LabelSeksi(l10n.menuMasterData),
            ListTile(
              leading: const Icon(Icons.straighten_outlined),
              title: Text(l10n.navEquipment),
              onTap: () => keTab(1),
            ),
            // Pelanggan, standar, dan akun cuma bisa diubah admin — backend
            // nolak dengan 403 kalau role lain nembak, jadi nggak usah
            // ditampilin buat teknisi/viewer.
            if (admin) ...[
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.profCustomers),
                onTap: () => keLayar(const CustomerListScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(l10n.standarTitle),
                onTap: () => keLayar(const StandardListScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.teknisiTitle),
                onTap: () => keLayar(const TechnicianListScreen()),
              ),
            ],

            const Divider(),
            _LabelSeksi(l10n.menuPengaturan),
            if (admin)
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(l10n.orgTitle),
                onTap: () => keLayar(const OrganizationScreen()),
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.navProfile),
              onTap: () => keTab(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelSeksi extends StatelessWidget {
  const _LabelSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        teks.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
