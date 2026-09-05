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
import '../../widgets/banner_update.dart';
import '../../widgets/pemasang_otomatis.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/tampil_masuk.dart';
import '../../widgets/work_chart.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/technician_pulse_panel.dart';
import '../../widgets/notification_bell.dart';
import '../calibration/category_picker_screen.dart';
import '../draf/draf_screen.dart';
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
        // Ikon notifikasi di atas layar (spesifikasi poin 4), bukan di navbar
        // bawah — tempatnya di navbar diambil Folder Manager.
        actions: const [
          NotificationBell(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      // Latar bergradasi, bukan warna rata: kartu SoftRaised butuh bidang yang
      // ada arah cahayanya biar bayangannya kebaca sebagai kedalaman. Di atas
      // warna rata, bayangan lembut cuma kelihatan kayak kotor.
      body: Container(
        decoration: BoxDecoration(color: AppColors.warnaLatar(context)),
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).muatUlang(),
          // Di DALAM Container, biar gradasi latarnya tetap penuh selebar
          // jendela — yang dibatasi cuma isinya.
          //
          // `PemasangOtomatis` memulangkan anaknya apa adanya; dia nggak
          // menggambar apa-apa dan nggak mengubah tata letak. Yang
          // dikerjakannya cuma satu: membuka layar pemasang Android sendiri
          // waktu aplikasi dibuka, kalau APK pemutakhirannya memang sudah
          // terunduh di latar. Syarat lengkapnya ada di kelasnya.
          child: PemasangOtomatis(child: ReadableWidth(child: isi)),
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
    final teknisi = !admin && (user?.role.bisaInput ?? false);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      // Kartunya datang berurutan, bukan serempak. Susunannya nggak dipindah
      // sama sekali — `berurutan` cuma membungkus tiap anak di tempatnya, dan
      // widget jarak dilewati supaya iramanya rata.
      children: berurutan([
        // Pemberitahuan versi baru ditaruh PALING ATAS, sebelum angka apa pun.
        //
        // Bukan di layar Pengaturan yang jarang dibuka: yang perlu memperbarui
        // itu teknisi yang tiap hari membuka dashboard, dan sebelum ini
        // caranya bolak-balik unduh manual dari GitHub atau email. Widget ini
        // menggambar dirinya sebagai kotak kosong waktu tidak ada
        // pemutakhiran — tidak memakan ruang dan tidak menggeser apa pun.
        const BannerUpdate(),

        // Teknisi masuk lewat command deck yang fokus ke kerja pribadinya;
        // admin tetap melihat ringkasan se-lab. Sumber datanya sama.
        if (teknisi)
          TechnicianPulsePanel(
            name: user?.nama ?? '',
            title: l10n.dashCalibrationMine,
            startLabel: l10n.dashStartCalibration,
            draftLabel: l10n.dashCalibrationDraft,
            pendingLabel: l10n.dashPendingApproval,
            doneLabel: l10n.dashCalibrationDone,
            activeLabel: l10n.dashActiveTasks(
              data.kalibrasiDraft + data.menungguApproval,
            ),
            liveLabel: l10n.dashLiveWorkspace,
            draft: data.kalibrasiDraft,
            pending: data.menungguApproval,
            done: data.kalibrasiSelesai,
            // Angka draf dulu cuma angka mati. Teknisi yang lihat "3" di sini
            // nggak punya jalan dari situ ke tiga lembarnya — dia mesti buka
            // menu samping, atau nyisir Riwayat yang campur sesi selesai.
            onDraftTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DrafScreen()),
            ),
            onStart: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryPickerScreen(),
              ),
            ),
          )
        else
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
        if (teknisi) ...[
          _JudulSeksi(l10n.dashLabScope),
          const SizedBox(height: AppSpacing.sm),
          _RingkasanLab(data: data, l10n: l10n),
        ] else ...[
          _JudulSeksi(l10n.dashCalibrationLab),
          const SizedBox(height: AppSpacing.sm),
          // Draft & menunggu-proses dulu ditampilin gantian tergantung role,
          // jadi tiap role cuma lihat separuh gambaran. Sekarang dua-duanya
          // dirender: backend udah ngirim keduanya, jadi nggak ada request
          // tambahan.
          StatCardRow(
            kiri: StatCard(
              label: l10n.dashCalibrationDraft,
              nilai: data.kalibrasiDraft,
              icon: Icons.edit_note,
              // Sama kayak panel teknisi di atas: angkanya nunjuk ke layar
              // yang isinya, bukan berhenti sebagai angka. Buat admin isinya
              // draf semua teknisi — yang nyangkut di tengah itu justru yang
              // perlu ditengok.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DrafScreen()),
              ),
            ),
            kanan: StatCard(
              label: l10n.dashPendingApproval,
              nilai: data.menungguApproval,
              icon: Icons.hourglass_empty,
              warna: data.menungguApproval > 0
                  ? AppColors.statusInfo(context)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatCardWide(
            label: l10n.dashCalibrationDone,
            nilai: data.kalibrasiSelesai,
            icon: Icons.task_alt,
            warna: AppColors.statusSukses(context),
          ),
        ],

        // Grafik cuma dirender kalau backend beneran ngirim datanya. Backend
        // versi lama nggak punya `grafik_pekerjaan`, dan seksi kosong berjudul
        // "Grafik pekerjaan" lebih bikin bingung daripada nggak ada sama sekali.
        // Grafiknya cuma buat ADMIN. Dashboard teknisi sengaja dipendekin
        // jadi empat blok — angka miliknya sendiri, peringatan jatuh tempo,
        // angka se-lab, satu aksi. Layar ini dibuka sambil berdiri di depan
        // alat, bukan sambil duduk nganalisa tren; buat teknisi grafik enam
        // bulan cuma nambah satu layar scroll sebelum tombol yang beneran dia
        // butuhin. Datanya nggak ilang — tetap ada di Riwayat.
        if (!teknisi && data.grafikPekerjaan.isNotEmpty) ...[
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
                if (!teknisi) ...[
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
                ],
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
      ]),
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

  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const EquipmentFormScreen()));

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
                  warna: data.alatOverdue > 0
                      ? AppColors.statusPeringatan(context)
                      : null,
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
                // Backend belum ngirim `total_sertifikat`, jadi angkanya bisa
                // `null`. Yang ditampilin angka bulan ini — itu yang BENERAN
                // dikirim — daripada nulis nol yang ngarang.
                _AngkaHero(
                  label: l10n.dashTotalCerts,
                  nilai: data.totalSertifikat ?? data.sertifikatBulanIni,
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

/// Ringkasan se-lab versi ringkas untuk teknisi. Dipisah dari command deck
/// supaya angka kerja pribadi tidak tercampur dengan angka yang cakupannya
/// seluruh lab, tetapi pintasan ke detailnya tetap tersedia.
class _RingkasanLab extends StatelessWidget {
  const _RingkasanLab({required this.data, required this.l10n});

  final DashboardSummary data;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return GlassSurface.rata(
      radius: 22,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: IntrinsicHeight(
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
              warna: data.alatOverdue > 0
                  ? AppColors.statusPeringatan(context)
                  : null,
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
              nilai: data.totalSertifikat ?? data.sertifikatBulanIni,
              sub: l10n.dashCertsThisMonthSub(data.sertifikatBulanIni),
            ),
          ],
        ),
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
      > 0 => (
        Icons.trending_up,
        AppColors.statusSukses(context),
        l10n.dashTrendUp(selisih),
      ),
      < 0 => (
        Icons.trending_down,
        AppColors.statusPeringatan(context),
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

    // Satu-satunya bidang di dashboard yang warnanya pekat penuh. Itu
    // disengaja: kalau ada alat lewat jatuh tempo, ini yang harus ketangkep
    // duluan waktu layar kebuka, dan blok crimson utuh nyampe itu tanpa perlu
    // ukuran atau animasi.
    //
    // Dulu bidang ini cobalt dan amber ditumpuk pakai alpha di atas latar —
    // hasilnya lavender kusam, warna yang nggak ada di palet mana pun. Warna
    // pekat + teks putih jauh lebih kebaca, dan nggak berubah rona kalau
    // latarnya ganti.
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
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          color: AppColors.crimson,
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.white,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.dashOverdueWarning(jumlah),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.white),
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
