import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../widgets/notification_bell.dart';
import '../admin/antrean_approval_screen.dart';
import '../order/my_tasks_screen.dart';
import '../settings/rumus_list_screen.dart';
import '../admin/import_excel_screen.dart';
import '../alur/alur_kerja_screen.dart';
import '../arsip/arsip_screen.dart';
import '../dashboard/ringkasan_screen.dart';
import '../../widgets/pemantau_antrean.dart';
import '../equipment/equipment_list_screen.dart';
import '../folder/folder_manager_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/customer_list_screen.dart';
import '../settings/organization_screen.dart';
import '../settings/standard_list_screen.dart';
import '../settings/tanda_tangan_screen.dart';
import '../settings/technician_list_screen.dart';

/// Panel admin desktop — sidebar tetap + bilah atas + area kerja.
///
/// Beda dari `MainShell` yang cuma mindahin navbar HP ke samping: di sini
/// menunya **dikelompokkan per urusan** (operasional / dokumen / master data /
/// sistem) dan semuanya kelihatan sekaligus. Di layar 1280px ke atas,
/// nyembunyiin sepuluh tujuan di balik hamburger cuma nyia-nyiain ruang yang
/// justru berlimpah.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  static const _lebarSidebar = 272.0;

  String _dipilih = _Menu.ringkasan;
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    // Sama kayak MainShell: sinkron realtime nyala selama panel kebuka.
    ref.watch(realtimeSyncProvider);

    final menu = _seksiTerpakai(context, ref);

    // Menu yang lagi dipilih bisa ilang dari daftar kalau izinnya berubah di
    // tengah jalan (mis. token di-refresh dan rolenya turun). Jatuh balik ke
    // Ringkasan daripada nampilin area kerja kosong.
    final semua = [for (final s in menu) ...s.menu];
    final aktif = semua.where((m) => m.id == _dipilih).firstOrNull ?? semua.first;

    return Scaffold(
      // Pemantau dibungkus di LUAR isi, bukan di dalam satu layar: kiriman
      // teknisi bisa masuk kapan aja, dan admin jarang lagi buka dashboard
      // waktu itu terjadi.
      body: PemantauAntrean(
        child: Row(
        children: [
          SizedBox(
            width: _lebarSidebar,
            child: _Sidebar(
              seksi: _saring(menu),
              dipilih: aktif.id,
              cari: _cari,
              onCari: (v) => setState(() => _cari = v),
              onPilih: (id) => setState(() => _dipilih = id),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                const _BilahAtas(),
                const Divider(height: 1, thickness: 1),
                Expanded(child: aktif.bangun()),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Buang menu yang nggak cocok sama kata kunci, lalu buang seksi yang jadi
  /// kosong — judul seksi tanpa isi cuma bikin daftarnya keliatan rusak.
  List<_Seksi> _saring(List<_Seksi> seksi) {
    final kunci = _cari.trim().toLowerCase();
    if (kunci.isEmpty) return seksi;

    return [
      for (final s in seksi)
        if (s.menu.any((m) => m.label.toLowerCase().contains(kunci)))
          _Seksi(
            judul: s.judul,
            menu: [
              for (final m in s.menu)
                if (m.label.toLowerCase().contains(kunci)) m,
            ],
          ),
    ];
  }

  /// Daftar menu sesudah disaring per izin.
  ///
  /// Angka di kanan menu diambil dari ringkasan dashboard yang **udah ketarik
  /// buat halaman Ringkasan** — bukan request tambahan. Kalau belum nyampe,
  /// angkanya nggak ditampilin, bukan ditampilin nol (nol itu pernyataan, dan
  /// "belum tahu" bukan nol).
  List<_Seksi> _seksiTerpakai(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final peran = ref.watch(authProvider).value?.role;
    final ringkas = ref.watch(dashboardProvider).value;

    final bolehSetujui = ref.bolehkah(
      NamaIzin.kalibrasiSetujui,
      cadangan: peran.adminSaja,
    );
    final bolehMasterData = ref.bolehkah(
      NamaIzin.masterDataUbah,
      cadangan: peran.adminSaja,
    );
    final bolehAkun = ref.bolehkah(
      NamaIzin.akunKelola,
      cadangan: peran.adminSaja,
    );
    final bolehTtd = ref.bolehkah(
      NamaIzin.tandaTanganKelola,
      cadangan: peran.adminSaja,
    );

    return [
      _Seksi(
        judul: l10n.panelSeksiOperasional,
        menu: [
          _Menu(
            id: _Menu.ringkasan,
            ikon: Icons.space_dashboard_outlined,
            label: l10n.panelRingkasan,
            bangun: RingkasanScreen.new,
          ),
          _Menu(
            id: 'alur',
            ikon: Icons.account_tree_outlined,
            label: l10n.alurTitle,
            bangun: AlurKerjaScreen.new,
          ),
          // "Tugas Saya" tadinya cuma ada di HP, jadi teknisi yang kerja di
          // laptop nggak punya jalan ke tugasnya sendiri — dia mesti nyisir
          // Alur Kerja yang isinya sesi semua orang. Sejajar sama Antrean
          // punya admin: dua-duanya layar kerja harian, beda perannya.
          if (peran?.bisaInput ?? false)
            _Menu(
              id: 'tugas',
              ikon: Icons.assignment_outlined,
              label: l10n.tugasTitle,
              bangun: MyTasksScreen.new,
            ),
          if (bolehSetujui)
            _Menu(
              id: 'antrean',
              ikon: Icons.inbox_outlined,
              label: l10n.antreanTitle,
              angka: ringkas?.menungguApproval,
              bangun: AntreanApprovalScreen.new,
            ),
          _Menu(
            id: 'alat',
            ikon: Icons.straighten_outlined,
            label: l10n.navEquipment,
            angka: ringkas?.totalAlat,
            bangun: EquipmentListScreen.new,
          ),
        ],
      ),
      _Seksi(
        judul: l10n.panelSeksiDokumen,
        menu: [
          _Menu(
            id: 'riwayat',
            ikon: Icons.history_outlined,
            label: l10n.navHistory,
            angka: ringkas?.totalSertifikat,
            bangun: HistoryScreen.new,
          ),
          _Menu(
            id: 'folder',
            ikon: Icons.folder_outlined,
            label: l10n.navFolderManager,
            bangun: FolderManagerScreen.new,
          ),
          _Menu(
            id: 'arsip',
            ikon: Icons.folder_copy_outlined,
            label: l10n.profArsip,
            bangun: ArsipScreen.new,
          ),
        ],
      ),
      if (bolehMasterData || bolehAkun)
        _Seksi(
          judul: l10n.menuMasterData,
          menu: [
            if (bolehMasterData) ...[
              _Menu(
                id: 'pelanggan',
                ikon: Icons.people_outline,
                label: l10n.profCustomers,
                bangun: CustomerListScreen.new,
              ),
              _Menu(
                id: 'standar',
                ikon: Icons.science_outlined,
                label: l10n.standarTitle,
                bangun: StandardListScreen.new,
              ),
            ],
            if (bolehAkun)
              _Menu(
                id: 'rumus',
                ikon: Icons.functions_outlined,
                label: l10n.rumusTitle,
                bangun: RumusListScreen.new,
              ),
              _Menu(
                id: 'teknisi',
                ikon: Icons.badge_outlined,
                label: l10n.teknisiTitle,
                bangun: TechnicianListScreen.new,
              ),
          ],
        ),
      if (bolehMasterData || bolehTtd)
        _Seksi(
          judul: l10n.panelSeksiSistem,
          menu: [
            if (bolehMasterData) ...[
              _Menu(
                id: 'impor',
                ikon: Icons.upload_file_outlined,
                label: l10n.importTitle,
                bangun: ImportExcelScreen.new,
              ),
              _Menu(
                id: 'organisasi',
                ikon: Icons.apartment_outlined,
                label: l10n.orgTitle,
                bangun: OrganizationScreen.new,
              ),
            ],
            if (bolehTtd)
              _Menu(
                id: 'ttd',
                ikon: Icons.draw_outlined,
                label: l10n.profTandaTangan,
                bangun: TandaTanganScreen.new,
              ),
          ],
        ),
    ];
  }
}

// ------------------------------------------------------------------- struktur

class _Seksi {
  const _Seksi({required this.judul, required this.menu});

  final String judul;
  final List<_Menu> menu;
}

class _Menu {
  const _Menu({
    required this.id,
    required this.ikon,
    required this.label,
    required this.bangun,
    this.angka,
  });

  static const ringkasan = 'ringkasan';

  final String id;
  final IconData ikon;
  final String label;
  final Widget Function() bangun;

  /// Angka di kanan label. `null` = belum diketahui, jadi nggak digambar.
  final int? angka;
}

// -------------------------------------------------------------------- sidebar

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.seksi,
    required this.dipilih,
    required this.cari,
    required this.onCari,
    required this.onPilih,
  });

  final List<_Seksi> seksi;
  final String dipilih;
  final String cari;
  final ValueChanged<String> onCari;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Merek(),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              onChanged: onCari,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.panelCariMenu,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
            ),
          ),
          Expanded(
            child: seksi.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        l10n.panelMenuKosong,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      for (final s in seksi) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            s.judul.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final m in s.menu)
                          _BarisMenu(
                            menu: m,
                            aktif: m.id == dipilih,
                            onTap: () => onPilih(m.id),
                          ),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1, thickness: 1),
          const _KakiSidebar(),
        ],
      ),
    );
  }
}

class _Merek extends ConsumerWidget {
  const _Merek();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              'S',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sidik Calibration',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  // Nomor akreditasi lab, bukan hiasan: ini yang bikin jelas
                  // panel-nya kepasang ke lab yang mana.
                  l10n.panelSubjudul('LK-285-IDN'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.menu,
    required this.aktif,
    required this.onTap,
  });

  final _Menu menu;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = aktif
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 1,
      ),
      child: Material(
        color: aktif
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(menu.ikon, size: 18, color: warna),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    menu.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: aktif ? theme.colorScheme.primary : null,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (menu.angka != null)
                  Text(
                    '${menu.angka}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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

/// Keterangan sambungan di kaki sidebar.
///
/// Isinya sengaja **keadaan sambungan yang sebenarnya** (server mana, mode
/// apa), bukan angka-angka mesin lokal: app ini nembak API Laravel, jadi
/// nampilin ukuran berkas SQLite bakal jadi keterangan yang kelihatan
/// meyakinkan tapi bohong.
class _KakiSidebar extends StatelessWidget {
  const _KakiSidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaya = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppConfig.apiBaseUrl, maxLines: 2, style: gaya),
          Text(
            AppConfig.useMock
                ? 'MOCK · tanpa server'
                : '${AppConfig.envLabel} · API langsung',
            style: gaya,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- bilah atas

class _BilahAtas extends ConsumerWidget {
  const _BilahAtas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).value;
    final gelap = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            const Spacer(),
            const _PilSinkron(),
            const SizedBox(width: AppSpacing.sm),
            const NotificationBell(),
            IconButton(
              tooltip: l10n.panelTema,
              icon: Icon(gelap ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => ref
                  .read(themeModeProvider.notifier)
                  .toggle(gelapSekarang: gelap),
            ),
            const SizedBox(width: AppSpacing.xs),
            _Avatar(nama: user?.nama ?? '?'),
          ],
        ),
      ),
    );
  }
}

/// Penanda sinkron realtime. Warnanya ngikut [AppConfig.realtimeAktif] — kalau
/// kunci Reverb belum dipasang, penandanya redup, bukan hijau bohongan.
class _PilSinkron extends StatelessWidget {
  const _PilSinkron();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final nyala = AppConfig.realtimeAktif;
    final warna = nyala ? theme.colorScheme.primary : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            nyala ? l10n.panelSinkronAktif : l10n.panelSinkronMati,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inisial user + pintu ke Profil.
///
/// Profil sengaja **nggak** dikasih slot di sidebar: dia bukan tempat kerja,
/// dan di panel admin slot sidebar itu buat urusan lab. Tapi tetap harus ada
/// jalannya — tanpa ini nggak ada cara keluar akun di desktop.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nama});

  final String nama;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final inisial = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((k) => k.isNotEmpty)
        .take(2)
        .map((k) => k[0].toUpperCase())
        .join();

    return Tooltip(
      message: nama,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            inisial.isEmpty ? '?' : inisial,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
            semanticsLabel: l10n.navProfile,
          ),
        ),
      ),
    );
  }
}
