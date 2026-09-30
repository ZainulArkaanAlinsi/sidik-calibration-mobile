import 'package:flutter/material.dart';

import '../core/theme/sidik_material.dart';

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

/// Navigasi bawah HP — sekarang PANEL LOGAM yang menempel di bawah layar.
///
/// Nama kelasnya peninggalan (dulu pil kaca melayang dengan lingkaran biru
/// bercahaya yang naik ke atas bar). Dipertahankan karena `MainShell`
/// memanggilnya; kontrak `selectedIndex` / `onSelected` / `items` tidak berubah.
///
/// ## Kenapa bukan kaca & lingkaran bercahaya lagi
///
/// 1. **Kaca di navigasi dilarang di sistem ini.** `BackdropFilter` di bar
///    yang SELALU tampil memaksa lapisan offscreen tiap frame — sumber lag
///    paling nyata di HP kelas bawah yang dipakai teknisi di lapangan. Kaca
///    bening cuma untuk benda yang mengambang sebentar (sheet, dialog).
/// 2. **Lingkaran biru yang bersinar** adalah ciri tampilan "AI" yang
///    dikeluhkan pemilik proyek, dan dia MENYEMBUNYIKAN ikon tab aktif dari
///    barisnya sendiri — mata harus melompat ke atas bar untuk tahu sedang
///    di mana.
/// 3. Bar melayang setinggi 110 px memakan layar; panel ini 64 px + area aman.
///
/// Tab aktif = tombol yang TERTEKAN masuk ke panel, plus satu LED kecil di
/// atasnya. Dua penanda, bukan cuma warna — kebaca juga oleh mata buta warna.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingNavItem> items;

  static const _tinggi = 64.0;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return DecoratedBox(
      decoration: m.logamPanel(
        border: Border(top: BorderSide(color: m.logamTepi)),
      ).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: m.terang ? 0.18 : 0.5),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _tinggi,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _Item(
                      item: items[i],
                      active: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.active, required this.onTap});

  final FloatingNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final durasi = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: durasi,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: active
              ? m.logamTertekan(radius: 9)
              : const BoxDecoration(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // LED tab aktif. Kecil, satu warna, tanpa halo — penanda posisi,
              // bukan dekorasi.
              if (active)
                Positioned(
                  top: 3,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: m.biruTinta,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? item.activeIcon : item.icon,
                      size: 22,
                      color: active ? m.biruTinta : m.etsa,
                    ),
                    const SizedBox(height: 3),
                    // FittedBox scaleDown: label panjang ("Notification") ngecil
                    // biar muat, bukan kepotong. Teksnya TIDAK di-uppercase di
                    // sini — label dari l10n dipakai apa adanya supaya test yang
                    // mencarinya tetap menemukan teks yang sama.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          height: 1.0,
                          letterSpacing: 0.3,
                          color: m.etsa,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
