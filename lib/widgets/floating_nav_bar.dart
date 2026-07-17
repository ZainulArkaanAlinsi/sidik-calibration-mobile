import 'package:flutter/material.dart';

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

/// Bottom nav "melayang" (floating pill) dengan lingkaran aktif yang **naik**
/// di atas bar dan **geser beranimasi** ke tab terpilih — ikon di dalamnya ikut
/// berganti mulus.
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

  static const _barHeight = 62.0;
  static const _circle = 52.0;
  static const _hMargin = 16.0;
  static const _bottom = 12.0;
  // Headroom di atas lingkaran buat bayangannya, biar nggak kepotong / overflow.
  static const _topPad = 10.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SizedBox(
        // Tinggi total = jarak bawah + bar + separuh lingkaran yang nongol +
        // headroom bayangan. Dihitung pas biar nggak ada 2px overflow.
        height: _bottom + _barHeight + _circle / 2 + _topPad,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth - _hMargin * 2;
            final itemWidth = barWidth / items.length;
            final circleLeft =
                _hMargin + itemWidth * (selectedIndex + 0.5) - _circle / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Pill bar.
                Positioned(
                  left: _hMargin,
                  right: _hMargin,
                  bottom: _bottom,
                  height: _barHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
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

                // Lingkaran aktif yang naik & geser.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  left: circleLeft,
                  bottom: _bottom + _barHeight - _circle / 2,
                  child: Container(
                    width: _circle,
                    height: _circle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      border: Border.all(color: scheme.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        items[selectedIndex].activeIcon,
                        key: ValueKey(selectedIndex),
                        color: scheme.onPrimary,
                        size: 23,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon disembunyiin waktu aktif — dia "naik" ke lingkaran di atas.
            SizedBox(
              height: 24,
              child: AnimatedOpacity(
                opacity: active ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Icon(item.icon, size: 23, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 2),
            // FittedBox scaleDown: label panjang ("Notification") otomatis
            // ngecil biar muat, nggak kepotong / bikin overflow horizontal.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  height: 1.0,
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
