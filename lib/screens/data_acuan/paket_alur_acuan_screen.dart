import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'alur_versi_acuan_screen.dart';
import 'widgets/keadaan_acuan.dart';

/// Pintu aplikasi lab ke alur versi data acuan (admin & super admin): pilih
/// paket → [AlurVersiAcuanScreen] dengan aksi tulis.
///
/// Menu jelajah Data Acuan sendiri tetap di Sidik Studio (keputusan 9 Okt
/// 2026); aplikasi lab hanya memuat pintu ini, karena rute tulis alur
/// menolak token Studio dan butuh orang kedua (BR-08).
class PaketAlurAcuanScreen extends StatelessWidget {
  const PaketAlurAcuanScreen({super.key});

  @override
  Widget build(BuildContext context) => GerbangDataAcuan(
    judul: AppLocalizations.of(context).alurAcuanJudul,
    child: const _DaftarPaketAlur(),
  );
}

class _DaftarPaketAlur extends ConsumerWidget {
  const _DaftarPaketAlur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final daftar = ref.watch(daftarPaketAcuanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alurAcuanJudul)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(daftarPaketAcuanProvider.future),
        child: daftar.when(
          loading: () => const KerangkaDaftarAcuan(),
          error: (e, _) => GalatAcuan(
            galat: e,
            onCobaLagi: () => ref.invalidate(daftarPaketAcuanProvider),
          ),
          data: (paket) {
            final diimpor = paket.where((p) => p.diimpor).toList();
            if (diimpor.isEmpty) {
              return KeadaanAcuan(
                ikon: Icons.dataset_outlined,
                judul: l10n.acuanPaketKosong,
              );
            }
            return ReadableWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final p in diimpor)
                    Kertas(
                      key: ValueKey('paket-alur-${p.kode}'),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AlurVersiAcuanScreen(kode: p.kode, nama: p.nama),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nama, style: theme.textTheme.titleSmall),
                                if (p.versiAktif != null)
                                  LencanaVersiAcuan(p.versiAktif!.kodeStatus),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: m.tinta2),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
