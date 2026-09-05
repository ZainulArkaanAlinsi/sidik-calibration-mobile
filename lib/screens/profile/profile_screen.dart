import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/inisial_nama.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/versi_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/platform_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/status_badge.dart';
import '../arsip/arsip_screen.dart';
import '../design_system/design_system_screen.dart';
import '../settings/customer_list_screen.dart';
import '../settings/organization_screen.dart';
import '../settings/tanda_tangan_screen.dart';
import '../settings/metode_list_screen.dart';
import '../settings/ruangan_list_screen.dart';
import '../settings/rumus_list_screen.dart';
import '../settings/standard_list_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _sedangCabutSemua = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final user = ref.watch(authProvider).value;
    final sedangLogout = ref.watch(authProvider).isLoading;
    final panelDesktop = ref.watch(pakaiPanelDesktopProvider);

    return Scaffold(
      // Foto hero header harus nyampe ke tepi paling atas layar (nggak ada
      // judul "Profil" mengambang di atasnya — acuan desainnya juga gitu).
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Di HP, profil adalah kumpulan scene satu layar. Pengguna geser
          // samping untuk pindah kelompok, bukan menggulir halaman panjang.
          if (constraints.maxWidth < 700 && user != null) {
            return _MobileProfileCarousel(
              user: user,
              apiBaseUrl: apiBaseUrl,
              sedangLogout: sedangLogout,
              sedangCabutSemua: _sedangCabutSemua,
              onEditFoto: _pilihFoto,
              onCabutSemua: _cabutSemuaSesi,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            );
          }

          return ReadableWidth(
            child: ListView(
              // Padding bawah lega biar item terakhir nggak ketutup bottom-nav
              // yang mengambang. Top sengaja 0 — header foto harus full-bleed.
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                if (user != null) ...[
                  _Header(user: user, onEditFoto: _pilihFoto),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Menu master data cuma muncul di HP.
                //
                // Di panel desktop, Pelanggan/Standar/Organisasi/Tanda Tangan/Arsip
                // semuanya UDAH jadi item sidebar sendiri — nampilinnya lagi di
                // sini bikin admin lihat tujuan yang sama dua kali, dan Pengaturan
                // jadi cuma salinan navigasi utama. Yang tersisa di layar ini
                // preferensi & diagnosa: hal-hal yang emang nggak ada di sidebar.
                //
                // Di HP nggak ada sidebar, jadi di situ blok ini SATU-SATUNYA jalan
                // ke master data dan tetap dipertahankan.
                if (user != null && user.role.isAdmin && !panelDesktop) ...[
                  _JudulSeksi(l10n.profAdminMenu),
                  _KartuMenu(
                    children: [
                      _BarisMenu(
                        icon: Icons.group_outlined,
                        title: l10n.profUserManagement,
                        subtitle: l10n.profUserManagementSub,
                        enabled: false,
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.apartment_outlined,
                        title: l10n.profOrgData,
                        subtitle: l10n.profOrgDataSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const OrganizationScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      // Ditaruh nempel sama Data Organisasi, bukan di kelompok
                      // lain: dua-duanya nyetel apa yang KECETAK di sertifikat,
                      // dan admin nyarinya di tempat yang sama.
                      _BarisMenu(
                        icon: Icons.draw_outlined,
                        title: l10n.profTandaTangan,
                        subtitle: l10n.profTandaTanganSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TandaTanganScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.people_outline,
                        title: l10n.profCustomers,
                        subtitle: l10n.profCustomersSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CustomerListScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.straighten_outlined,
                        title: l10n.profStandards,
                        subtitle: l10n.profStandardsSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const StandardListScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.functions_outlined,
                        title: l10n.profRumus,
                        subtitle: l10n.profRumusSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RumusListScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.meeting_room_outlined,
                        title: l10n.profRuangan,
                        subtitle: l10n.profRuanganSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RuanganListScreen(),
                          ),
                        ),
                      ),
                      const _GarisPemisah(),
                      _BarisMenu(
                        icon: Icons.menu_book_outlined,
                        title: l10n.profMetode,
                        subtitle: l10n.profMetodeSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MetodeListScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Preferensi: milik SATU ORANG, bukan milik lab. Tema & bahasa
                // nggak pernah jadi item sidebar karena bukan tujuan navigasi —
                // jadi ini isi Pengaturan yang nggak mungkin duplikat.
                _JudulSeksi(l10n.profPreferensi),
                const _KartuMenu(
                  children: [_PilihTema(), _GarisPemisah(), _PilihBahasa()],
                ),
                const SizedBox(height: AppSpacing.lg),

                _KartuMenu(
                  children: [
                    // Di luar blok admin: arsip itu baca-baca hasil kerja, dan
                    // backend ngizinin semua role (berkasnya sendiri tetap disaring
                    // per-teknisi di server).
                    _BarisMenu(
                      icon: Icons.folder_copy_outlined,
                      title: l10n.profArsip,
                      subtitle: l10n.profArsipSub,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ArsipScreen(),
                        ),
                      ),
                    ),
                    const _GarisPemisah(),
                    _BarisMenu(
                      icon: Icons.palette_outlined,
                      title: l10n.profDesignSystem,
                      subtitle: l10n.profDesignSystemSub,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DesignSystemScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _JudulSeksi(l10n.profAppInfo),
                _KartuMenu(
                  children: [
                    _BarisMenu(
                      icon: Icons.layers_outlined,
                      title: l10n.profEnvironment,
                      subtitle: AppConfig.envLabel,
                      showChevron: false,
                    ),
                    const _GarisPemisah(),
                    _BarisMenu(
                      icon: Icons.cloud_outlined,
                      title: l10n.profApiBaseUrl,
                      subtitle: apiBaseUrl,
                      showChevron: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _JudulSeksi(l10n.profSecurity),
                _KartuMenu(
                  children: [
                    _BarisMenu(
                      icon: Icons.phonelink_erase_outlined,
                      iconColor: theme.colorScheme.error,
                      title: l10n.profLogoutAll,
                      subtitle: l10n.profLogoutAllSub,
                      trailing: _sedangCabutSemua
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _sedangCabutSemua ? null : _cabutSemuaSesi,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: AppButton(
                    label: l10n.profLogout,
                    icon: Icons.logout,
                    variant: AppButtonVariant.secondary,
                    isLoading: sedangLogout,
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pilihFoto() {
    final l10n = AppLocalizations.of(context);
    final adaFoto = ref.read(avatarPathProvider) != null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.profChangePhotoSheet,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profChooseGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _ambilFoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profTakePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _ambilFoto(ImageSource.camera);
              },
            ),
            if (adaFoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(l10n.profRemovePhoto),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _hapusFoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ambilFoto(ImageSource sumber) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: sumber,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      await ref.read(avatarPathProvider.notifier).setPath(file.path);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoUpdated)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoFailed)));
    }
  }

  Future<void> _hapusFoto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(avatarPathProvider.notifier).setPath(null);
    messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoRemoved)));
  }

  Future<void> _cabutSemuaSesi() async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profLogoutAllConfirmTitle),
        content: Text(l10n.profLogoutAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profRevokeAll),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sedangCabutSemua = true);

    try {
      final dicabut = await ref.read(authProvider.notifier).logoutAll();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            dicabut > 0
                ? l10n.profSessionsRevoked(dicabut)
                : l10n.profAllSessionsRevoked,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _sedangCabutSemua = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profRevokeFailed(e.message))),
      );
    }
  }
}

/// Profil versi HP: **satu bagian = satu layar penuh**, pindahnya digeser ke
/// samping.
///
/// Kenapa nggak digulung ke bawah kayak biasanya:
///
/// - Daftar pengaturan yang panjang bikin orang lupa udah lihat apa. Dipecah
///   jadi bagian yang tiap-tiapnya muat sekali lihat, nggak ada yang
///   kesembunyi di bawah lipatan.
/// - Tingginya diambil dari layar HP-nya sendiri lewat `LayoutBuilder`, bukan
///   angka mati. HP pendek dapat jarak lebih rapat, HP jangkung dapat lebih
///   lega — dua-duanya tetap pas satu layar tanpa scroll.
///
/// Kacanya ([LiquidGlass]) sapuan cahayanya diikat ke posisi geseran, jadi pas
/// jari gerak, panelnya kelihatan mantulin cahaya — bukan cuma pindah tempat.
class _MobileProfileCarousel extends StatefulWidget {
  const _MobileProfileCarousel({
    required this.user,
    required this.apiBaseUrl,
    required this.sedangLogout,
    required this.sedangCabutSemua,
    required this.onEditFoto,
    required this.onCabutSemua,
    required this.onLogout,
  });

  final User user;
  final String apiBaseUrl;
  final bool sedangLogout;
  final bool sedangCabutSemua;
  final VoidCallback onEditFoto;
  final VoidCallback onCabutSemua;
  final VoidCallback onLogout;

  @override
  State<_MobileProfileCarousel> createState() => _MobileProfileCarouselState();
}

class _MobileProfileCarouselState extends State<_MobileProfileCarousel> {
  final _page = PageController();
  double _posisi = 0;

  @override
  void initState() {
    super.initState();
    // Dipantau terus, bukan cuma waktu halaman kelepas: sapuan cahaya di kaca
    // dan geser paralaks isinya diikat ke angka ini.
    _page.addListener(() {
      final p = _page.page;
      if (p != null && p != _posisi) setState(() => _posisi = p);
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final admin = widget.user.role.isAdmin;

    final bagian = <_Bagian>[
      _Bagian(
        label: l10n.profSectionAccount,
        bangun: (context, jarak) => _AdeganIdentitas(
          user: widget.user,
          onEditFoto: widget.onEditFoto,
          jarak: jarak,
        ),
      ),
      _Bagian(
        label: l10n.profPreferensi,
        bangun: (context, jarak) =>
            _AdeganPreferensi(user: widget.user, jarak: jarak),
      ),
      if (admin)
        _Bagian(
          label: l10n.profAdminMenu,
          bangun: (context, jarak) => _AdeganPintasan(
            eyebrow: l10n.profSectionWorkspace,
            judul: l10n.profAdminMenu,
            subjudul: l10n.profAdminMenuSub,
            jarak: jarak,
            item: [
              _Pintasan(
                Icons.apartment_outlined,
                l10n.profOrgData,
                l10n.profOrgDataSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OrganizationScreen(),
                  ),
                ),
              ),
              _Pintasan(
                Icons.draw_outlined,
                l10n.profTandaTangan,
                l10n.profTandaTanganSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TandaTanganScreen(),
                  ),
                ),
              ),
              _Pintasan(
                Icons.people_outline,
                l10n.profCustomers,
                l10n.profCustomersSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerListScreen(),
                  ),
                ),
              ),
              _Pintasan(
                Icons.straighten_outlined,
                l10n.profStandards,
                l10n.profStandardsSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StandardListScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      if (admin)
        _Bagian(
          label: l10n.profLabSettings,
          bangun: (context, jarak) => _AdeganPintasan(
            eyebrow: l10n.profSectionWorkspace,
            judul: l10n.profLabSettings,
            subjudul: l10n.profLabSettingsSub,
            jarak: jarak,
            item: [
              _Pintasan(
                Icons.functions_outlined,
                l10n.profRumus,
                l10n.profRumusSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RumusListScreen(),
                  ),
                ),
              ),
              _Pintasan(
                Icons.meeting_room_outlined,
                l10n.profRuangan,
                l10n.profRuanganSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RuanganListScreen(),
                  ),
                ),
              ),
              _Pintasan(
                Icons.menu_book_outlined,
                l10n.profMetode,
                l10n.profMetodeSub,
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MetodeListScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      _Bagian(
        label: l10n.profSecurity,
        bangun: (context, jarak) => _AdeganSistem(
          apiBaseUrl: widget.apiBaseUrl,
          sedangLogout: widget.sedangLogout,
          sedangCabutSemua: widget.sedangCabutSemua,
          onCabutSemua: widget.onCabutSemua,
          onLogout: widget.onLogout,
          jarak: jarak,
        ),
      ),
    ];

    final aktif = _posisi.round().clamp(0, bagian.length - 1);

    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.warnaLatar(context)),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: bagian.length,
              itemBuilder: (context, i) =>
                  bagian[i].bangun(context, (_posisi - i).clamp(-1.0, 1.0)),
            ),
          ),
          _KakiCarousel(
            posisi: _posisi,
            jumlah: bagian.length,
            label: bagian[aktif].label,
            petunjuk: l10n.profSwipeHint,
          ),
        ],
      ),
    );
  }
}

class _Bagian {
  const _Bagian({required this.label, required this.bangun});

  final String label;
  final Widget Function(BuildContext context, double jarak) bangun;
}

/// Bilah kaki yang tetap: titik halaman + nama bagian + petunjuk geser.
///
/// Ditaruh di luar PageView, bukan di dalam tiap adegan, biar dia nggak ikut
/// geser — jadi dia kebaca sebagai penunjuk posisi, bukan bagian dari isi.
class _KakiCarousel extends StatelessWidget {
  const _KakiCarousel({
    required this.posisi,
    required this.jumlah,
    required this.label,
    required this.petunjuk,
  });

  final double posisi;
  final int jumlah;
  final String label;
  final String petunjuk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final munculHint = posisi < 0.6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Row(
            children: List.generate(jumlah, (i) {
              // Lebarnya ikut posisi pecahan — titiknya meleleh pelan ke titik
              // sebelah selama jari masih nempel, bukan lompat pas kelepas.
              final dekat = (1 - (posisi - i).abs()).clamp(0.0, 1.0);
              return Container(
                height: 5,
                width: 5 + 16 * dekat,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    // Bukan `outlineVariant`: di latar terang warnanya nyaris
                    // nyatu sama gradasi, jadi titik yang belum kepilih
                    // kelihatan kayak nggak ada.
                    theme.colorScheme.outline.withValues(alpha: 0.45),
                    theme.colorScheme.primary,
                    dekat,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(width: AppSpacing.md),
          // Petunjuk gesernya cuma nongol di bagian pertama (label-nya masih
          // pendek, "Akun"/"Preferensi") — begitu ilang, nama bagian yang
          // bisa panjang ("Pengaturan Lab", dst) butuh SEMUA sisa baris buat
          // ellipsis-nya sendiri. Makanya `Expanded` cuma dipasang pas hint
          // nggak ada: dua widget flex sama-sama di baris ini bakal dibagi
          // rata SETENGAH-SETENGAH oleh Flutter walaupun labelnya cuma
          // "Akun" — hint-nya jadi kepotong padahal ruangnya sebenarnya
          // cukup (kejadian 18 Agt 2026, golden `profil.png` ketangkep).
          munculHint
              ? Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          // Satu-satunya flex child di baris ini pas dia nongol (lihat
          // komentar di atas) — jadi dia kebagian SEMUA sisa ruang, bukan
          // separuh. `Flexible`, bukan `Expanded`: pas jari lagi di antara
          // dua titik, DUA titik sekaligus melar — total lebar dots di frame
          // itu lebih gede dari frame diam manapun, jadi tetap butuh
          // ellipsis buat frame transisi yang paling sempit.
          if (munculHint) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swipe_left_alt_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      petunjuk,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bingkai isi tiap adegan: judul kecil + judul besar + keterangan, terus
/// sisanya diserahkan ke isi.
///
/// Tinggi jarak-jaraknya diambil dari tinggi yang beneran tersedia, jadi
/// bagian ini pas di layar HP mana pun tanpa pernah butuh scroll.
class _Bingkai extends StatelessWidget {
  const _Bingkai({
    required this.eyebrow,
    required this.judul,
    required this.subjudul,
    required this.jarak,
    required this.child,
  });

  final String eyebrow;
  final String judul;
  final String subjudul;

  /// -1..1, jarak halaman ini dari tengah layar. Dipakai buat paralaks.
  final double jarak;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, batas) {
        // Rapat di HP pendek, lega di HP jangkung. Acuannya 720 — tinggi isi
        // di HP 6 inci sesudah dipotong bilah atas & navbar bawah.
        final rapat = (batas.maxHeight / 720).clamp(0.82, 1.16);
        final atas = MediaQuery.paddingOf(context).top + 12 * rapat;

        return Padding(
          padding: EdgeInsets.only(top: atas, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                // Judul jalan lebih jauh dari kartunya — lapisannya jadi
                // kebaca punya kedalaman waktu digeser.
                offset: Offset(jarak * -54, 0),
                child: Opacity(
                  opacity: (1 - jarak.abs()).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.cobalt,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              eyebrow,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8 * rapat),
                        Text(
                          judul,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4 * rapat),
                        Text(
                          subjudul,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18 * rapat),
              Expanded(
                child: Transform.translate(
                  offset: Offset(jarak * -22, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Adegan 1 — identitas. Satu-satunya adegan yang full-bleed sampai tepi
/// layar: foto hero-nya emang harus nyampe di bawah status bar.
class _AdeganIdentitas extends StatelessWidget {
  const _AdeganIdentitas({
    required this.user,
    required this.onEditFoto,
    required this.jarak,
  });

  final User user;
  final VoidCallback onEditFoto;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, batas) {
        return Column(
          children: [
            _Header(
              user: user,
              onEditFoto: onEditFoto,
              // Foto hero ikut tinggi layar, bukan 260 mati: di HP pendek dia
              // makan lebih dari sepertiga layar dan ngedorong panelnya keluar.
              tinggiFoto: (batas.maxHeight * 0.33).clamp(170.0, 260.0),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Transform.translate(
                offset: Offset(jarak * -34, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  // `SingleChildScrollView`, bukan `Column` + `Spacer`: di
                  // HP tinggi normal isinya nggak nyampe separuh ruang jadi
                  // dia diam kayak biasa, nggak kelihatan scrollable sama
                  // sekali. Tapi begitu kartunya kepepet (HP super pendek,
                  // atau kode teknisi bikin barisnya jadi tiga), dia ngalah
                  // geser dikit — bukan overflow merah nabrak tepi layar.
                  child: SingleChildScrollView(
                    child: LiquidGlass(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BarisMenu(
                            icon: Icons.photo_camera_outlined,
                            title: l10n.profChangePhoto,
                            subtitle: l10n.profChangePhotoSub,
                            onTap: onEditFoto,
                          ),
                          // Kode teknisi cuma dirender kalau backend
                          // ngirimnya. Baris "Kode teknisi: —" nggak ngasih
                          // tau apa-apa selain bahwa ada yang kosong.
                          if ((user.kodeTeknisi ?? '').isNotEmpty) ...[
                            const _GarisPemisah(),
                            _BarisMenu(
                              icon: Icons.tag,
                              title: l10n.profTechnicianCode,
                              subtitle: l10n.profTechnicianCodeSub,
                              trailing: Text(
                                user.kodeTeknisi!,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(letterSpacing: 1.4),
                              ),
                              showChevron: false,
                            ),
                          ],
                          const _GarisPemisah(),
                          _BarisMenu(
                            icon: Icons.badge_outlined,
                            title: l10n.profAccountInfo,
                            subtitle: user.email,
                            showChevron: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Adegan 2 — preferensi perangkat.
class _AdeganPreferensi extends StatelessWidget {
  const _AdeganPreferensi({required this.user, required this.jarak});

  final User user;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Bingkai(
      eyebrow: user.role.label.toUpperCase(),
      judul: l10n.profPreferensi,
      subjudul: l10n.profPreferensiSub,
      jarak: jarak,
      child: Column(
        children: [
          // Dua spacer nggak seimbang: kartunya duduk agak di atas tengah,
          // bukan nempel di kepala judul. Ruang sisanya jadi napas, bukan
          // lubang di bawah layar.
          const Spacer(flex: 1),
          _KacaKartu(
            child: const Column(
              children: [_PilihTema(), _GarisPemisah(), _PilihBahasa()],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _KacaKartu(
            child: Column(
              children: [
                _BarisMenu(
                  icon: Icons.folder_copy_outlined,
                  title: l10n.profArsip,
                  subtitle: l10n.profArsipSub,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ArsipScreen(),
                    ),
                  ),
                ),
                const _GarisPemisah(),
                _BarisMenu(
                  icon: Icons.palette_outlined,
                  title: l10n.profDesignSystem,
                  subtitle: l10n.profDesignSystemSub,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DesignSystemScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

/// Adegan pintasan — petak kartu. Perbandingan sisi kartunya dihitung dari
/// ruang yang tersisa, jadi empat kartu SELALU muat tanpa scroll, baik di HP
/// pendek maupun jangkung.
class _AdeganPintasan extends StatelessWidget {
  const _AdeganPintasan({
    required this.eyebrow,
    required this.judul,
    required this.subjudul,
    required this.item,
    required this.jarak,
  });

  final String eyebrow;
  final String judul;
  final String subjudul;
  final List<_Pintasan> item;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    return _Bingkai(
      eyebrow: eyebrow,
      judul: judul,
      subjudul: subjudul,
      jarak: jarak,
      child: LayoutBuilder(
        builder: (context, batas) {
          const jeda = AppSpacing.sm;
          final baris = (item.length / 2).ceil();
          final lebarKartu = (batas.maxWidth - jeda) / 2;

          // Kartu boleh manjang buat ngisi layar, TAPI ada batasnya: kartu
          // yang tingginya lebih dari 1,15x lebarnya isinya jadi ngambang di
          // tengah kolom kosong. Sisa ruangnya dibiarin jadi napas di bawah,
          // bukan dipaksa ditelen kartu.
          final muat = (batas.maxHeight - jeda * (baris - 1)) / baris;
          final tinggiKartu = muat.clamp(96.0, lebarKartu * 1.15);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: tinggiKartu * baris + jeda * (baris - 1),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: item.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: jeda,
                  crossAxisSpacing: jeda,
                  childAspectRatio: lebarKartu / tinggiKartu,
                ),
                itemBuilder: (context, i) => _KartuPintasan(item: item[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Adegan terakhir — status sistem & akses akun.
class _AdeganSistem extends StatelessWidget {
  const _AdeganSistem({
    required this.apiBaseUrl,
    required this.sedangLogout,
    required this.sedangCabutSemua,
    required this.onCabutSemua,
    required this.onLogout,
    required this.jarak,
  });

  final String apiBaseUrl;
  final bool sedangLogout;
  final bool sedangCabutSemua;
  final VoidCallback onCabutSemua;
  final VoidCallback onLogout;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _Bingkai(
      eyebrow: l10n.profSectionSystem,
      judul: l10n.profSecurity,
      subjudul: l10n.profSecuritySub,
      jarak: jarak,
      child: Column(
        children: [
          _KacaKartu(
            child: Column(
              children: [
                _BarisMenu(
                  icon: Icons.layers_outlined,
                  title: l10n.profEnvironment,
                  subtitle: AppConfig.envLabel,
                  showChevron: false,
                ),
                const _GarisPemisah(),
                _BarisMenu(
                  icon: Icons.cloud_outlined,
                  title: l10n.profApiBaseUrl,
                  subtitle: apiBaseUrl,
                  showChevron: false,
                ),
                const _GarisPemisah(),
                _BarisMenu(
                  icon: Icons.phonelink_erase_outlined,
                  iconColor: theme.colorScheme.error,
                  title: l10n.profLogoutAll,
                  subtitle: l10n.profLogoutAllSub,
                  trailing: sedangCabutSemua
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: sedangCabutSemua ? null : onCabutSemua,
                ),
              ],
            ),
          ),
          const Spacer(),
          const _BarisVersi(),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.profLogout,
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            isLoading: sedangLogout,
            onPressed: onLogout,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Versi & nomor build yang TERPASANG di HP ini.
///
/// Kecil dan di pojok, tapi bukan hiasan: sampai sebelum ada baris ini,
/// pertanyaan "punyaku versi berapa" cuma bisa dijawab dari catatan rilis App
/// Distribution — yang kelihatan SEBELUM dipasang, bukan sesudah. Waktu
/// teknisi lapor "punyaku masih yang lama", tidak ada satu pun angka di
/// layarnya yang bisa diadu.
///
/// Gagal membacanya tidak menampilkan apa-apa, bukan pesan error: yang rusak
/// cuma label informatif, dan menaruh error merah di bawah tombol Keluar
/// bikin teknisi mengira akunnya bermasalah.
class _BarisVersi extends ConsumerWidget {
  const _BarisVersi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ref
        .watch(versiTerpasangProvider)
        .maybeWhen(
          data: (versi) => Text(
            versi,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        );
  }
}

/// Kartu kaca pembungkus baris-baris menu.
class _KacaKartu extends StatelessWidget {
  const _KacaKartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

class _Pintasan {
  const _Pintasan(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _KartuPintasan extends StatelessWidget {
  const _KartuPintasan({required this.item});

  final _Pintasan item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiquidGlass(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: item.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IkonPetak(icon: item.icon),
          const Spacer(),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul kecil di atas tiap seksi.
class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        teks.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Header profil ala kartu acuan "Tom Chen": foto hero *full-bleed*, avatar
/// rata kiri numpuk di sambungan foto↔panel putih, nama+email rata kiri,
/// terus baris statistik 3 kolom (ID Pegawai / Departemen / Role).
class _Header extends ConsumerWidget {
  const _Header({
    required this.user,
    required this.onEditFoto,
    this.tinggiFoto = 260.0,
  });

  /// Tinggi foto hero. Bisa disetel karena di HP pendek angka mati 260
  /// makan lebih dari sepertiga layar dan ngedorong panel identitasnya keluar.
  final double tinggiFoto;

  static const _avatar = 96.0;
  static const _overlap =
      _avatar / 2; // separuh nongol di foto, separuh di panel

  final User user;
  final VoidCallback onEditFoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fotoPath = ref.watch(avatarPathProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // Foto hero — nyampe tepi layar, disambung `extendBodyBehindAppBar`
            // di Scaffold biar nembus sampai di bawah status bar.
            Container(
              height: tinggiFoto,
              width: double.infinity,
              decoration: BoxDecoration(
                // Tanpa foto: bidang Cobalt rata. Sempat Jet Black, dan sebidang
                // hitam setinggi ini di atas layar kebaca kayak gambar yang
                // gagal muat — cobalt kebaca sebagai bidang merek yang memang
                // disengaja.
                color: fotoPath == null ? AppColors.cobalt : null,
                image: fotoPath != null
                    ? DecorationImage(
                        image: FileImage(File(fotoPath)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.30),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
            ),
            // Panel putih nutupin bagian bawah foto, sudut atas membulat —
            // kesan "sheet" yang numpuk di atas foto.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                _overlap + AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          user.nama,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(
                        label: user.status.label,
                        tone: switch (user.status) {
                          UserStatus.aktif => BadgeTone.success,
                          UserStatus.pending => BadgeTone.warning,
                          UserStatus.nonaktif => BadgeTone.neutral,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _BarisStatistik(
                    employeeId: user.employeeId,
                    department: user.department ?? '—',
                    roleLabel: user.role.label,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Avatar numpuk pas di sambungan foto <-> panel, rata kiri.
        Positioned(
          top: tinggiFoto - _overlap,
          left: AppSpacing.lg,
          child: _Avatar(
            size: _avatar,
            fotoPath: fotoPath,
            // Satu huruf, sama kayak sebelumnya — yang berubah cuma nama
            // kosong nggak lagi nglempar `StateError` dari `characters.first`.
            inisial: inisialNama(user.nama, maks: 1),
            onTap: onEditFoto,
          ),
        ),
      ],
    );
  }
}

/// Baris statistik 3 kolom ala acuan (Article/Views/Followers) — di sini
/// diisi data asli yang app punya, bukan angka karangan.
class _BarisStatistik extends StatelessWidget {
  const _BarisStatistik({
    required this.employeeId,
    required this.department,
    required this.roleLabel,
    required this.l10n,
  });

  final String employeeId;
  final String department;
  final String roleLabel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Statistik(
            label: l10n.employeeIdLabel,
            // Kosong = akun lama dari sebelum kolomnya diwajibkan. Ditulis
            // apa adanya, bukan dibiarkan jadi kotak kosong yang kebaca
            // seperti layar gagal muat. Padanan yang sama sudah dipakai di
            // `technician_list_screen`.
            nilai: employeeId.isEmpty ? l10n.teknisiTanpaEmployeeId : employeeId,
          ),
        ),
        const _PemisahVertikal(),
        Expanded(
          child: _Statistik(label: l10n.departmentLabel, nilai: department),
        ),
        const _PemisahVertikal(),
        Expanded(
          child: _Statistik(label: l10n.profRoleLabel, nilai: roleLabel),
        ),
      ],
    );
  }
}

class _Statistik extends StatelessWidget {
  const _Statistik({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          nilai,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _PemisahVertikal extends StatelessWidget {
  const _PemisahVertikal();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        width: AppSpacing.md,
        thickness: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.size,
    required this.fotoPath,
    required this.inisial,
    required this.onTap,
  });

  final double size;
  final String? fotoPath;
  final String inisial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = theme.scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cincin buat misahin avatar dari banner.
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ring,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: fotoPath != null
                    ? FileImage(File(fotoPath!))
                    : null,
                child: fotoPath == null
                    ? Text(
                        inisial,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
            // Badge kamera.
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ink,
                  border: Border.all(color: ring, width: 2.5),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu putih membulat dengan bayangan halus — wadah semua baris.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GlassSurface.rata(
        radius: 22,
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class _KartuMenu extends StatelessWidget {
  const _KartuMenu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Kartu(child: Column(children: children));
  }
}

/// Pilih tema terang/gelap/ikut sistem.
///
/// Ditaruh di Pengaturan, bukan cuma sakelar di bilah atas panel desktop:
/// di HP nggak ada bilah itu sama sekali, jadi sebelumnya pengguna HP nggak
/// punya jalan buat ngubah tema.
class _PilihTema extends ConsumerWidget {
  const _PilihTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);

    return _BarisPilihan(
      icon: Icons.brightness_6_outlined,
      judul: l10n.profTema,
      nilai: switch (mode) {
        ThemeMode.light => l10n.profTemaTerang,
        ThemeMode.dark => l10n.profTemaGelap,
        ThemeMode.system => l10n.profTemaSistem,
      },
      kontrol: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            icon: const Icon(Icons.light_mode_outlined),
            tooltip: l10n.profTemaTerang,
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: const Icon(Icons.dark_mode_outlined),
            tooltip: l10n.profTemaGelap,
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: const Icon(Icons.brightness_auto_outlined),
            tooltip: l10n.profTemaSistem,
          ),
        ],
        selected: {mode},
        onSelectionChanged: (p) =>
            ref.read(themeModeProvider.notifier).setMode(p.first),
      ),
    );
  }
}

/// Pilih bahasa. Dua-duanya disebut pakai nama bahasanya sendiri
/// ("Indonesia" / "English"), bukan diterjemahin — orang yang lagi kesasar di
/// bahasa yang salah tetap bisa nemu jalan pulang.
class _PilihBahasa extends ConsumerWidget {
  const _PilihBahasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return _BarisPilihan(
      icon: Icons.translate,
      judul: l10n.profBahasa,
      nilai: locale.languageCode == 'en' ? 'English' : 'Indonesia',
      kontrol: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'id', label: Text('Indonesia')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {locale.languageCode},
        onSelectionChanged: (p) =>
            ref.read(localeProvider.notifier).setLocale(Locale(p.first)),
      ),
    );
  }
}

/// Baris pengaturan yang punya kontrol lebar: label di atas, kontrolnya
/// sebaris penuh di bawah.
///
/// Dulu ini `ListTile` dengan `SegmentedButton` di `trailing`. Di lebar HP
/// kontrolnya makan lebih dari separuh baris, dan judulnya kepaksa ngelipat
/// sampai "Bahasa" kepotong jadi "Baha / sa". Kontrol selebar baris juga
/// bikin tiap pilihan dapat lebar yang sama — target sentuhnya jadi jelas.
class _BarisPilihan extends StatelessWidget {
  const _BarisPilihan({
    required this.icon,
    required this.judul,
    required this.nilai,
    required this.kontrol,
  });

  final IconData icon;
  final String judul;
  final String nilai;
  final Widget kontrol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IkonPetak(icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nilai,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(width: double.infinity, child: kontrol),
        ],
      ),
    );
  }
}

class _GarisPemisah extends StatelessWidget {
  const _GarisPemisah();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
    );
  }
}

/// Petak ikon lembut di kiri tiap baris.
class _IkonPetak extends StatelessWidget {
  const _IkonPetak({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 21,
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Baris menu (dengan chevron / trailing + aksi tap) ala list Image #3.
class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final redup = !enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: redup ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                _IkonPetak(icon: icon, color: iconColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
