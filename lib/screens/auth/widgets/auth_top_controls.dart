import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/locale_provider.dart';
import '../../../widgets/sakelar_tema.dart';
import 'neu.dart';

/// Baris kontrol di atas layar auth: pemilih bahasa + toggle dark mode —
/// bergaya neumorphism, ngikutin gambar acuan ("English ⌄" + "Dark Mode").
class AuthTopControls extends ConsumerWidget {
  const AuthTopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = NeuColors.of(context);
    final locale = ref.watch(localeProvider);
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
        const SizedBox(width: 4),
        // Toggle dark mode. Sengaja nggak dibungkus NeuRaised: treknya udah
        // punya bentuk sendiri, bayangan neumorphism di atasnya cuma bikin
        // pinggirannya kotor.
        const SakelarTema(),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuRaised(
        radius: 20,
        distance: 3,
        blur: 7,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}
