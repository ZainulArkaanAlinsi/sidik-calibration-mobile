import 'package:flutter/material.dart';

import 'tema_beku.dart';

/// Membekukan tampilan lembar kerja: semua yang di bawahnya membaca [TemaBeku]
/// (salinan tema 14 Nov 2026), bukan tema app (`docs/desain-ulang/BEKU.md`).
///
/// ## Di mana dipasang
///
/// Di SETIAP pemanggil yang membuka layar beku (`MaterialPageRoute`, `buka(...)`,
/// dan seterusnya), membungkus layarnya dari LUAR: `LembarKerjaScreen`,
/// `CalibrationInputScreen`, `SkemaDinamisScreen`, `TemperaturIndikatorGerbangScreen`,
/// `OnboardingScreen`, `SertifikatPdfView`, `TabelPerhitunganWidget`, `KeypadAngka`.
///
/// Sengaja dari luar, BUKAN di dalam `build` layar. `Theme.of(context)` dan
/// `showDialog(context: context)` yang ditulis di `State` layar memakai
/// `context` layar itu sendiri; pembungkus di dalam `build` berada di bawahnya
/// dan tidak menjangkaunya (subjudul dan gaya "5x" di app bar, dialog dari
/// `State`). Pembungkus dari luar menaruh `context` itu di bawah tema beku.
/// Pembungkus di akar juga memaksa tema produksi pada tes lama yang memasang
/// layar langsung di bawah `ThemeData` bawaan (`gerbang_cek_layar_test`,
/// `kepala_tabel_tidak_kepotong_test`) dan membuatnya gagal tanpa ada tampilan
/// produksi yang berubah. `test/beku/tema_beku_terpasang_test.dart` memindai
/// `lib/` dan gagal bila ada pemanggil yang lupa.
///
/// ## Selain tema
///
/// `MaterialApp` memasang `DefaultSelectionStyle` dari `colorScheme.primary`
/// tema app: warna kursor dan blok pilihan semua `TextField`. Itu berada DI
/// ATAS pembungkus ini, jadi tanpa pasangan di bawah, kursor lembar kerja ikut
/// berganti begitu `primary` app berganti. Rumusnya sama dengan
/// `_MaterialAppState._materialBuilder`.
///
/// Mode terang/gelap mengikuti tema di atasnya (`MaterialApp.themeMode`).
class BekuLembarKerja extends StatelessWidget {
  const BekuLembarKerja({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = TemaBeku.untuk(context);

    return Theme(
      data: tema,
      child: DefaultSelectionStyle(
        selectionColor:
            tema.textSelectionTheme.selectionColor ??
            tema.colorScheme.primary.withAlpha(102),
        cursorColor:
            tema.textSelectionTheme.cursorColor ?? tema.colorScheme.primary,
        child: child,
      ),
    );
  }
}
