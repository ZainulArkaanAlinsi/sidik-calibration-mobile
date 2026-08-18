import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../widgets/floating_nav_bar.dart';
import '../dashboard/dashboard_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../folder/folder_manager_screen.dart';
import '../history/history_screen.dart';
import '../admin/antrean_approval_screen.dart';
import '../alur/alur_kerja_screen.dart';
import '../../widgets/pemantau_antrean.dart';
import '../admin/import_excel_screen.dart';
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

/// Rangka utama app: navbar bawah 5 tab yang sama buat semua role.
/// Yang beda antar role cuma isi tab Profil (lihat README, Prinsip Desain).
///
/// Navbar bawah dipertahankan buat 5 tujuan yang paling sering dipakai; menu
/// samping ([_MenuUtama]) nampung sisanya — master data & pengaturan — yang
/// dibuka sesekali dan nggak layak makan slot navbar.
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

  /// Di atas lebar ini navigasi pindah ke samping ([NavigationRail]). Angkanya
  /// ikut breakpoint "expanded" Material 3 (840dp) dibulatkan ke 900 — di
  /// bawah itu rail malah makan lebar yang dibutuhkan isi layar.
  ///
  /// Sengaja dipatok ke **lebar jendela, bukan ke `Platform.isWindows`**:
  /// jendela desktop bisa dikecilin sampai seukuran HP, dan tablet Android
  /// dilandscape-kan justru pantas dapat rail. Yang menentukan ruang, bukan
  /// merek sistem operasinya.
  static const _lebarRail = 900.0;

  /// Di layar yang benar-benar lebar, rail dibentangkan supaya labelnya ikut
  /// kebaca — bukan cuma ikon yang harus ditebak.
  static const _lebarRailPanjang = 1200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);
    final l10n = AppLocalizations.of(context);

    // Nyalain sinkron realtime selama shell (login) kebuka — lonceng & data
    // ke-update barengan sama panel desktop (spec poin 12D). No-op kalau
    // realtime nonaktif.
    ref.watch(realtimeSyncProvider);

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

    final pilihTab = ref.read(selectedTabProvider.notifier).select;

    // IndexedStack, bukan ganti-ganti widget: state tiap tab (posisi scroll,
    // isian form) nggak ilang waktu pindah tab.
    final isi = IndexedStack(index: selected, children: _tabs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pakaiRail = constraints.maxWidth >= _lebarRail;

        return Scaffold(
          key: mainShellKey,
          drawer: const _MenuUtama(),
          // Lihat catatan di DesktopShell: pemantau antrean dibungkus di luar
          // isi supaya tandanya muncul di layar mana pun.
          body: PemantauAntrean(
            child: pakaiRail
                ? Row(
                    children: [
                      _RailSamping(
                        selectedIndex: selected,
                        onSelected: pilihTab,
                        items: items,
                        dibentangkan: constraints.maxWidth >= _lebarRailPanjang,
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(child: isi),
                    ],
                  )
                : isi,
          ),
          // Navbar bawah cuma buat layar sempit. Di desktop dua-duanya nongol
          // bakal jadi dua kontrol yang isinya sama persis — bingungin, dan
          // makan tinggi layar yang justru mahal di jendela pendek.
          bottomNavigationBar: pakaiRail
              ? null
              : FloatingNavBar(
                  selectedIndex: selected,
                  onSelected: pilihTab,
                  items: items,
                ),
        );
      },
    );
  }
}

/// Navigasi samping buat layar lebar. Tujuannya **sama persis** dengan navbar
/// bawah di HP — orang yang pindah dari HP ke desktop nggak perlu belajar peta
/// baru, cuma bentuknya yang beda.
///
/// Tombol menu di atas rail dipertahankan karena master data & pengaturan
/// tetap tinggal di Drawer; tanpa itu, di desktop nggak ada jalan masuk yang
/// kelihatan ke sana selain hamburger di AppBar tiap tab.
class _RailSamping extends StatelessWidget {
  const _RailSamping({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.dibentangkan,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingNavItem> items;
  final bool dibentangkan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: dibentangkan,
      // `extended` sudah nampilin label di samping ikon; maksa `labelType`
      // selain `none` bareng `extended` itu assert-nya Flutter, bukan selera.
      labelType: dibentangkan ? null : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: l10n.menuUtama,
          onPressed: bukaMenuUtama,
        ),
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          ),
      ],
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => layar));
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradasiLatar(context),
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.50)),
          ),
        ),
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
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.24,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.menuUtama,
                            style: theme.textTheme.titleMedium,
                          ),
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
              // Antrean approval = layar kerja harian admin, sejajar sama
              // "Tugas Saya" punya teknisi — bukan pengaturan.
              if (admin)
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: Text(l10n.antreanTitle),
                  onTap: () => keLayar(const AntreanApprovalScreen()),
                ),
              // Alur Kerja tadinya cuma ada di panel Windows, jadi admin yang
              // pegang HP nggak bisa lihat sesi yang sedang jalan sama sekali —
              // dia cuma lihat yang udah masuk antrean approval. Padahal yang
              // nyangkut di tengah itu justru yang perlu ditengok.
              if (admin)
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(l10n.alurTitle),
                  onTap: () => keLayar(const AlurKerjaScreen()),
                ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.navFolderManager),
                onTap: () => keTab(3),
              ),
              // Notifikasi udah bukan tab: dia halaman sendiri yang dibuka dari
              // lonceng di app bar (spesifikasi poin 4). Di menu samping tetap
              // dikasih pintu, tapi lewat `keLayar` — `keTab(3)` sekarang
              // ngarah ke Folder Manager.
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: Text(l10n.navNotifications),
                onTap: () => keLayar(const NotificationScreen()),
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
              if (admin) ...[
                ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(l10n.orgTitle),
                  onTap: () => keLayar(const OrganizationScreen()),
                ),
                // Import Excel = alat masa transisi, bukan kerja harian —
                // makanya ditaruh di Pengaturan, bukan di navbar.
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: Text(l10n.importTitle),
                  onTap: () => keLayar(const ImportExcelScreen()),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.navProfile),
                onTap: () => keTab(4),
              ),
            ],
          ),
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
