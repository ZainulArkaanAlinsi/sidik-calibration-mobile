import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Membuka lembar bawah pemilih (PT, alat, teknisi) yang aman untuk layar
/// pendek dan papan ketik: tingginya 90% layar, dan naik mengikuti papan
/// ketik supaya kolom cari + hasilnya tetap terlihat.
Future<T?> bukaSheetPilih<T>(
  BuildContext context, {
  required Widget Function(BuildContext) bangun,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (konteks) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(konteks).bottom),
      child: FractionallySizedBox(heightFactor: 0.9, child: bangun(konteks)),
    ),
  );
}

/// Isi lembar pemilih: judul, kolom cari (opsional), isi yang digulir, dan
/// tombol aksi bawah (opsional).
class KerangkaSheetPilih extends StatelessWidget {
  const KerangkaSheetPilih({
    super.key,
    required this.judul,
    required this.isi,
    this.cari,
    this.saatCari,
    this.petunjukCari,
    this.bawah,
  });

  final String judul;
  final Widget isi;
  final TextEditingController? cari;
  final ValueChanged<String>? saatCari;
  final String? petunjukCari;
  final Widget? bawah;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              judul,
              style: tema.textTheme.titleMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (cari != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Semantics(
              label: petunjukCari,
              child: TextField(
                key: const Key('cari-sheet'),
                controller: cari,
                onChanged: saatCari,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: petunjukCari,
                ),
              ),
            ),
          ),
        Expanded(child: isi),
        if (bawah != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: bawah,
            ),
          ),
      ],
    );
  }
}
