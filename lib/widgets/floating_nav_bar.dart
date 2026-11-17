import 'package:flutter/material.dart';

import '../core/motion/app_motion.dart';
import '../core/motion/gerak_bersama.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_ukuran.dart';
import '../core/theme/bentuk_lab.dart';
import '../core/theme/sidik_material.dart';
import '../core/theme/token_komponen_biru_awan.dart';
import '../l10n/app_localizations.dart';

/// Satu item di [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Ragam dock: ukuran butir dan jarak antarbutir.
///
/// - [teknisi]: butir 52, jarak 10, bantalan pil 18; dua tujuan + Mulai di
///   tengah (`LAYAR.md` 01).
/// - [admin]: butir 48, jarak 4, bantalan pil 16; lima tujuan, tanpa Mulai
///   (`LAYAR.md` A1).
enum RagamDock { teknisi, admin }

/// Dock Biru Awan di bawah layar HP (`LAYAR.md` 01 dan A1; artboard `Komponen`,
/// `Main`, `BerandaAdmin` di `docs/desain-ulang/referensi-html/`).
///
/// Nama kelasnya peninggalan (dulu pil kaca, lalu panel logam); dipertahankan
/// karena `MainShell` dan tes memanggilnya, dan kontrak `selectedIndex` /
/// `onSelected` / `items` TIDAK berubah.
///
/// ## Bentuk
///
/// Pil putih (`kertas`) bersudut [BentukBiruAwan.dock], tepi halus, bayangan navy
/// 16 %; melayang [AppSpacing.md] di atas tepi sistem (area aman ikut).
///
/// - Butir AKTIF = pil kabut berisi ikon + label 14/800 `biruTinta` (primerTua).
/// - Butir LAIN = bulat berisi ikon `tinta2`, tanpa label tampak. Namanya tetap
///   dibaca pembaca layar (`Semantics.label`), jadi tiap butir punya nama.
/// - [aksiTengah] (Mulai di dock teknisi) disisipkan di tengah daftar [items].
///
/// ## Lebar sempit
///
/// Dock selebar isinya. Bila label butir aktif tidak muat (lebar 320, huruf
/// 1,3), label dikecilkan sampai 78 % lalu dibuang dan butir aktif tampil
/// sebagai bulat kabut berisi ikon. Butir tidak pernah lebih kecil dari
/// ukurannya (48/52), jadi sasaran sentuh selalu >= 48.
///
/// ## Teks tersembunyi pada butir tanpa label tampak
///
/// Butir yang labelnya tidak tampak tetap memuat satu `Text` berlabel dengan
/// `Opacity(0)`, dikeluarkan dari pohon semantik. Itu BUKAN untuk pembaca layar
/// (mereka memakai `Semantics.label`) melainkan menjaga tes yang sudah ada
/// (`widget_test`, `auth_test`, `history_test`, `equipment_test`, `standard_test`)
/// yang mengetuk butir dock lewat `find.text('Alat')` dan sejenisnya. Bila
/// tes-tes itu kelak diganti ke pencarian semantik, hapus blok `_LabelGaib`.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.ragam = RagamDock.admin,
    this.aksiTengah,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingNavItem> items;
  final RagamDock ragam;

  /// Tombol di tengah dock (Mulai kalibrasi). Dipasang di antara butir
  /// `items.length ~/ 2 - 1` dan `items.length ~/ 2`; untuk dua butir = tepat di
  /// tengah. Pemanggil yang menentukan aksi dan labelnya.
  final Widget? aksiTengah;

  /// Bantalan di dalam dock.
  static const _bantalan = AppSpacing.sm;

  /// Jarak antarbutir dock teknisi (artboard `Main`: 10).
  static const _jarakTeknisi = 10.0;

  /// Bayangan dock (artboard `Komponen`: 0 14 34 navy 16 %).
  static const _bayanganGeser = 14.0;
  static const _bayanganBlur = 34.0;
  static const _bayanganAlfa = 0.16;

  /// Label boleh dikecilkan sampai pecahan ini sebelum dibuang.
  static const _labelMinimum = 0.78;

  /// Selisih keamanan pengukuran teks (dp).
  static const _kelonggaran = 1.0;

  static double _lebarTeks(
    BuildContext context,
    String teks,
    TextStyle gaya,
  ) {
    final p = TextPainter(
      text: TextSpan(
        text: teks,
        style: DefaultTextStyle.of(context).style.merge(gaya),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final lebar = p.width;
    p.dispose();
    return lebar;
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final admin = ragam == RagamDock.admin;
    final sisi = admin
        ? UkuranBiruAwan.butirDockAdmin
        : UkuranBiruAwan.butirDockTeknisi;
    final jarak = admin ? AppSpacing.xs : _jarakTeknisi;
    final bantalanPil = admin ? AppSpacing.md : JarakBiruAwan.samping;
    final bayang = m.terang ? m.tinta : m.meja;
    final sisip = items.length ~/ 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, batas) {
            final gayaLabel = HurufBiruAwan.labelKecil.copyWith(
              fontWeight: FontWeight.w800,
              color: m.biruTinta,
            );
            final aktif = selectedIndex.clamp(0, items.length - 1);

            // Ruang yang tersisa untuk butir aktif setelah butir lain, tombol
            // tengah, jarak, dan bantalan dock dihitung (tepi dock 1 dp digambar
            // di atas bantalan, tidak menambah lebar).
            final jumlahAnak = items.length + (aksiTengah != null ? 1 : 0);
            final tetap =
                2 * _bantalan +
                (items.length - 1) * sisi +
                (aksiTengah != null ? UkuranBiruAwan.tombolMulaiDock : 0) +
                (jumlahAnak - 1) * jarak;
            final ruangPil = batas.maxWidth - tetap - _kelonggaran;
            final selainLabel =
                2 * bantalanPil +
                UkuranKomponenBiruAwan.ikonTombol +
                AppSpacing.sm;
            final ruangLabel = ruangPil - selainLabel;
            final lebarLabel = _lebarTeks(context, items[aktif].label, gayaLabel);

            final double? lebarAktifLabel;
            if (ruangLabel >= lebarLabel) {
              lebarAktifLabel = lebarLabel;
            } else if (ruangLabel >= lebarLabel * _labelMinimum) {
              lebarAktifLabel = ruangLabel;
            } else {
              lebarAktifLabel = null;
            }

            final anak = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              if (aksiTengah != null && i == sisip) anak.add(aksiTengah!);
              anak.add(
                _Butir(
                  key: ValueKey('dock-butir-$i'),
                  item: items[i],
                  nomor: i + 1,
                  jumlah: items.length,
                  aktif: i == aktif,
                  sisi: sisi,
                  bantalanPil: bantalanPil,
                  lebarLabel: i == aktif ? lebarAktifLabel : null,
                  gayaLabel: gayaLabel,
                  onTap: () => onSelected(i),
                ),
              );
            }

            // `heightFactor: 1`: dock setinggi isinya. Tanpa itu `Center` mengisi
            // seluruh tinggi yang ditawarkan `Scaffold` dan badan layar habis.
            return Center(
              heightFactor: 1,
              child: DecoratedBox(
                key: const ValueKey('dock'),
                decoration: BoxDecoration(
                  color: m.kertas,
                  borderRadius: BorderRadius.circular(BentukBiruAwan.dock),
                  border: Border.all(
                    color: m.kertasTepi,
                    width: AppUkuran.garis,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bayang.withValues(alpha: _bayanganAlfa),
                      offset: const Offset(0, _bayanganGeser),
                      blurRadius: _bayanganBlur,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_bantalan),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < anak.length; i++) ...[
                        if (i > 0) SizedBox(width: jarak),
                        anak[i],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Satu butir dock. [lebarLabel] `null` = label tidak tampak (butir lain, atau
/// butir aktif yang labelnya tidak muat); selain itu lebar yang disediakan untuk
/// label butir aktif.
class _Butir extends StatefulWidget {
  const _Butir({
    super.key,
    required this.item,
    required this.nomor,
    required this.jumlah,
    required this.aktif,
    required this.sisi,
    required this.bantalanPil,
    required this.lebarLabel,
    required this.gayaLabel,
    required this.onTap,
  });

  final FloatingNavItem item;
  final int nomor;
  final int jumlah;
  final bool aktif;
  final double sisi;
  final double bantalanPil;
  final double? lebarLabel;
  final TextStyle gayaLabel;
  final VoidCallback onTap;

  @override
  State<_Butir> createState() => _ButirState();
}

class _ButirState extends State<_Butir> {
  bool _fokus = false;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final aktif = widget.aktif;
    final labelTampak = aktif && widget.lebarLabel != null;
    final durasi = AppMotion.hormati(context, AppMotion.kilat);

    final Widget isi;
    if (labelTampak) {
      isi = Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.bantalanPil),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.item.activeIcon,
              size: UkuranKomponenBiruAwan.ikonTombol,
              color: m.biruTinta,
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: widget.lebarLabel,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: widget.gayaLabel,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      isi = SizedBox.square(
        dimension: widget.sisi,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              aktif ? widget.item.activeIcon : widget.item.icon,
              size: aktif
                  ? UkuranKomponenBiruAwan.ikonTombol
                  : UkuranKomponenBiruAwan.ikonBulat,
              color: aktif ? m.biruTinta : m.tinta2,
            ),
            _LabelGaib(teks: widget.item.label),
          ],
        ),
      );
    }

    // Cincin fokus papan ketik: di LUAR butir, terpisah dari tepinya, navy
    // (`tinta`) terhadap putih dock >= 3:1 terang dan gelap.
    const inset =
        UkuranKomponenBiruAwan.jarakCincinFokus + AppUkuran.garisTebal;

    return Semantics(
      button: true,
      selected: aktif,
      label: widget.item.label,
      hint: l10n.navLabTabHint(widget.nomor, widget.jumlah),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: TekanSkala(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: durasi,
              curve: AppMotion.masuk,
              constraints: BoxConstraints(
                minWidth: widget.sisi,
                minHeight: widget.sisi,
              ),
              decoration: ShapeDecoration(
                color: aktif ? m.biruTipis : Colors.transparent,
                shape: const StadiumBorder(),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: widget.onTap,
                  onFocusChange: (v) => setState(() => _fokus = v),
                  child: SizedBox(
                    height: widget.sisi,
                    child: Center(widthFactor: 1, child: isi),
                  ),
                ),
              ),
            ),
            if (_fokus &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional)
              Positioned(
                left: -inset,
                top: -inset,
                right: -inset,
                bottom: -inset,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: m.tinta,
                          width: AppUkuran.garisTebal,
                        ),
                      ),
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

/// Teks butir yang tidak tampak: lihat catatan di [FloatingNavBar]. Memenuhi
/// butir (ikut menerima ketukan), tidak menggambar apa pun, tidak masuk
/// semantik.
class _LabelGaib extends StatelessWidget {
  const _LabelGaib({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0,
          child: ExcludeSemantics(
            child: Text(teks, maxLines: 1, overflow: TextOverflow.clip),
          ),
        ),
      ),
    );
  }
}
