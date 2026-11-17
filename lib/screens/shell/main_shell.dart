import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/beku_lembar_kerja.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../core/utils/inisial_nama.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../widgets/biru_awan/tombol_bulat.dart';
import '../../widgets/biru_awan/ubin_ikon.dart';
import '../../widgets/floating_nav_bar.dart';
import '../calibration/category_picker_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../draf/draf_screen.dart';
import '../equipment/equipment_list_screen.dart';
import '../arsip/arsip_screen.dart';
import '../history/history_screen.dart';
import '../admin/antrean_approval_screen.dart';
import '../alur/alur_kerja_screen.dart';
import '../../widgets/pemantau_antrean.dart';
import '../../widgets/pemeriksa_pembaruan.dart';
import '../notification/notification_screen.dart';
import '../jatuh_tempo/layar_jatuh_tempo.dart';
import '../pelacakan/telusuri_sertifikat_screen.dart';
import '../penugasan/penugasan_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/kelola_lab_screen.dart';
import '../teknisi/kalibrasi_teknisi_screen.dart';

/// Dipegang di level library, bukan lewat `Scaffold.of()`, karena tiap tab
/// punya `Scaffold` sendiri — `Scaffold.of()` dari dalam tab bakal nemu
/// Scaffold tab-nya, bukan yang megang Drawer ini.
final mainShellKey = GlobalKey<ScaffoldState>();

/// Buka menu samping dari AppBar tab mana pun.
void bukaMenuUtama() => mainShellKey.currentState?.openDrawer();

// Ukuran laci (`LAYAR.md` A3, artboard `Menu.dc.html`). Yang sudah punya token
// (sudut 32, stempel 30, ubin 44) dibaca dari token; sisanya diberi nama di sini.
const double _lebarLaci = 320;
const double _bantalanLaciSamping = 14;
const double _bantalanLaciAtas = 20;
const double _jarakSeksi = 18;
const double _jarakButir = 2;
const double _tinggiButir = 52;
const double _ukuranAvatar = 52;
const double _ukuranLencana = 26;
const double _bantalanLencana = 7;
const int _lencanaMaks = 99;

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
    ArsipScreen(),
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

  /// Latar redup di belakang laci (artboard `Menu`: navy 42 %).
  static const _alfaLatarLaci = 0.42;

  /// Teknisi: DUA tab saja — Kalibrasi & Profil (K-50-14). Tab lain tidak
  /// ikut dibangun sama sekali: `IndexedStack` membangun SEMUA anaknya, jadi
  /// dashboard (panel 3D, grafik), daftar alat, dan riwayat 20 halaman dulu
  /// ikut dimuat di HP teknisi walau tidak pernah dibuka.
  static const _tabsTeknisi = <Widget>[
    KalibrasiTeknisiScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final teknisi = ref.watch(authProvider).value?.role == UserRole.teknisi;
    final tabs = teknisi ? _tabsTeknisi : _tabs;
    // Indeks tab disimpan bersama; teknisi cuma punya dua.
    final selected = ref.watch(selectedTabProvider).clamp(0, tabs.length - 1);

    // Nyalain sinkron realtime selama shell (login) kebuka — lonceng & data
    // ke-update barengan sama panel desktop (spec poin 12D). No-op kalau
    // realtime nonaktif.
    ref.watch(realtimeSyncProvider);

    final items = teknisi
        ? <FloatingNavItem>[
            FloatingNavItem(
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment,
              label: l10n.navKalibrasi,
            ),
            FloatingNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: l10n.navProfile,
            ),
          ]
        : <FloatingNavItem>[
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
              label: l10n.profArsip,
            ),
            FloatingNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: l10n.navProfile,
            ),
          ];

    final pilihTab = ref.read(selectedTabProvider.notifier).select;

    // Mulai di tengah dock teknisi: alur Mulai kalibrasi yang SAMA dengan
    // tombol di layar Kalibrasi (`KalibrasiTeknisiScreen.buka`): pilih alat,
    // lalu ketiga daftar disegarkan sesudah kembali. Tidak ada rute baru.
    final aksiMulai = teknisi
        ? TombolBulat(
            key: const ValueKey('dock-mulai'),
            ikon: Icons.add,
            label: l10n.dashStartCalibration,
            ukuran: UkuranTombolBulat.mulai,
            ragam: RagamTombolBulat.primer,
            onPressed: () => KalibrasiTeknisiScreen.buka(
              context,
              ref,
              const BekuLembarKerja(child: CategoryPickerScreen()),
            ),
          )
        : null;

    // IndexedStack, bukan ganti-ganti widget: state tiap tab (posisi scroll,
    // isian form) nggak ilang waktu pindah tab.
    final isi = IndexedStack(index: selected, children: tabs);

    final m = SidikMaterial.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pakaiRail = constraints.maxWidth >= _lebarRail;

        return Scaffold(
          key: mainShellKey,
          // Latar redup laci: navy 42 % (artboard `Menu`); gelap memakai meja.
          drawerScrimColor: (m.terang ? m.tinta : m.meja).withValues(
            alpha: _alfaLatarLaci,
          ),
          // Teknisi tidak punya menu samping: dua tab sudah semua tujuannya.
          drawer: teknisi ? null : const _MenuUtama(),
          // Lihat catatan di DesktopShell: pemantau antrean dibungkus di luar
          // isi supaya tandanya muncul di layar mana pun.
          body: PemantauAntrean(
            // Banner + cek ulang pembaruan untuk SEMUA peran, di tab mana pun
            // (lihat `PemeriksaPembaruan`).
            child: PemeriksaPembaruan(
              child: pakaiRail
                  ? Row(
                      children: [
                        _RailSamping(
                          selectedIndex: selected,
                          onSelected: pilihTab,
                          items: items,
                          tanpaMenu: teknisi,
                          dibentangkan:
                              constraints.maxWidth >= _lebarRailPanjang,
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(child: isi),
                      ],
                    )
                  : isi,
            ),
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
                  aksiTengah: aksiMulai,
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
    this.tanpaMenu = false,
  });

  /// Tombol menu samping disembunyikan (teknisi tidak punya drawer).
  final bool tanpaMenu;

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
      leading: tanpaMenu
          ? null
          : Padding(
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
///
/// [jumlah] > 0 menampilkan lencana koral di ujung baris (Antrean approval,
/// Draf, Jadwal, Notifikasi). Angkanya dari provider yang sudah dimuat shell
/// (`dashboardProvider`, `unreadCountProvider`); laci tidak memanggil layanan
/// baru.
class _Tujuan {
  const _Tujuan(this.ikon, this.judul, {this.tab, this.layar, this.jumlah = 0});

  final IconData ikon;
  final String judul;
  final int? tab;
  final Widget Function()? layar;
  final int jumlah;
}

/// Menu samping — **isinya beda per peran**, karena pekerjaan hariannya beda.
///
/// Dulu satu daftar yang sama buat semua orang, disaring `if (admin)` di
/// sana-sini: super admin melihat menu teknisi (Draf) yang tidak bisa dia isi,
/// dan teknisi tidak punya jalan ke "Tugas saya" sama sekali. Sekarang tiap
/// peran dapat urutan yang dimulai dari pekerjaan UTAMANYA:
///
/// - **Super admin** — SEMUA menu admin & teknisi (keputusan
///   K-49-14, 15 Okt 2026: satu tempat untuk semua aksi). Sesi yang dia isi
///   tetap disetujui orang lain — server yang
///   menahan (`pemisahan_wewenang`).
/// - **Admin** — Antrean approval, Alur kerja,
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
    final m = SidikMaterial.of(context);
    final user = ref.watch(authProvider).value;
    final peran = user?.role ?? UserRole.viewer;
    final w = WarnaBiruAwan.of(context);
    final tabAktif = ref.watch(selectedTabProvider);
    // Angka lencana: ringkasan yang sama dengan tab Beranda (sudah dimuat di
    // IndexedStack) dan jumlah notifikasi belum dibaca yang sama dengan lonceng.
    // Gagal/menunggu = tanpa lencana, bukan angka karangan.
    final ringkasan = ref.watch(dashboardProvider).value;
    final belumDibaca = ref.watch(unreadCountProvider).value ?? 0;

    final beranda = _Tujuan(
      Icons.space_dashboard_outlined,
      l10n.navDashboard,
      tab: 0,
    );
    final alat = _Tujuan(Icons.straighten_outlined, l10n.navEquipment, tab: 1);
    final riwayat = _Tujuan(Icons.history_outlined, l10n.navHistory, tab: 2);
    final folder = _Tujuan(Icons.folder_outlined, l10n.profArsip, tab: 3);
    final profil = _Tujuan(Icons.person_outline, l10n.navProfile, tab: 4);
    final notifikasi = _Tujuan(
      Icons.notifications_none,
      l10n.navNotifications,
      layar: () => const NotificationScreen(),
      jumlah: belumDibaca,
    );
    final pelacakan = _Tujuan(
      Icons.local_shipping_outlined,
      l10n.telusuriJudul,
      layar: () => const TelusuriSertifikatScreen(),
    );
    final penugasan = _Tujuan(
      Icons.assignment_ind_outlined,
      l10n.penugasanJudul,
      layar: () => const PenugasanScreen(),
    );
    final jadwal = _Tujuan(
      Icons.event_repeat_outlined,
      l10n.jadwalJudul,
      layar: () => const JadwalKalibrasiScreen(),
      jumlah: ringkasan?.alatOverdue ?? 0,
    );
    final alur = _Tujuan(
      Icons.account_tree_outlined,
      l10n.alurTitle,
      layar: () => const AlurKerjaScreen(),
    );
    final draf = _Tujuan(
      Icons.edit_note,
      l10n.drafTitle,
      layar: () => const DrafScreen(),
      jumlah: ringkasan?.kalibrasiDraft ?? 0,
    );

    final antreanApproval = _Tujuan(
      Icons.inbox_outlined,
      l10n.antreanTitle,
      layar: () => const AntreanApprovalScreen(),
      jumlah: ringkasan?.menungguApproval ?? 0,
    );
    final kelolaLab = _Tujuan(
      Icons.tune,
      l10n.kelolaJudul,
      layar: () => const KelolaLabScreen(),
    );

    final List<(String?, List<_Tujuan>)> seksi = switch (peran) {
      // Gabungan menu admin + teknisi (Pengesahan dicabut 15 Okt, K-50-07).
      UserRole.superAdmin => [
        (
          l10n.menuKerjaHarian,
          [beranda, antreanApproval, alur, penugasan, pelacakan, draf],
        ),
        (l10n.menuArsip, [riwayat, alat, jadwal, folder, notifikasi]),
        (l10n.menuPengaturan, [kelolaLab, profil]),
      ],
      UserRole.admin => [
        (
          l10n.menuKerjaHarian,
          [beranda, antreanApproval, alur, penugasan, pelacakan, draf],
        ),
        (l10n.menuArsip, [riwayat, alat, jadwal, folder, notifikasi]),
        (l10n.menuPengaturan, [kelolaLab, profil]),
      ],
      UserRole.teknisi => [
        (
          l10n.menuKerjaHarian,
          [
            beranda,
            _Tujuan(
              Icons.assignment_ind_outlined,
              l10n.penugasanTugasSaya,
              layar: () => const PenugasanScreen(),
            ),
            draf,
            riwayat,
          ],
        ),
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
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => t.layar!()));
      }
    }

    // Panel kiri: selebar 320 (artboard `Menu`), tetapi di layar sempit selalu
    // menyisakan satu sasaran sentuh di kanan supaya latar redup bisa diketuk.
    final lebarLaci = math.min(
      _lebarLaci,
      MediaQuery.sizeOf(context).width - AppUkuran.sasaranSentuh,
    );

    return Drawer(
      width: lebarLaci,
      backgroundColor: m.kertas,
      shadowColor: m.terang ? m.tinta : m.meja,
      // Bayangan sangat tipis (REVISI 16 Nov 2026; bawaan Drawer 16).
      elevation: 1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(BentukBiruAwan.lembarBawah),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: _bantalanLaciSamping,
            vertical: _bantalanLaciAtas,
          ),
          children: [
            // Kepala menu: siapa yang sedang masuk dan sebagai apa, supaya
            // orang yang pinjam HP rekannya langsung sadar menunya milik
            // siapa. Avatar berisi inisial, stempel peran, tombol tutup 44.
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: Padding(
                padding: const EdgeInsets.all(JarakBiruAwan.sisipan),
                child: Row(
                  children: [
                    UbinIkon(
                      ukuran: _ukuranAvatar,
                      warna: IsiBiruAwan.awan,
                      child: Text(
                        inisialNama(user?.nama ?? ''),
                        style: HurufBiruAwan.judulBagian.copyWith(
                          color: w.tinta(IsiBiruAwan.awan),
                        ),
                      ),
                    ),
                    const SizedBox(width: JarakBiruAwan.blok),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.nama ?? l10n.menuUtama,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HurufBiruAwan.judulBaris.copyWith(
                              color: m.tinta,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _PilPeran(peran.label),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TombolBulat(
                      key: const ValueKey('laci-tutup'),
                      ikon: Icons.close,
                      label: l10n.shellTutupMenu,
                      ukuran: UkuranTombolBulat.kecil,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            // Super admin & viewer dapat satu kalimat yang bilang apa yang
            // bisa & tidak: viewer supaya tidak mencari tombol yang memang
            // tidak ada, super admin supaya tahu sesi isiannya sendiri tetap
            // butuh penyetuju lain (K-30-03).
            if (peran == UserRole.superAdmin || peran == UserRole.viewer)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JarakBiruAwan.sisipan,
                  AppSpacing.sm,
                  JarakBiruAwan.sisipan,
                  0,
                ),
                child: Text(
                  peran == UserRole.superAdmin
                      ? l10n.menuCatatanSuperAdmin
                      : l10n.menuCatatanViewer,
                  style: HurufBiruAwan.keteranganKecil.copyWith(
                    color: m.tinta2,
                  ),
                ),
              ),
            for (final (judul, isi) in seksi) ...[
              const SizedBox(height: _jarakSeksi),
              if (judul != null)
                _LabelSeksi(judul)
              else
                Divider(
                  height: AppUkuran.garis,
                  thickness: AppUkuran.garis,
                  color: m.kertasTepi,
                ),
              for (final t in isi)
                Padding(
                  padding: const EdgeInsets.only(top: _jarakButir),
                  child: _ButirLaci(
                    tujuan: t,
                    terpilih: t.tab != null && t.tab == tabAktif,
                    onTap: () => buka(t),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stempel peran di kepala laci: lencana kabut 24 bersudut 6, kata 12/600
/// (`biruTinta` di atas kabut 7,31:1). Bukan tombol; nama peran dibaca sebagai
/// teks biasa.
class _PilPeran extends StatelessWidget {
  const _PilPeran(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UkuranBiruAwan.stempel),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: w.isi(IsiBiruAwan.kabut),
            borderRadius: BorderRadius.circular(BentukBiruAwan.lencana),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Center(
              widthFactor: 1,
              child: Text(
                teks,
                style: HurufBiruAwan.stempel.copyWith(color: m.biruTinta),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu butir laci (`LAYAR.md` A3): tinggi minimum 52, sudut 12, ikon 22 + label
/// 15/500. TERPILIH = kabut + `biruTinta` 600 (penanda latar DAN bobot, bukan
/// warna saja). [Lencana] merah di ujung bila ada angka.
///
/// Seluruh baris menerima ketukan. Pembaca layar mendengar satu butir:
/// "judul, jumlah" bila ada lencana, ditandai terpilih.
class _ButirLaci extends StatelessWidget {
  const _ButirLaci({
    required this.tujuan,
    required this.terpilih,
    required this.onTap,
  });

  final _Tujuan tujuan;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final warnaIsi = terpilih ? m.biruTinta : m.tinta;
    final gaya = HurufBiruAwan.tombol.copyWith(
      color: warnaIsi,
      fontWeight: terpilih ? FontWeight.w600 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: terpilih,
      label: tujuan.jumlah > 0
          ? l10n.biruAwanChipJumlah(tujuan.judul, tujuan.jumlah)
          : tujuan.judul,
      onTap: onTap,
      excludeSemantics: true,
      child: TekanSkala(
        child: Material(
          color: terpilih ? m.biruTipis : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentukBiruAwan.saringan),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _tinggiButir),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _bantalanLaciSamping,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      tujuan.ikon,
                      size: UkuranKomponenBiruAwan.ikonBulat,
                      color: warnaIsi,
                    ),
                    const SizedBox(width: _bantalanLaciSamping),
                    Expanded(child: Text(tujuan.judul, style: gaya)),
                    if (tujuan.jumlah > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Lencana(tujuan.jumlah),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana jumlah merah di ujung butir laci: kotak >= 26 bersudut 6, angka 12/600
/// putih di atas merah galat (7,32:1). Lebih dari 99 ditulis "99+". Hanya angka
/// dari provider; tidak menghitung apa pun.
class _Lencana extends StatelessWidget {
  const _Lencana(this.jumlah);

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _ukuranLencana,
        minHeight: _ukuranLencana,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: m.gagal,
          borderRadius: BorderRadius.circular(BentukBiruAwan.lencana),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _bantalanLencana),
            child: Text(
              jumlah > _lencanaMaks ? '$_lencanaMaks+' : '$jumlah',
              style: HurufBiruAwan.stempel.copyWith(color: m.teksDiGagal),
            ),
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
    final m = SidikMaterial.of(context);

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _bantalanLaciSamping,
          0,
          _bantalanLaciSamping,
          JarakBiruAwan.sisipan,
        ),
        child: Text(
          teks,
          style: HurufBiruAwan.stempel.copyWith(color: m.tinta2),
        ),
      ),
    );
  }
}
