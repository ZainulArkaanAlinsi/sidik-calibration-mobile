import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/sidik_material.dart';
import '../l10n/app_localizations.dart';
import '../models/koreksi_pelanggan.dart';
import '../providers/koreksi_provider.dart';

/// Deretan thumbnail foto pelat nama yang dikirim pelanggan.
///
/// Gambarnya ditarik lewat [fotoPelangganProvider] — `GET /foto-pelanggan/{id}`
/// dengan header `Authorization` yang sama seperti panggilan API lain. Bukan
/// `Image.network`: itu tidak membawa token, jadi server menjawab 401 dan
/// gambarnya tidak pernah muncul. Ketuk thumbnail → tampilan penuh yang bisa
/// dicubit.
class DeretFotoPelanggan extends StatelessWidget {
  const DeretFotoPelanggan({super.key, required this.foto, this.ukuran = 76});

  final List<FotoPelanggan> foto;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    if (foto.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final f in foto) FotoPelangganMini(foto: f, ukuran: ukuran),
      ],
    );
  }
}

class FotoPelangganMini extends ConsumerWidget {
  const FotoPelangganMini({super.key, required this.foto, this.ukuran = 76});

  final FotoPelanggan foto;
  final double ukuran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final async = ref.watch(fotoPelangganProvider(foto.id));
    final bytes = async.value;

    final Widget isi;
    if (bytes != null) {
      isi = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: ukuran,
        height: ukuran,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Kosong(ukuran: ukuran),
      );
    } else if (async.hasError || async.hasValue) {
      // Gagal ditarik atau 404: kotak berikon, tetap bisa diketuk ulang.
      isi = _Kosong(ukuran: ukuran);
    } else {
      isi = Container(width: ukuran, height: ukuran, color: m.kertas2);
    }

    return Semantics(
      button: true,
      label: l10n.fotoPelangganBuka,
      child: InkWell(
        key: ValueKey('foto-pelanggan-${foto.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: bytes == null
            ? () => ref.invalidate(fotoPelangganProvider(foto.id))
            : () => _bukaPenuh(context, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: isi,
        ),
      ),
    );
  }

  static void _bukaPenuh(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  key: const ValueKey('tutup-foto-pelanggan'),
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.ukuran});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Container(
      width: ukuran,
      height: ukuran,
      color: m.kertas2,
      child: Icon(Icons.broken_image_outlined, color: m.tinta2),
    );
  }
}
