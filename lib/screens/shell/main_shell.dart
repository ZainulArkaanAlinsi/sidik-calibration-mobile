import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/koreksi_provider.dart';
import '../../providers/permintaan_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../widgets/floating_nav_bar.dart';
import '../dashboard/dashboard_screen.dart';
import '../draf/draf_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../folder/folder_manager_screen.dart';
import '../history/history_screen.dart';
import '../admin/antrean_approval_screen.dart';
import '../alur/alur_kerja_screen.dart';
import '../../widgets/pemantau_antrean.dart';
import '../notification/notification_screen.dart';
import '../jatuh_tempo/layar_jatuh_tempo.dart';
import '../pelacakan/pelacakan_screen.dart';
import '../pelanggan/pusat_pelanggan_screen.dart';
import '../koreksi/antrean_koreksi_screen.dart';
import '../permintaan/antrean_permintaan_screen.dart';
import '../pengesahan/antrean_pengesahan_screen.dart';
import '../penugasan/penugasan_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/kelola_lab_screen.dart';

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

/// Satu baris menu samping. `tab` diisi kalau tujuannya tab navbar (supaya
/// barisnya bisa ikut menyala saat tab itu aktif); selain itu `layar`.
class _Tujuan {
  const _Tujuan(this.ikon, this.judul, {this.tab, this.layar, this.lencana});

  final IconData ikon;
  final String judul;
  final int? tab;
  final Widget Function()? layar;

  /// Angka kecil di ujung baris (mis. permintaan baru). Widget sendiri supaya
  /// yang menonton provider-nya cuma baris ini, bukan seluruh drawer.
  final Widget? lencana;
}

/// Jumlah permintaan pelanggan yang menunggu keputusan. Kosong (tanpa angka)
/// kalau nol atau belum termuat — angka dekorasi tidak boleh menahan menu.
class _LencanaPermintaan extends ConsumerWidget {
  const _LencanaPermintaan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(jumlahPermintaanBaruProvider).value ?? 0;
    return _LencanaAngka(
      n: n,
      kunci: const ValueKey('lencana-permintaan'),
      label: AppLocalizations.of(context).permintaanBadge(n),
    );
  }
}

/// Jumlah koreksi pelanggan yang menunggu keputusan (`meta.jumlah.menunggu`).
class _LencanaKoreksi extends ConsumerWidget {
  const _LencanaKoreksi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(jumlahKoreksiMenungguProvider).value ?? 0;
    return _LencanaAngka(
      n: n,
      kunci: const ValueKey('lencana-koreksi'),
      label: AppLocalizations.of(context).koreksiBadge(n),
    );
  }
}

class _LencanaAngka extends StatelessWidget {
  const _LencanaAngka({
    required this.n,
    required this.kunci,
    required this.label,
  });

  final int n;
  final Key kunci;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (n <= 0) return const SizedBox.shrink();

    final m = SidikMaterial.of(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: kunci,
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: m.biru,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          n > 99 ? '99+' : '$n',
          textAlign: TextAlign.center,
          style: SidikTheme.gayaAngka(
            ukuran: 11,
            warna: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Menu samping — **isinya beda per peran**, karena pekerjaan hariannya beda.
///
/// Dulu satu daftar yang sama buat semua orang, disaring `if (admin)` di
/// sana-sini: super admin melihat menu teknisi (Draf) yang tidak bisa dia isi,
/// dan teknisi tidak punya jalan ke "Tugas saya" sama sekali. Sekarang tiap
/// peran dapat urutan yang dimulai dari pekerjaan UTAMANYA:
///
/// - **Super admin** — Pengesahan sertifikat di paling atas; sisanya seksi
///   "Pantau (baca saja)" supaya dia tidak mencari tombol yang memang tidak
///   ada untuknya.
/// - **Admin** — Antrean approval, Pengesahan (status & tarik), Alur kerja,
///   Pelacakan, Penugasan; semua pengaturan di SATU pintu "Kelola lab".
/// - **Teknisi** — Tugas saya & Draf dulu, baru arsip.
/// - **Viewer** — arsip & pelacakan saja.
///
/// Izin tetap dijaga server; menu ini cuma tidak menawarkan pintu yang pasti
/// dijawab 403. **Cuma berisi tujuan yang layarnya sudah ada.**
class _MenuUtama extends ConsumerWidget {
  const _MenuUtama();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final user = ref.watch(authProvider).value;
    final peran = user?.role ?? UserRole.viewer;
    final tabAktif = ref.watch(selectedTabProvider);

    final beranda = _Tujuan(Icons.space_dashboard_outlined, l10n.navDashboard, tab: 0);
    final alat = _Tujuan(Icons.straighten_outlined, l10n.navEquipment, tab: 1);
    final riwayat = _Tujuan(Icons.history_outlined, l10n.navHistory, tab: 2);
    final folder = _Tujuan(Icons.folder_outlined, l10n.navFolderManager, tab: 3);
    final profil = _Tujuan(Icons.person_outline, l10n.navProfile, tab: 4);
    final notifikasi = _Tujuan(Icons.notifications_none, l10n.navNotifications,
        layar: () => const NotificationScreen());
    final permintaan = _Tujuan(Icons.move_to_inbox_outlined, l10n.permintaanJudul,
        layar: () => const AntreanPermintaanScreen(),
        lencana: const _LencanaPermintaan());
    final koreksi = _Tujuan(Icons.rule_folder_outlined, l10n.koreksiJudul,
        layar: () => const AntreanKoreksiScreen(),
        lencana: const _LencanaKoreksi());
    final pengesahan = _Tujuan(Icons.verified_outlined, l10n.pengesahanJudul,
        layar: () => const AntreanPengesahanScreen());
    final pelacakan = _Tujuan(Icons.local_shipping_outlined, l10n.pelacakanJudul,
        layar: () => const PelacakanScreen());
    final penugasan = _Tujuan(Icons.assignment_ind_outlined, l10n.penugasanJudul,
        layar: () => const PenugasanScreen());
    final pusat = _Tujuan(Icons.apartment_outlined, l10n.pusatJudul,
        layar: () => const PusatPelangganScreen());
    final jadwal = _Tujuan(Icons.event_repeat_outlined, l10n.jadwalJudul,
        layar: () => const JadwalKalibrasiScreen());
    final alur = _Tujuan(Icons.account_tree_outlined, l10n.alurTitle,
        layar: () => const AlurKerjaScreen());
    final draf = _Tujuan(Icons.edit_note, l10n.drafTitle,
        layar: () => const DrafScreen());

    final List<(String?, List<_Tujuan>)> seksi = switch (peran) {
      UserRole.superAdmin => [
        (l10n.menuKerjaHarian, [beranda, pengesahan, penugasan, pelacakan]),
        (l10n.menuPantau, [permintaan, koreksi, jadwal, pusat, alur, riwayat, alat, folder]),
        (null, [notifikasi, profil]),
      ],
      UserRole.admin => [
        (l10n.menuKerjaHarian, [
          beranda,
          _Tujuan(Icons.inbox_outlined, l10n.antreanTitle,
              layar: () => const AntreanApprovalScreen()),
          permintaan,
          koreksi,
          pengesahan,
          alur,
          penugasan,
          pelacakan,
          draf,
        ]),
        (l10n.menuArsip, [riwayat, alat, pusat, jadwal, folder, notifikasi]),
        (l10n.menuPengaturan, [
          _Tujuan(Icons.tune, l10n.kelolaJudul,
              layar: () => const KelolaLabScreen()),
          profil,
        ]),
      ],
      UserRole.teknisi => [
        (l10n.menuKerjaHarian, [
          beranda,
          _Tujuan(Icons.assignment_ind_outlined, l10n.penugasanTugasSaya,
              layar: () => const PenugasanScreen()),
          draf,
          riwayat,
        ]),
        (l10n.menuArsip, [alat, pelacakan, folder, notifikasi]),
        (null, [profil]),
      ],
      UserRole.viewer => [
        (l10n.menuArsip, [beranda, riwayat, alat, pelacakan, folder]),
        (null, [notifikasi, profil]),
      ],
    };

    void buka(_Tujuan t) {
      Navigator.of(context).pop();
      if (t.tab != null) {
        ref.read(selectedTabProvider.notifier).select(t.tab!);
      } else if (t.layar != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => t.layar!()),
        );
      }
    }

    return Drawer(
      backgroundColor: m.kertas,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            // Kepala menu: pelat LOGAM (bingkai), bukan petak berpendar —
            // isinya siapa yang sedang masuk dan sebagai apa, supaya orang
            // yang pinjam HP rekannya langsung sadar menunya milik siapa.
            Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: m.logamTimbul(radius: SidikMaterial.sudutLogam),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: m.logamTertekan(radius: 9),
                    child: Icon(Icons.biotech_outlined, color: m.etsa, size: 21),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nama ?? l10n.menuUtama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: m.tinta,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          peran.label.toUpperCase(),
                          style: m.gayaEtsa(ukuran: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Dua peran yang TIDAK bisa mengisi data dapat satu kalimat yang
            // bilang apa yang bisa & tidak — supaya mereka tidak mencari
            // tombol yang memang tidak ada untuknya (artboard Menu_*).
            if (peran == UserRole.superAdmin || peran == UserRole.viewer)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  peran == UserRole.superAdmin
                      ? l10n.menuCatatanSuperAdmin
                      : l10n.menuCatatanViewer,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final (judul, isi) in seksi) ...[
              if (judul != null) _LabelSeksi(judul) else const Divider(),
              for (final t in isi)
                ListTile(
                  leading: Icon(t.ikon),
                  title: Text(t.judul),
                  trailing: t.lencana,
                  selected: t.tab != null && t.tab == tabAktif,
                  // Tinta, bukan `primary`: di tema gelap biru di atas
                  // biru-tipis cuma 1,9:1 — baris aktif malah jadi yang
                  // paling susah dibaca. Penandanya latar, bukan warna teks.
                  selectedColor: m.tinta,
                  selectedTileColor: m.biruTipis,
                  onTap: () => buka(t),
                ),
            ],
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
    final m = SidikMaterial.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(teks.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
    );
  }
}
