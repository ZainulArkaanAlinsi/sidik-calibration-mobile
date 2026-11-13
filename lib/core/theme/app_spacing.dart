import 'bentuk_lab.dart';

/// Skala jarak & sudut. Dipakai biar spasi antar layar konsisten —
/// jangan nulis `EdgeInsets.all(13)` random di widget.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Sudut membulat komponen, dipetakan ke set bentuk Lab (`BentukLab`):
  /// kecil = panel 8, sedang = kontrol 10, besar = panel 8.
  ///
  /// Nama lama dipertahankan (35 berkas memakainya). `radiusLg` bukan lagi
  /// "lebih besar dari Md": pemakainya kartu dan panel, jadi nilainya panel 8
  /// supaya sama dengan kartu tema.
  static const double radiusSm = BentukLab.panel;
  static const double radiusMd = BentukLab.kontrol;
  static const double radiusLg = BentukLab.panel;
}
