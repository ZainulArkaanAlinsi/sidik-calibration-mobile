import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/widgets/banner_pembaruan_windows.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';

import '../inti/lingkungan_studio.dart';
import '../inti/sesi_studio.dart';
import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';
import '../widget/bilah_status.dart';
import '../widget/dialog_sesi_berakhir.dart';
import '../widget/merek_studio.dart';
import 'seksi_studio.dart';

/// Tata letak navigasi Studio (FR-STU-011, `04-UI-UX-Flow.md` §2.1).
enum TataLetakStudio {
  /// Windows/desktop: sidebar kiri 240 dp + bilah status bawah.
  sidebar,

  /// Tablet lanskap (±1138 dp) atau jendela desktop < 1024 dp: rail 72 dp,
  /// ikon + label.
  rail,

  /// Tablet potret (±711 dp): rail 56 dp ikon saja; label di tooltip/tekan
  /// lama.
  railRingkas,

  /// Lebih sempit dari 600 dp (HP, jendela sangat sempit): drawer di balik
  /// tombol menu. Bukan sasaran Studio, tapi tidak boleh rusak.
  laci,
}

/// Pilih tata letak dari platform + ukuran.
///
/// Platform dibaca lewat `pakaiPanelDesktopProvider` paket bersama (Windows &
/// macOS = meja; test menimpanya): yang menentukan tablet vs meja itu alat
/// tunjuknya, bukan cuma lebar.
TataLetakStudio tataLetakStudio({required bool meja, required Size ukuran}) {
  if (ukuran.width < 600) return TataLetakStudio.laci;
  if (meja) {
    return ukuran.width >= 1024
        ? TataLetakStudio.sidebar
        : TataLetakStudio.rail;
  }
  return ukuran.width > ukuran.height
      ? TataLetakStudio.rail
      : TataLetakStudio.railRingkas;
}

/// Kunci butir navigasi seksi — dipakai test & otomasi, sama di sidebar,
/// rail, maupun drawer.
ValueKey<String> kunciNavigasi(SeksiStudio seksi) =>
    ValueKey('nav-${seksi.name}');

/// Cangkang Studio sesudah masuk: navigasi seksi, bilah atas, panel konten,
/// bilah status.
///
/// Konten tiap seksi punya [Navigator] sendiri, jadi layar detail (mis. studio
/// satu paket acuan) terbuka DI DALAM panel konten — navigasi tetap terlihat,
/// seperti aplikasi meja pada umumnya.
///
/// Dua kewajiban sesi (ST-T-012) dipegang di sini, karena cangkang adalah
/// yang hidup selama orang bekerja:
///  - `401` di mana pun → dialog "Sesi berakhir" DI ATAS layar yang sama;
///  - kembali dari latar → izin ditarik ulang dari server (FR-STU-007).
class CangkangStudio extends ConsumerStatefulWidget {
  const CangkangStudio({super.key});

  @override
  ConsumerState<CangkangStudio> createState() => _CangkangStudioState();
}

class _CangkangStudioState extends ConsumerState<CangkangStudio> {
  final _kunciScaffold = GlobalKey<ScaffoldState>();

  /// Panel konten dipindah antar-induk waktu tata letak berganti (tablet
  /// diputar, jendela dipersempit). GlobalKey membuat Flutter MEMINDAHKAN
  /// subpohon itu, bukan membangunnya ulang — layar detail yang sedang terbuka
  /// di navigator seksi tidak hilang hanya karena tablet diputar.
  final _kunciKonten = GlobalKey();

  late final AppLifecycleListener _siklus;
  bool _dialogSesiTerbuka = false;

  @override
  void initState() {
    super.initState();
    // `onShow` = tersembunyi → tampil lagi: kembali dari latar di Android,
    // dipulihkan dari minimize di Windows. Sengaja BUKAN `onResume`: di
    // Windows itu terpicu tiap jendela mendapat fokus lagi (alt-tab), dan
    // menembak `/me/permissions` tiap alt-tab tidak membeli apa-apa.
    _siklus = AppLifecycleListener(onShow: () => ref.invalidate(izinProvider));
  }

  @override
  void dispose() {
    _siklus.dispose();
    super.dispose();
  }

  Future<void> _tampilkanDialogSesi() async {
    if (_dialogSesiTerbuka) return;
    _dialogSesiTerbuka = true;
    await tampilkanDialogSesiBerakhir(context);
    _dialogSesiTerbuka = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sesiStudioProvider, (_, keadaan) {
      if (keadaan == KeadaanSesiStudio.berakhir) _tampilkanDialogSesi();
    });

    final meja = ref.watch(pakaiPanelDesktopProvider);

    // Seksi yang tampil di navigasi: yang diizinkan server, plus seksi tahap
    // mendatang (nonaktif, tidak bisa dibuka).
    final tampil = [
      for (final s in SeksiStudio.values)
        if (!s.tersedia || s.boleh(ref)) s,
    ];
    final bisaDibuka = tampil.where((s) => s.tersedia).toList();
    final pilihan = ref.watch(pilihanSeksiStudioProvider);
    final aktif = bisaDibuka.contains(pilihan)
        ? pilihan
        : bisaDibuka.firstOrNull;

    void pilih(SeksiStudio s) =>
        ref.read(pilihanSeksiStudioProvider.notifier).pilih(s);

    final konten = _KontenStudio(key: _kunciKonten, aktif: aktif);

    return LayoutBuilder(
      builder: (context, batas) {
        final tata = tataLetakStudio(meja: meja, ukuran: batas.biggest);

        final Widget? navigasi = switch (tata) {
          TataLetakStudio.sidebar => SizedBox(
            width: UkuranStudio.lebarSidebar,
            child: _PanelNavigasi(tampil: tampil, aktif: aktif, onPilih: pilih),
          ),
          TataLetakStudio.rail => _RailStudio(
            tampil: tampil,
            aktif: aktif,
            onPilih: pilih,
            ringkas: false,
          ),
          TataLetakStudio.railRingkas => _RailStudio(
            tampil: tampil,
            aktif: aktif,
            onPilih: pilih,
            ringkas: true,
          ),
          TataLetakStudio.laci => null,
        };

        return Scaffold(
          key: _kunciScaffold,
          drawer: tata == TataLetakStudio.laci
              ? Drawer(
                  child: _PanelNavigasi(
                    tampil: tampil,
                    aktif: aktif,
                    onPilih: (s) {
                      pilih(s);
                      _kunciScaffold.currentState?.closeDrawer();
                    },
                  ),
                )
              : null,
          body: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?navigasi,
                    Expanded(
                      child: Column(
                        children: [
                          _BilahAtas(
                            seksi: aktif,
                            onMenu: tata == TataLetakStudio.laci
                                ? () =>
                                      _kunciScaffold.currentState?.openDrawer()
                                : null,
                            // Di tablet bilah status dilipat ke menu akun
                            // (§2.1); di meja ia di bawah + kaki sidebar.
                            denganMenuAkun: tata != TataLetakStudio.sidebar,
                          ),
                          Expanded(child: konten),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // "Versi X siap — mulai ulang untuk memasang" (pembaru Windows
              // Studio, `main.dart`). Kotak kosong bila tidak ada pembaruan.
              const BannerPembaruanWindows(),
              if (tata == TataLetakStudio.sidebar) const BilahStatus(),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────── konten

class _KontenStudio extends ConsumerWidget {
  const _KontenStudio({super.key, required this.aktif});

  final SeksiStudio? aktif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final izin = ref.watch(izinProvider);

    // Izin belum sampai → tunggu, jangan buru-buru menggambar seksi yang
    // belum tentu boleh.
    if (!izin.hasValue && !izin.hasError) {
      return Center(
        child: Semantics(
          label: l10n.memuat,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    // Izin GAGAL diambil: katakan apa adanya + coba lagi. Bukan "tanpa izin" —
    // itu klaim yang belum tentu benar.
    if (!izin.hasValue) {
      return _Keadaan(
        ikon: Icons.cloud_off_outlined,
        judul: l10n.izinGagalJudul,
        aksi: FilledButton.icon(
          onPressed: () => ref.invalidate(izinProvider),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.cobaLagi),
        ),
      );
    }

    // Beranda selalu bisa dibuka; `null` cuma bila daftar seksi kosong.
    final seksi = aktif;
    if (seksi == null) return const SizedBox.shrink();

    return _PanelSeksi(key: ValueKey(seksi), seksi: seksi);
  }
}

/// Satu seksi dengan [Navigator]-nya sendiri.
class _PanelSeksi extends StatefulWidget {
  const _PanelSeksi({super.key, required this.seksi});

  final SeksiStudio seksi;

  @override
  State<_PanelSeksi> createState() => _PanelSeksiState();
}

class _PanelSeksiState extends State<_PanelSeksi> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final akar = widget.seksi.bangun();
    // Seksi tanpa layar tidak pernah sampai sini (nonaktif di navigasi).
    if (akar == null) return const SizedBox.shrink();

    // `container: true` WAJIB: rute di navigator bersarang memasang
    // `BlockSemantics`, yang membuang semantik semua yang dilukis sebelumnya
    // di wadah semantik yang sama — termasuk sidebar di sebelahnya. Tanpa
    // wadah sendiri, pembaca layar tidak melihat satu pun menu Studio
    // (ketahuan dari test semantik `studio_test.dart`).
    //
    // Tombol kembali sistem (Android) memundurkan navigator seksi dulu,
    // bukan langsung menutup aplikasi.
    return Semantics(
      container: true,
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => _navigator.currentState?.maybePop(),
        child: Navigator(
          key: _navigator,
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(builder: (_) => akar),
          ],
        ),
      ),
    );
  }
}

class _Keadaan extends StatelessWidget {
  const _Keadaan({required this.ikon, required this.judul, this.aksi});

  final IconData ikon;
  final String judul;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 36, color: w.teksRedup),
              const SizedBox(height: UkuranStudio.j3),
              Text(judul, textAlign: TextAlign.center, style: teks.titleMedium),
              if (aksi != null) ...[
                const SizedBox(height: UkuranStudio.j4),
                aksi!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── bilah atas

/// Bilah atas 48 dp (`UkuranStudio.tinggiBilah`): jejak navigasi (akar = seksi
/// aktif), tombol menu (drawer), dan menu akun di tablet.
///
/// Status simpan & aksi utama per layar menyusul bersama layar yang
/// membutuhkannya (S2+). Layar M2 data acuan masih membawa AppBar sendiri
/// sampai dipindah ke Studio (ST-T-014).
class _BilahAtas extends StatelessWidget {
  const _BilahAtas({
    required this.seksi,
    required this.onMenu,
    required this.denganMenuAkun,
  });

  final SeksiStudio? seksi;
  final VoidCallback? onMenu;
  final bool denganMenuAkun;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);

    return Material(
      color: w.permukaan,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: UkuranStudio.tinggiBilah,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: w.garis)),
          ),
          padding: EdgeInsets.only(
            left: onMenu == null ? UkuranStudio.j4 : UkuranStudio.j1,
            right: UkuranStudio.j1,
          ),
          child: Row(
            children: [
              if (onMenu != null) ...[
                IconButton(
                  tooltip: l10n.bukaMenu,
                  icon: const Icon(Icons.menu),
                  onPressed: onMenu,
                ),
                const SizedBox(width: UkuranStudio.j1),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    seksi?.label(l10n) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              if (denganMenuAkun) const _MenuAkun(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu akun (tablet): isi bilah status + tema + keluar.
class _MenuAkun extends ConsumerWidget {
  const _MenuAkun();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final gelap = ref.watch(modeTemaStudioProvider) == ThemeMode.dark;

    return MenuAnchor(
      menuChildren: [
        const RincianStatus(),
        const Divider(),
        MenuItemButton(
          leadingIcon: Icon(
            gelap ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: () => ref.read(modeTemaStudioProvider.notifier).balik(),
          child: Text(gelap ? l10n.temaTerang : l10n.temaGelap),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          onPressed: () =>
              keluarStudio(ProviderScope.containerOf(context, listen: false)),
          child: Text(l10n.keluar),
        ),
      ],
      builder: (context, kendali, _) => IconButton(
        tooltip: l10n.menuAkun,
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => kendali.isOpen ? kendali.close() : kendali.open(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── navigasi

/// Sidebar (desktop) dan isi drawer (layar sempit) — satu widget.
class _PanelNavigasi extends StatelessWidget {
  const _PanelNavigasi({
    required this.tampil,
    required this.aktif,
    required this.onPilih,
  });

  final List<SeksiStudio> tampil;
  final SeksiStudio? aktif;
  final ValueChanged<SeksiStudio> onPilih;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);

    return Material(
      color: w.sisi,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                UkuranStudio.j4,
                UkuranStudio.j4,
                UkuranStudio.j3,
                UkuranStudio.j4,
              ),
              child: MerekStudio(),
            ),
            Divider(color: w.sisiGaris),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: UkuranStudio.j2,
                  vertical: UkuranStudio.j3,
                ),
                children: [
                  for (final s in tampil)
                    _ItemSeksi(
                      key: kunciNavigasi(s),
                      seksi: s,
                      aktif: s == aktif,
                      onTap: s.tersedia ? () => onPilih(s) : null,
                    ),
                ],
              ),
            ),
            Divider(color: w.sisiGaris),
            const _KakiAkun(),
          ],
        ),
      ),
    );
  }
}

class _ItemSeksi extends StatelessWidget {
  const _ItemSeksi({
    super.key,
    required this.seksi,
    required this.aktif,
    this.onTap,
  });

  final SeksiStudio seksi;
  final bool aktif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final sentuh =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
    final label = seksi.label(l10n);
    final tahap = seksi.tahap;
    final nonaktif = tahap != null;

    final warnaTeks = nonaktif
        ? w.sisiTeksRedup
        : (aktif ? w.sisiTeks : w.sisiTeks.withValues(alpha: 0.88));

    Widget baris = Container(
      height: sentuh ? 48 : 38,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: aktif ? w.sisiAktif : null,
        borderRadius: BorderRadius.circular(UkuranStudio.sudut),
        // Penanda aktif = garis amber di kiri, warna yang sama dengan sel
        // terpilih di ikon Studio.
        border: Border(
          left: BorderSide(
            color: aktif ? w.aksen : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
      child: Row(
        children: [
          Icon(
            aktif ? seksi.ikonAktif : seksi.ikon,
            size: 18,
            color: aktif ? w.aksen : warnaTeks,
          ),
          const SizedBox(width: UkuranStudio.j3),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: teks.bodyMedium?.copyWith(
                color: warnaTeks,
                fontWeight: aktif ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (nonaktif) _LencanaTahap(kode: tahap),
        ],
      ),
    );

    if (nonaktif) {
      // Nonaktif yang JUJUR: terlihat, tidak bisa ditekan, dan alasannya
      // terbaca (tooltip + pembaca layar).
      return Tooltip(
        message: l10n.tahapBelumTersedia(tahap),
        child: Semantics(
          container: true,
          button: true,
          enabled: false,
          label: '$label. ${l10n.tahapBelumTersedia(tahap)}',
          excludeSemantics: true,
          child: baris,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: aktif,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UkuranStudio.sudut),
        hoverColor: w.sisiAktif.withValues(alpha: 0.6),
        child: baris,
      ),
    );
  }
}

class _LencanaTahap extends StatelessWidget {
  const _LencanaTahap({required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: w.sisiGaris),
        borderRadius: BorderRadius.circular(UkuranStudio.sudut),
      ),
      child: Text(
        l10n.tahapKode(kode),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: w.sisiTeksRedup),
      ),
    );
  }
}

/// Akun yang masuk + tema + keluar. Dipakai sidebar & drawer.
class _KakiAkun extends ConsumerWidget {
  const _KakiAkun();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final user = ref.watch(authProvider).value;
    final peran = labelPeranStudio(peranAkunStudio(ref), l10n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UkuranStudio.j4,
        UkuranStudio.j2,
        UkuranStudio.j1,
        UkuranStudio.j2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.nama ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.bodyMedium?.copyWith(
                    color: w.sisiTeks,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _labelAkun(user, peran),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: teks.labelMedium?.copyWith(color: w.sisiTeksRedup),
                ),
              ],
            ),
          ),
          const _TombolTema(),
          const _TombolKeluar(),
        ],
      ),
    );
  }
}

/// "Master Data · SDK-0001 · DEV". Lingkungan cuma disebut kalau build-nya
/// dinyatakan bukan produksi — Studio akan menyunting data, dan salah jendela
/// (dev vs produksi) adalah kesalahan yang mahal.
String _labelAkun(User? user, String peran) {
  final bagian = [
    if (user != null && peran.isNotEmpty) peran,
    if (user != null && user.employeeId.isNotEmpty) user.employeeId,
    if (appEnvStudio.isNotEmpty && appEnvStudio != 'prod')
      appEnvStudio.toUpperCase(),
  ];
  return bagian.join(' · ');
}

class _TombolTema extends ConsumerWidget {
  const _TombolTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final gelap = ref.watch(modeTemaStudioProvider) == ThemeMode.dark;
    return IconButton(
      tooltip: gelap ? l10n.temaTerang : l10n.temaGelap,
      color: w.sisiTeks,
      icon: Icon(gelap ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref.read(modeTemaStudioProvider.notifier).balik(),
    );
  }
}

class _TombolKeluar extends StatelessWidget {
  const _TombolKeluar();

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return IconButton(
      tooltip: l10n.keluar,
      color: w.sisiTeks,
      icon: const Icon(Icons.logout),
      onPressed: () =>
          keluarStudio(ProviderScope.containerOf(context, listen: false)),
    );
  }
}

/// Rail (tablet, jendela desktop sempit). [ringkas] = potret: 56 dp, ikon
/// saja, label di tooltip (tekan lama di layar sentuh).
class _RailStudio extends StatelessWidget {
  const _RailStudio({
    required this.tampil,
    required this.aktif,
    required this.onPilih,
    required this.ringkas,
  });

  final List<SeksiStudio> tampil;
  final SeksiStudio? aktif;
  final ValueChanged<SeksiStudio> onPilih;
  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final indeks = aktif == null ? -1 : tampil.indexOf(aktif!);

    // Tujuan nonaktif: NavigationRail mewarnainya `onSurface` 38% — warna
    // teks KONTEN, yang di tema terang gelap di atas navy sisi dan hilang sama
    // sekali (ketahuan dari golden). Warnanya dipasang eksplisit dari token
    // sisi, diredupkan supaya tetap beda dari tujuan yang bisa ditekan.
    final warnaNonaktif = w.sisiTeksRedup.withValues(alpha: 0.6);

    Widget ikon(SeksiStudio s, {required bool terpilih}) {
      final tahap = s.tahap;
      final label = s.label(l10n);
      Widget i = Icon(
        terpilih ? s.ikonAktif : s.ikon,
        color: tahap == null ? null : warnaNonaktif,
      );
      if (tahap != null) {
        i = Badge(
          label: Text(tahap),
          backgroundColor: w.sisiAktif,
          textColor: w.sisiTeks,
          child: i,
        );
      }
      // Kunci di ikon: `NavigationRailDestination` tidak menerima kunci.
      i = KeyedSubtree(key: kunciNavigasi(s), child: i);

      if (tahap != null) {
        return Tooltip(
          message: ringkas
              ? '$label. ${l10n.tahapBelumTersedia(tahap)}'
              : l10n.tahapBelumTersedia(tahap),
          child: i,
        );
      }
      return ringkas ? Tooltip(message: label, child: i) : i;
    }

    return NavigationRail(
      minWidth: ringkas ? 56 : 72,
      labelType: ringkas
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedIndex: indeks < 0 ? null : indeks,
      onDestinationSelected: (i) => onPilih(tampil[i]),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: UkuranStudio.j3),
        child: MerekStudio(denganNama: false, ukuranIkon: ringkas ? 32 : 36),
      ),
      destinations: [
        for (final s in tampil)
          NavigationRailDestination(
            icon: ikon(s, terpilih: false),
            selectedIcon: ikon(s, terpilih: true),
            label: Text(
              s.label(l10n),
              style: s.tersedia ? null : TextStyle(color: warnaNonaktif),
            ),
            disabled: !s.tersedia,
          ),
      ],
    );
  }
}
