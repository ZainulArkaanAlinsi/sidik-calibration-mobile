import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/inisial_nama.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart' show userListProvider;
import '../../providers/super_admin_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'hak_super_admin.dart';
import 'pengguna_form_screen.dart';
import 'widgets/dialog_isian.dart';
import 'widgets/pesan_galat_sa.dart';
import 'widgets/pesan_layar.dart';

/// Pengguna lab — semua peran internal, dengan saringan peran/status/cari.
///
/// Aksi (semuanya diambil ulang dari server sesudah sukses, bukan ditambal di
/// state lokal): tambah admin/teknisi, ubah data, setel ulang sandi, setujui /
/// tolak pendaftar `pending`, nonaktifkan / aktifkan kembali.
///
/// **Tidak ada Hapus.** Akun dinonaktifkan; riwayat sertifikat & audit
/// menempel di akun. Tiap tombol mengikuti izin server (`/me/permissions`);
/// menyembunyikannya bukan kontrol akses — server tetap menolak 403.
class PenggunaScreen extends ConsumerStatefulWidget {
  const PenggunaScreen({super.key});

  @override
  ConsumerState<PenggunaScreen> createState() => _PenggunaScreenState();
}

class _PenggunaScreenState extends ConsumerState<PenggunaScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;
  bool _memuatLagi = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  PenggunaSaController get _ctl => ref.read(penggunaSaProvider.notifier);

  void _cariBerubah(String kata) {
    _debounce?.cancel();
    // 400 ms: mencari tiap ketikan menembak API tiap huruf.
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _ctl.saring(_ctl.filter.salin(cari: kata));
    });
  }

  Future<void> _muatLagi() async {
    if (_memuatLagi) return;
    setState(() => _memuatLagi = true);
    try {
      await _ctl.muatLebihBanyak();
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  /// Daftar di layar ini DAN daftar Data Teknisi (layar lama) memuat ulang.
  void _segarkan() {
    _ctl.muatUlang();
    ref.invalidate(userListProvider);
  }

  void _kabari(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  void _kabariGalat(Object e) {
    if (!mounted) return;
    _kabari(pesanGalatSa(AppLocalizations.of(context), e));
    if (perluMuatUlang(e)) _segarkan();
  }

  Future<void> _tambah() async {
    final berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PenggunaFormScreen()),
    );
    if (berhasil == true) _segarkan();
  }

  Future<void> _ubah(User akun) async {
    final berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PenggunaFormScreen(akun: akun)),
    );
    if (berhasil == true) {
      _segarkan();
      if (mounted) _kabari(AppLocalizations.of(context).saFormBerhasilUbah);
    }
  }

  Future<void> _setelSandi(User akun) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.saSetelJudul(akun.nama),
      isi: l10n.saSetelIsi,
      labelKolom: l10n.saSetelLabel,
      helper: l10n.saSetelHelper,
      labelAksi: l10n.saSetelAksi,
      sandi: true,
      potong: false,
      panjangMinimal: 8,
      panjangMaksimal: 255,
      pesanPendek: l10n.saSetelPendek,
      pesanPanjang: l10n.saSetelPendek,
      kunciGalatServer: 'password',
      aksi: (sandi) async => ref
          .read(penggunaSaServiceProvider)
          .setelUlangSandi(await _token(), akun.id, sandi),
      saatGalat: (e) {
        if (perluMuatUlang(e)) _segarkan();
      },
    );
    if (ok) _kabari(l10n.saSetelBerhasil(akun.nama));
  }

  Future<void> _nonaktifkan(User akun) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.saNonaktifJudul(akun.nama),
      isi: l10n.saNonaktifIsi,
      labelKolom: l10n.saAlasanWajib,
      catatan: l10n.saAlasanCatatan,
      labelAksi: l10n.saNonaktifAksi,
      destruktif: true,
      panjangMinimal: 3,
      pesanPendek: l10n.saAlasanPendek,
      pesanPanjang: l10n.saAlasanPanjang,
      aksi: (alasan) async => ref
          .read(penggunaSaServiceProvider)
          .nonaktifkan(await _token(), akun.id, alasan: alasan),
      saatGalat: (e) {
        if (perluMuatUlang(e)) _segarkan();
      },
    );
    if (ok) {
      _segarkan();
      _kabari(l10n.saNonaktifBerhasil);
    }
  }

  Future<void> _aktifkan(User akun) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.saAktifJudul(akun.nama),
      isi: l10n.saAktifIsi,
      labelKolom: l10n.saAlasanOpsional,
      catatan: l10n.saAlasanCatatan,
      labelAksi: l10n.saAktifAksi,
      wajib: false,
      pesanPanjang: l10n.saAlasanPanjang,
      aksi: (alasan) async => ref
          .read(penggunaSaServiceProvider)
          .aktifkan(
            await _token(),
            akun.id,
            alasan: alasan.isEmpty ? null : alasan,
          ),
      saatGalat: (e) {
        if (perluMuatUlang(e)) _segarkan();
      },
    );
    if (ok) {
      _segarkan();
      _kabari(l10n.saAktifBerhasil);
    }
  }

  Future<void> _setujui(User akun) async {
    final l10n = AppLocalizations.of(context);
    final peran = await showDialog<UserRole>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.saSetujuiJudul(akun.nama),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.saSetujuiIsi),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.saPeranAdminMasterData),
                onTap: () => Navigator.of(dialogContext).pop(UserRole.admin),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.saPeranTeknisi),
                onTap: () => Navigator.of(dialogContext).pop(UserRole.teknisi),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.saBatal),
          ),
        ],
      ),
    );
    if (peran == null) return;

    try {
      await ref
          .read(penggunaSaServiceProvider)
          .setujui(await _token(), akun.id, peran);
      _segarkan();
      _kabari(l10n.saSetujuiBerhasil);
    } catch (e) {
      _kabariGalat(e);
    }
  }

  Future<void> _tolak(User akun) async {
    final l10n = AppLocalizations.of(context);
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.saTolakJudul(akun.nama),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(child: Text(l10n.saTolakIsi)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.saBatal),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.saAksiTolak),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    try {
      await ref.read(penggunaSaServiceProvider).tolak(await _token(), akun.id);
      _segarkan();
      _kabari(l10n.saTolakBerhasil);
    } catch (e) {
      _kabariGalat(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehLihatPengguna;
    final bolehTambah = ref.bolehBuatAdmin || ref.bolehBuatTeknisi;
    final papanKetikTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saPenggunaJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin)
            : Column(
                children: [
                  Expanded(
                    child: ReadableWidth(
                      maksimum: 720,
                      child: _Daftar(
                        cari: _cari,
                        saatCari: _cariBerubah,
                        memuatLagi: _memuatLagi,
                        saatMuatLagi: _muatLagi,
                        saatUbah: _ubah,
                        saatSetelSandi: _setelSandi,
                        saatNonaktifkan: _nonaktifkan,
                        saatAktifkan: _aktifkan,
                        saatSetujui: _setujui,
                        saatTolak: _tolak,
                      ),
                    ),
                  ),
                  // Tombol tambah disembunyikan saat papan ketik terbuka: pakai
                  // pola layar Pelanggan (tombol di bawah), tapi jangan makan
                  // tinggi layar yang sudah sempit oleh papan ketik.
                  if (bolehTambah && !papanKetikTerbuka)
                    SafeArea(
                      top: false,
                      child: ReadableWidth(
                        maksimum: 720,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: AppButton(
                            label: l10n.saTambahPengguna,
                            icon: Icons.person_add_alt_1_outlined,
                            onPressed: _tambah,
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

class _Daftar extends ConsumerWidget {
  const _Daftar({
    required this.cari,
    required this.saatCari,
    required this.memuatLagi,
    required this.saatMuatLagi,
    required this.saatUbah,
    required this.saatSetelSandi,
    required this.saatNonaktifkan,
    required this.saatAktifkan,
    required this.saatSetujui,
    required this.saatTolak,
  });

  final TextEditingController cari;
  final ValueChanged<String> saatCari;
  final bool memuatLagi;
  final VoidCallback saatMuatLagi;
  final ValueChanged<User> saatUbah;
  final ValueChanged<User> saatSetelSandi;
  final ValueChanged<User> saatNonaktifkan;
  final ValueChanged<User> saatAktifkan;
  final ValueChanged<User> saatSetujui;
  final ValueChanged<User> saatTolak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(penggunaSaProvider);
    final ctl = ref.read(penggunaSaProvider.notifier);
    final data = async.value;

    // Satu `ListView.builder` MALAS untuk semua keadaan: kepala (cari +
    // saringan) selalu item 0, sisanya mengikuti keadaan data. Daftar ratusan
    // baris tidak membangun kartu di luar layar.
    final int isi;
    final Widget Function(BuildContext, int) bangunIsi;
    if (data != null && data.items.isNotEmpty) {
      isi = data.items.length + (data.adaLagi ? 1 : 0);
      bangunIsi = (context, i) {
        if (i == data.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: AppButton(
                label: l10n.saMuatLagi,
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                isLoading: memuatLagi,
                onPressed: saatMuatLagi,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _KartuPengguna(
            akun: data.items[i],
            saatUbah: saatUbah,
            saatSetelSandi: saatSetelSandi,
            saatNonaktifkan: saatNonaktifkan,
            saatAktifkan: saatAktifkan,
            saatSetujui: saatSetujui,
            saatTolak: saatTolak,
          ),
        );
      };
    } else if (data != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.people_outline,
          teks: l10n.saPenggunaKosong,
        ),
      );
    } else if (async.hasError) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 320,
        child: PesanLayar(
          ikon: Icons.cloud_off_outlined,
          galat: true,
          teks: async.error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.saPenggunaGagal,
          aksi: AppButton(
            label: l10n.saCobaLagi,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: ctl.muatUlang,
          ),
        ),
      );
    } else {
      isi = 4;
      bangunIsi = (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KerangkaKartu(),
      );
    }

    return RefreshIndicator(
      onRefresh: ctl.muatUlang,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: isi + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Kepala(cari: cari, saatCari: saatCari);
          }
          return bangunIsi(context, i - 1);
        },
      ),
    );
  }
}

class _Kepala extends ConsumerWidget {
  const _Kepala({required this.cari, required this.saatCari});

  final TextEditingController cari;
  final ValueChanged<String> saatCari;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Dibaca sekali per build; berubah bersama `penggunaSaProvider` (setiap
    // `saring` memasang `loading` lalu data), jadi chip ikut diperbarui.
    ref.watch(penggunaSaProvider);
    final ctl = ref.read(penggunaSaProvider.notifier);
    final f = ctl.filter;

    Widget baris(
      List<(String?, String)> pilihan,
      String? aktif,
      void Function(String?) pilih,
    ) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (nilai, label) in pilihan)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: Text(label),
                  selected: aktif == nilai,
                  onSelected: (_) => pilih(nilai),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.saPenggunaCari,
            child: TextField(
              key: const Key('cari-pengguna'),
              controller: cari,
              onChanged: saatCari,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.saPenggunaCari,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          baris(
            [
              (null, l10n.saPeranSemua),
              ('admin', l10n.saPeranAdmin),
              ('teknisi', l10n.saPeranTeknisi),
              ('viewer', l10n.saPeranViewer),
            ],
            f.peran,
            (nilai) => ctl.saring(f.salin(peran: nilai)),
          ),
          baris(
            [
              (null, l10n.teknisiFilterSemua),
              ('pending', l10n.teknisiFilterPending),
              ('aktif', l10n.teknisiFilterAktif),
              ('nonaktif', l10n.teknisiFilterNonaktif),
            ],
            f.status,
            (nilai) => ctl.saring(f.salin(status: nilai)),
          ),
        ],
      ),
    );
  }
}

class _KartuPengguna extends ConsumerWidget {
  const _KartuPengguna({
    required this.akun,
    required this.saatUbah,
    required this.saatSetelSandi,
    required this.saatNonaktifkan,
    required this.saatAktifkan,
    required this.saatSetujui,
    required this.saatTolak,
  });

  final User akun;
  final ValueChanged<User> saatUbah;
  final ValueChanged<User> saatSetelSandi;
  final ValueChanged<User> saatNonaktifkan;
  final ValueChanged<User> saatAktifkan;
  final ValueChanged<User> saatSetujui;
  final ValueChanged<User> saatTolak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final diriSendiri = ref.watch(authProvider).value?.id == akun.id;

    final pending = akun.status == UserStatus.pending;
    final aktif = akun.status == UserStatus.aktif;
    final nonaktif = akun.status == UserStatus.nonaktif;

    // Menu ⋮ hanya memuat aksi yang BOLEH untuk akun ini. Akun sendiri tidak
    // bisa dinonaktifkan/disetel-ulang dari sini (pakai Ganti sandi).
    final menu = <(String, String)>[
      ('ubah', l10n.saAksiUbah),
      if (aktif && !diriSendiri) ('sandi', l10n.saAksiSetelSandi),
      if (aktif && !diriSendiri && ref.bolehUbahStatusPengguna)
        ('nonaktifkan', l10n.saAksiNonaktifkan),
      if (nonaktif && ref.bolehUbahStatusPengguna)
        ('aktifkan', l10n.saAksiAktifkan),
    ];

    void pilih(String kode) {
      switch (kode) {
        case 'ubah':
          saatUbah(akun);
        case 'sandi':
          saatSetelSandi(akun);
        case 'nonaktifkan':
          saatNonaktifkan(akun);
        case 'aktifkan':
          saatAktifkan(akun);
      }
    }

    final namaTampil = akun.nama.trim().isEmpty ? akun.email : akun.nama;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tema.colorScheme.secondaryContainer,
                    ),
                    child: Text(
                      inisialNama(namaTampil),
                      style: tema.textTheme.labelLarge?.copyWith(
                        color: tema.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaTampil,
                        style: tema.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        akun.email,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          akun.employeeId.isEmpty
                              ? l10n.teknisiTanpaEmployeeId
                              : akun.employeeId,
                          if ((akun.department ?? '').trim().isNotEmpty)
                            akun.department!.trim(),
                        ].join(' · '),
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (menu.isNotEmpty)
                  PopupMenuButton<String>(
                    key: Key('menu-${akun.id}'),
                    tooltip: l10n.saAksiUntuk(namaTampil),
                    icon: const Icon(Icons.more_vert),
                    onSelected: pilih,
                    itemBuilder: (_) => [
                      for (final (kode, label) in menu)
                        PopupMenuItem<String>(value: kode, child: Text(label)),
                    ],
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusBadge(
                    label: akun.status.label,
                    tone: switch (akun.status) {
                      UserStatus.aktif => BadgeTone.success,
                      UserStatus.pending => BadgeTone.warning,
                      UserStatus.nonaktif => BadgeTone.neutral,
                    },
                    icon: switch (akun.status) {
                      UserStatus.aktif => Icons.check_circle_outline,
                      UserStatus.pending => Icons.hourglass_empty,
                      UserStatus.nonaktif => Icons.block_outlined,
                    },
                  ),
                  StatusBadge(
                    label: akun.role.label,
                    tone: akun.role.isAdmin
                        ? BadgeTone.info
                        : BadgeTone.neutral,
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
            ),
            if (pending && ref.bolehSetujuiPengguna) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _TombolBernama(
                    teks: l10n.saAksiSetujui,
                    nama: namaTampil,
                    ikon: Icons.check,
                    saatTekan: () => saatSetujui(akun),
                  ),
                  _TombolBernama(
                    teks: l10n.saAksiTolak,
                    nama: namaTampil,
                    ikon: Icons.block_outlined,
                    sekunder: true,
                    saatTekan: () => saatTolak(akun),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tombol kartu yang di pembaca layar terbaca "Setujui Dedi", bukan "Setujui"
/// saja — di daftar dua pendaftar tombolnya persis sama tanpa nama.
class _TombolBernama extends StatelessWidget {
  const _TombolBernama({
    required this.teks,
    required this.nama,
    required this.ikon,
    required this.saatTekan,
    this.sekunder = false,
  });

  final String teks;
  final String nama;
  final IconData ikon;
  final VoidCallback saatTekan;
  final bool sekunder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$teks $nama',
      onTap: saatTekan,
      excludeSemantics: true,
      child: AppButton(
        label: teks,
        ringkas: true,
        icon: ikon,
        variant: sekunder
            ? AppButtonVariant.secondary
            : AppButtonVariant.primary,
        onPressed: saatTekan,
      ),
    );
  }
}

class _KerangkaKartu extends StatelessWidget {
  const _KerangkaKartu();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 16, width: 160),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 220),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 100),
          ],
        ),
      ),
    );
  }
}
