import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Kotak abu-abu pengganti konten yang lagi dimuat.
///
/// Sengaja **diam, tanpa animasi shimmer**. Dua alasannya: (1) shimmer yang
/// muter terus bikin widget test nggak pernah "settle" — tesnya jadi hang,
/// (2) buat data yang cuma sebentar dimuat, kedipan shimmer malah bikin layar
/// kelihatan gelisah. Bentuknya niru layout aslinya, jadi waktu data masuk,
/// posisinya nggak loncat-loncat.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = AppSpacing.radiusSm,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
