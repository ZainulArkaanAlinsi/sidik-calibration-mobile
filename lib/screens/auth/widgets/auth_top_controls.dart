import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/locale_provider.dart';
import '../../../providers/theme_mode_provider.dart';
import 'neu.dart';

/// Baris kontrol di atas layar auth: pemilih bahasa + toggle dark mode —
/// bergaya neumorphism, ngikutin gambar acuan ("English ⌄" + "Dark Mode").
class AuthTopControls extends ConsumerWidget {
  const AuthTopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = NeuColors.of(context);
    final locale = ref.watch(localeProvider);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final isId = locale.languageCode == 'id';

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pemilih bahasa.
        _Pill(
          onTap: () => ref.read(localeProvider.notifier).toggle(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: c.textMuted),
              const SizedBox(width: 6),
              Text(
                isId ? 'Indonesia' : 'English',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 18, color: c.textMuted),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Toggle dark mode.
        _Pill(
          circle: true,
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .toggle(gelapSekarang: gelap),
          child: Icon(
            gelap ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 18,
            color: c.text,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.onTap, this.circle = false});

  final Widget child;
  final VoidCallback onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuRaised(
        circle: circle,
        radius: 20,
        distance: 3,
        blur: 7,
        padding: circle
            ? const EdgeInsets.all(9)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}
