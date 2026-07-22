import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dashboard_summary.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../shell/main_shell.dart' show bukaMenuUtama;
import '../../providers/dashboard_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/work_chart.dart';
import '../../widgets/status_badge.dart';
import '../calibration/category_picker_screen.dart';
import '../equipment/equipment_form_screen.dart';
import 'device_overview_screen.dart';

/// Dashboard — 4 state sesuai task 21 Jul:
/// `loading` (skeleton) · `empty` (belum ada apa-apa) · `normal` (angka) ·
/// `error` (gagal muat + tombol coba lagi).
///
/// Isinya beda per role: teknisi lihat angka miliknya sendiri, admin lihat
/// angka lintas-teknisi. **Backend yang nentuin dari token** — mobile cuma
/// ngubah judul & sorotan, nggak ngitung sendiri.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringkasan = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).value;
    final l10n = AppLocalizations.of(context);

    // JANGAN pattern-match `AsyncLoading()` duluan di sini.
    //
    // Riverpod 3 otomatis nyoba ulang provider yang gagal, dan selama nyoba
    // ulang itu state-nya tetap `AsyncLoading` **yang bawa error**. Kalau
    // loading dicek duluan, layar bakal nampilin skeleton selamanya — user
    // nggak pernah lihat pesan gagal atau tombol coba lagi, dan app-nya
    // kelihatan nge-hang. Jadi urutannya: ada data? → ada error? → baru
    // loading.
    final data = ringkasan.value;

    final Widget isi;
    if (data != null) {
      isi = data.kosong ? _Kosong(user: user) : _Isi(data: data, user: user);
    } else if (ringkasan.hasError) {
      isi = _Gagal(
        pesan: ringkasan.error is TokenHilangException
            ? l10n.dashSessionExpired
            : l10n.dashLoadFailed,
        onCobaLagi: () => ref.read(dashboardProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
        // Drawer-nya nempel di Scaffold MainShell, bukan Scaffold ini, jadi
        // tombolnya dipasang manual — Flutter cuma naruh ikon hamburger
        // otomatis kalau Scaffold yang sama yang megang drawer-nya.
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: l10n.menuUtama,
          onPressed: bukaMenuUtama,
        ),
      ),
      // Latar bergradasi, bukan warna rata: kartu SoftRaised butuh bidang yang
      // ada arah cahayanya biar bayangannya kebaca sebagai kedalaman. Di atas
      // warna rata, bayangan lembut cuma kelihatan kayak kotor.
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.gradasiLatar(context)),
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).muatUlang(),
          child: isi,
        ),
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.data, required this.user});

  final DashboardSummary data;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = user?.role.isAdmin ?? false;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Kartu hero nampung angka yang **selalu se-lab** — jumlah alat, alat
        // jatuh tempo, sertifikat terbit. Angka-angka ini nggak pernah
        // disaring per user, jadi aman jadi "wajah" dashboard buat semua role.
        _KartuHero(data: data, user: user),

        // Peringatannya nempel persis di bawah angkanya, bukan di dasar layar
        // kayak dulu — kalau ditaruh jauh, orang keburu scroll lewat.
        if (data.alatOverdue > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _PeringatanOverdue(jumlah: data.alatOverdue),
        ],

        const SizedBox(height: AppSpacing.lg),
        // Judul seksi ini beda per role, dan itu BUKAN kosmetik.
        //
        // Angka sesi di bawah sini disaring backend per user: buat teknisi
        // isinya kerjaan dia sendiri, buat admin lintas-teknisi. Sementara
        // angka di kartu hero selalu se-lab. Tanpa judul yang misahin, layar
        // teknisi nampilin "Selesai: 2" bareng "Sertifikat: 137" tanpa
        // penjelasan — kebaca kayak datanya ngaco, padahal cakupannya emang
        // beda (`docs/kontrak-api.md`, handoff backend §B).
        _JudulSeksi(admin ? l10n.dashCalibrationLab : l10n.dashCalibrationMine),
        const SizedBox(height: AppSpacing.sm),
        // Draft & menunggu-proses dulu ditampilin gantian tergantung role, jadi
        // tiap role cuma lihat separuh gambaran. Sekarang dua-duanya dirender:
        // backend udah ngirim keduanya, jadi nggak ada request tambahan.
        StatCardRow(
          kiri: StatCard(
            label: l10n.dashCalibrationDraft,
            nilai: data.kalibrasiDraft,
            icon: Icons.edit_note,
          ),
          kanan: StatCard(
            label: l10n.dashPendingApproval,
            nilai: data.menungguApproval,
            icon: Icons.hourglass_empty,
            warna: data.menungguApproval > 0 ? AppColors.info : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StatCardWide(
          label: l10n.dashCalibrationDone,
          nilai: data.kalibrasiSelesai,
          icon: Icons.task_alt,
          warna: AppColors.success,
        ),

        // Grafik cuma dirender kalau backend beneran ngirim datanya. Backend
        // versi lama nggak punya `grafik_pekerjaan`, dan seksi kosong berjudul
        // "Grafik pekerjaan" lebih bikin bingung daripada nggak ada sama sekali.
        if (data.grafikPekerjaan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _JudulSeksi(l10n.dashWorkChart),
          const SizedBox(height: AppSpacing.sm),
          GlassSurface.rata(
            radius: AppSpacing.radiusLg,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RingkasanTren(titik: data.grafikPekerjaan),
                const SizedBox(height: AppSpacing.md),
                WorkChart(titik: data.grafikPekerjaan),
              ],
            ),
          ),
        ],

        // Viewer read-only: tombol aksi nggak dirender sama sekali.
        if (user?.role.bisaInput ?? false) ...[
          const SizedBox(height: AppSpacing.lg),
          _JudulSeksi(l10n.dashQuickActions),
          const SizedBox(height: AppSpacing.sm),
          // .rata, bukan kaca ber-blur: panel ini ikut ke-scroll bareng
          // seluruh dashboard. BackdropFilter di sini bakal nge-blur ulang
          // latarnya tiap frame selama jari user gerak.
          GlassSurface.rata(
            radius: AppSpacing.radiusLg,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Satu pintu buat semua kalibrasi, termasuk pH Meter.
                //
                // Dulu ada tombol pintasan "Kalibrasi pH Meter" terpisah di
                // bawah tombol ini. Dihapus karena alurnya udah kelewat sama
                // pintu ini (Kategori → Instrumen Analitik → pH Meter), dan
                // dua tombol yang ujungnya ke form yang sama bikin orang mikir
                // ada dua jenis kalibrasi yang beda.
                AppButton(
                  label: l10n.dashStartCalibration,
                  icon: Icons.add_task,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoryPickerScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.dashAddDevice,
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _bukaTambahAlat(context, ref),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Buka form Tambah Alat, lalu **muat ulang dashboard** kalau alatnya jadi
/// disimpan. Tanpa ini, teknisi balik ke dashboard dan lihat "Total alat" masih
/// angka lama — kelihatan kayak alatnya gagal kesimpen, padahal cuma
/// ringkasannya yang basi.
Future<void> _bukaTambahAlat(BuildContext context, WidgetRef ref) async {
  // Notifier-nya diambil SEBELUM `await`: sesudah form-nya ketutup, widget
  // yang manggil bisa aja udah nggak ke-mount, dan `ref` yang udah dibuang
  // ngelempar begitu dipakai.
  final dashboard = ref.read(dashboardProvider.notifier);

  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const EquipmentFormScreen()),
  );

  await dashboard.muatUlang();
}

/// Kartu pembuka: sapaan + angka lab yang paling sering dicari.
///
/// Angka di sini sengaja cuma yang cakupannya **se-lab** (`total_alat`,
/// `alat_overdue`, `total_sertifikat`) — biar satu kartu ini punya satu arti
/// yang konsisten buat semua role, nggak campur sama angka yang disaring
/// per user.
class _KartuHero extends StatelessWidget {
  const _KartuHero({required this.data, required this.user});

  final DashboardSummary data;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return GlassSurface.rata(
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            _Sapaan(user: user!),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.dashLabScope.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AngkaHero(
                  label: l10n.dashTotalDevices,
                  nilai: data.totalAlat,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DeviceOverviewScreen(title: l10n.dashTotalDevices),
                    ),
                  ),
                ),
                _GarisPemisah(),
                _AngkaHero(
                  label: l10n.dashOverdue,
                  nilai: data.alatOverdue,
                  warna: data.alatOverdue > 0 ? AppColors.warning : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeviceOverviewScreen(
                        title: l10n.dashOverdue,
                        statusFilter: 'overdue',
                      ),
                    ),
                  ),
                ),
                _GarisPemisah(),
                _AngkaHero(
                  label: l10n.dashTotalCerts,
                  nilai: data.totalSertifikat,
                  // Angka bulan berjalan nempel sebagai sub-teks, bukan kartu
                  // sendiri: dia cuma bikin angka total di atasnya kebaca
                  // ("dari sekian banyak, sekian terbit bulan ini").
                  sub: l10n.dashCertsThisMonthSub(data.sertifikatBulanIni),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AngkaHero extends StatelessWidget {
  const _AngkaHero({
    required this.label,
    required this.nilai,
    this.sub,
    this.warna,
    this.onTap,
  });

  final String label;
  final int nilai;
  final String? sub;
  final Color? warna;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$nilai',
                // Lebar digit tetap — biar tiga angka sebaris ini lurus dan
                // nggak goyang tiap kali nilainya berubah.
                style: AppTypography.measurement.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 34 / 28,
                  letterSpacing: -0.28,
                  color: warna ?? theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarisPemisah extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// Satu baris ringkas di atas grafik: kerjaan selesai periode terakhir naik
/// atau turun dibanding periode sebelumnya.
///
/// Grafik batang bagus buat ngebandingin, tapi arah gerakannya baru kebaca
/// setelah orang neliti tiap batang. Kalimat pendek ini yang ngasih
/// kesimpulannya duluan.
class _RingkasanTren extends StatelessWidget {
  const _RingkasanTren({required this.titik});

  final List<TitikTren> titik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Butuh dua periode buat bisa dibandingin — satu batang nggak punya
    // "sebelumnya".
    if (titik.length < 2) return const SizedBox.shrink();

    final selisih = titik.last.selesai - titik[titik.length - 2].selesai;

    final (IconData ikon, Color warna, String teks) = switch (selisih) {
      > 0 => (Icons.trending_up, AppColors.success, l10n.dashTrendUp(selisih)),
      < 0 => (
        Icons.trending_down,
        AppColors.warning,
        l10n.dashTrendDown(-selisih),
      ),
      _ => (
        Icons.trending_flat,
        theme.colorScheme.onSurfaceVariant,
        l10n.dashTrendFlat,
      ),
    };

    return Row(
      children: [
        Icon(ikon, size: 18, color: warna),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            teks,
            style: theme.textTheme.bodySmall?.copyWith(color: warna),
          ),
        ),
      ],
    );
  }
}

/// Judul seksi — huruf besar, spasi lebar, warna kalem. Dia penunjuk arah,
/// bukan isi, jadi sengaja nggak ikut nyolok kayak angka di kartu.
class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      teks.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Sapaan extends StatelessWidget {
  const _Sapaan({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).dashGreeting,
                style: theme.textTheme.bodySmall,
              ),
              Text(user.nama, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        StatusBadge(
          label: user.role.label,
          tone: user.role.isAdmin ? BadgeTone.info : BadgeTone.neutral,
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }
}

/// Peringatan alat lewat jatuh tempo — **bisa dipencet** langsung ke daftar
/// alatnya. Peringatan yang cuma ngasih angka tanpa jalan keluar bikin orang
/// harus nyari sendiri alat mana yang telat.
class _PeringatanOverdue extends StatelessWidget {
  const _PeringatanOverdue({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeviceOverviewScreen(
            title: l10n.dashOverdue,
            statusFilter: 'overdue',
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.dashOverdueWarning(jumlah),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Kosong extends ConsumerWidget {
  const _Kosong({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bisaInput = user?.role.bisaInput ?? false;

    // ListView (bukan Center) biar tetap bisa ditarik buat refresh.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.dashEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          bisaInput ? l10n.dashEmptyBodyInput : l10n.dashEmptyBodyReadonly,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (bisaInput) ...[
          const SizedBox(height: AppSpacing.lg),
          // Di state kosong tombol ini satu-satunya jalan maju yang masuk akal:
          // belum ada alat, jadi belum ada yang bisa dikalibrasi.
          AppButton(
            label: l10n.dashAddDevice,
            icon: Icons.add,
            onPressed: () => _bukaTambahAlat(context, ref),
          ),
        ],
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).dashRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SkeletonBox(height: 14, width: 60),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonBox(height: 28, width: 180),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBox(height: 12, width: 140),
        const SizedBox(height: AppSpacing.sm),
        const StatCardRow(kiri: StatCardSkeleton(), kanan: StatCardSkeleton()),
        const SizedBox(height: AppSpacing.sm),
        const StatCardRow(kiri: StatCardSkeleton(), kanan: StatCardSkeleton()),
      ],
    );
  }
}
