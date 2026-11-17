import 'dart:math' as math;

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

/// Kunci kapsul biru muda butir aktif, untuk tes.
const Key kunciIndikatorBilah = ValueKey<String>('bilah-indikator');

/// Bilah navigasi bawah Lab (HP), solid (REVISI 16 Nov 2026, R1).
///
/// Nama kelasnya peninggalan (dulu dock melayang berbentuk pil, lalu panel
/// logam); dipertahankan karena `MainShell` dan tes memanggilnya. Kontrak
/// `selectedIndex` / `onSelected` / `items` / `aksiTengah` TIDAK berubah.
///
/// ## Bentuk
///
/// Permukaan putih (`kertas`) selebar layar, garis 1 dp di atasnya, TANPA
/// bayangan dan tanpa sudut (dulu pil melayang 16 dp di atas tepi dengan
/// bayangan navy). Tepi sistem (gesture bar) ada DI DALAM permukaan, jadi
/// tidak ada celah di bawah bilah.
///
/// - SEMUA butir berlabel (ikon 24 + satu baris kata 12). Dulu hanya butir
///   aktif yang bertulisan.
/// - Butir AKTIF = kapsul kabut 56 x 32 di belakang ikon terisi + kata
///   semibold navy; butir lain ikon garis dan kata medium tinta kedua. Aktif
///   tidak hanya dibedakan warna: bentuk ikon, berat huruf, dan kapsul ikut
///   berubah.
/// - [aksiTengah] (Mulai di bilah teknisi) disisipkan di tengah daftar
///   [items], datar (tanpa bayangan), 48 dp.
/// - Papan ketik terbuka: bilah disembunyikan (isian tidak kehilangan ~64 dp).
///
/// ## Lebar sempit
///
/// Butir sama lebar. Label mengikuti huruf sistem (dijepit 1,3x), lalu SEMUA
/// label mengecil bersama (satu faktor, ukuran sama di tiap butir, tidak pernah
/// di bawah 12 sp efektif) sampai kata terpanjang (berat terpilih, yang
/// terlebar) muat di selnya, sehingga tidak ada kata yang terpotong di 320 dp.
/// Bila masih tidak muat, kata diskalakan turun (FittedBox), tidak dipotong.
///
/// Tiap butir SATU simpul pembaca layar (label, `selected`, "Tab n dari m").
/// Seluruh butir, selebar selnya dan setinggi bilah, menerima ketukan. Papan
/// ketik: Tab berpindah butir, Enter/Spasi memilih, cincin fokus muncul di
/// dalam sel.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.aksiTengah,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingNavItem> items;

  /// Tombol di tengah bilah (Mulai kalibrasi). Dipasang di antara butir
  /// `items.length ~/ 2 - 1` dan `items.length ~/ 2`; untuk dua butir = tepat di
  /// tengah. Pemanggil yang menentukan aksi dan labelnya.
  final Widget? aksiTengah;

  /// Skala huruf label dijepit sampai sini; di atasnya semua label mengecil
  /// bersama sampai muat.
  static const double skalaLabelMaks = 1.3;

  /// Bantalan kiri-kanan tiap sel yang tak boleh dipakai kata.
  static const double _sisaSel = AppSpacing.xs;

  /// Ruang di kiri-kanan [aksiTengah] di dalam baris.
  static const double _celahTengah = AppSpacing.sm;

  /// Berat huruf label (terpilih terlebar, dipakai untuk mengukur).
  static const FontWeight _beratTerpilih = FontWeight.w600;
  static const FontWeight _beratBiasa = FontWeight.w500;

  /// Gaya dasar label: 12/16, warna dipasang pemakai.
  static TextStyle _gayaDasar(BuildContext context) =>
      (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
        fontSize: 12,
        height: 16 / 12,
      );

  /// Skala huruf label yang dipakai SEMUA butir pada lebar [lebarSel] per sel:
  /// huruf sistem (sudah dijepit [skalaLabelMaks]) dikali faktor <= 1 supaya
  /// kata terpanjang muat, tetapi tidak pernah di bawah 12 sp efektif.
  double _skalaLabel(BuildContext context, double lebarSel) {
    final dasar = _gayaDasar(context).copyWith(fontWeight: _beratTerpilih);
    final ukuran = dasar.fontSize ?? 12;
    final sistem = MediaQuery.textScalerOf(context).scale(ukuran) / ukuran;
    var terlebar = 0.0;
    for (final item in items) {
      final ukur = TextPainter(
        text: TextSpan(text: item.label, style: dasar),
        textDirection: Directionality.of(context),
        textScaler: TextScaler.linear(sistem),
        maxLines: 1,
      )..layout();
      terlebar = math.max(terlebar, ukur.width);
      ukur.dispose();
    }
    final muat = lebarSel - _sisaSel;
    final faktor = terlebar <= muat || terlebar == 0 ? 1.0 : muat / terlebar;
    // Tidak di bawah 12 sp efektif: faktor minimum = 1 / sistem (bila sistem
    // > 1) dan 1 (bila sistem sudah 1).
    final minimum = sistem > 1 ? 1 / sistem : 1.0;
    return sistem * math.max(faktor, minimum);
  }

  @override
  Widget build(BuildContext context) {
    // Papan ketik terbuka: bilah turun dari layar. Dibaca dari `View` (jendela
    // sungguhan), BUKAN `MediaQuery`: `Scaffold` memotong `viewInsets` untuk
    // body-nya, dan bilah bisa saja dipasang di sana.
    if (View.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    final m = SidikMaterial.of(context);
    final tepiSistem = MediaQuery.paddingOf(context).bottom;
    final sisip = items.length ~/ 2;
    final lebarTengah = aksiTengah == null
        ? 0.0
        : UkuranBiruAwan.tombolMulaiDock + 2 * _celahTengah;
    final aktif = selectedIndex.clamp(0, items.length - 1);

    return Material(
      color: m.kertas,
      child: DecoratedBox(
        key: const ValueKey('dock'),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: m.kertasTepi, width: AppUkuran.garis),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: tepiSistem),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: skalaLabelMaks,
            // LayoutBuilder DI LUAR IntrinsicHeight (ia tidak bisa menjawab
            // ukuran intrinsik).
            child: LayoutBuilder(
              builder: (context, batas) {
                final lebarSel = (batas.maxWidth - lebarTengah) / items.length;
                final skala = _skalaLabel(context, lebarSel);
                final anak = <Widget>[];
                for (var i = 0; i < items.length; i++) {
                  if (aksiTengah != null && i == sisip) {
                    anak.add(
                      SizedBox(
                        width: lebarTengah,
                        child: Center(child: aksiTengah),
                      ),
                    );
                  }
                  anak.add(
                    Expanded(
                      child: _Butir(
                        key: ValueKey('dock-butir-$i'),
                        item: items[i],
                        nomor: i + 1,
                        jumlah: items.length,
                        aktif: i == aktif,
                        skalaLabel: skala,
                        onTap: () => onSelected(i),
                      ),
                    ),
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: anak,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu butir bilah: ikon di atas kapsul, kata di bawahnya. Lihat
/// [FloatingNavBar] untuk semantik dan ukuran.
class _Butir extends StatefulWidget {
  const _Butir({
    super.key,
    required this.item,
    required this.nomor,
    required this.jumlah,
    required this.aktif,
    required this.skalaLabel,
    required this.onTap,
  });

  final FloatingNavItem item;
  final int nomor;
  final int jumlah;
  final bool aktif;

  /// Skala huruf label, sama untuk semua butir.
  final double skalaLabel;
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
    final durasi = AppMotion.hormati(context, AppMotion.kilat);
    final gayaLabel = FloatingNavBar._gayaDasar(context).copyWith(
      color: aktif ? m.tinta : m.tinta2,
      fontWeight: aktif
          ? FloatingNavBar._beratTerpilih
          : FloatingNavBar._beratBiasa,
    );

    final kapsul = AnimatedContainer(
      key: aktif ? kunciIndikatorBilah : null,
      duration: durasi,
      curve: AppMotion.masuk,
      width: UkuranBiruAwan.kapsulBilahLebar,
      height: UkuranBiruAwan.kapsulBilahTinggi,
      decoration: BoxDecoration(
        color: aktif ? m.biruTipis : Colors.transparent,
        borderRadius: BorderRadius.circular(BentukBiruAwan.saringan),
      ),
      child: Center(
        child: Icon(
          aktif ? widget.item.activeIcon : widget.item.icon,
          size: UkuranKomponenBiruAwan.ikonBilah,
          color: aktif ? m.biruTinta : m.tinta2,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: aktif,
      label: widget.item.label,
      hint: l10n.navLabTabHint(widget.nomor, widget.jumlah),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: TekanSkala(
        child: Stack(
          // Seluruh sel menerima ketukan: `expand` memberi Material ukuran sel
          // penuh (Stack longgar menyusutkannya ke isi), dan `ColoredBox`
          // transparan (hit-test opak) membuat bantalan kosong di sekitar
          // kapsul dan kata ikut menanggapi (InkWell hanya menanggapi bagian
          // yang berisi).
          fit: StackFit.expand,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (v) => setState(() => _fokus = v),
                child: ColoredBox(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: UkuranBiruAwan.tinggiBilah,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          kapsul,
                          const SizedBox(height: AppSpacing.xs),
                          // Tanpa jarak kiri-kanan: kata sudah dimuatkan ke
                          // sel (lihat `_skalaLabel`); FittedBox hanya jaring
                          // terakhir.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.item.label,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.linear(widget.skalaLabel),
                              style: gayaLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Cincin fokus papan ketik: di DALAM sel (sel bersebelahan, tak ada
            // ruang di luar), navy (`tinta`) terhadap putih bilah >= 3:1.
            if (_fokus &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional)
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs / 2),
                    child: DecoratedBox(
                      key: kunciCincinFokusBilah,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          BentukBiruAwan.saringan,
                        ),
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: m.tinta,
                            width: AppUkuran.garisTebal,
                          ),
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

/// Kunci cincin fokus butir bilah, untuk tes.
const Key kunciCincinFokusBilah = ValueKey<String>('bilah-cincin-fokus');
