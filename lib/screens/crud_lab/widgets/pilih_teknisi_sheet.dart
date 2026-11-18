import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/order_kelola_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/skeleton.dart';
import '../../super_admin/widgets/pesan_layar.dart';
import 'kerangka_sheet_pilih.dart';

/// Hasil pemilih teknisi. `id == null` = "Belum dibagi" (melepas teknisi).
typedef PilihanTeknisi = ({int? id, String? nama});

/// Pemilih teknisi AKTIF lab. `null` = ditutup tanpa memilih; pilihan
/// "Belum dibagi" mengembalikan `(id: null, nama: null)`.
Future<PilihanTeknisi?> pilihTeknisiCrud(
  BuildContext context, {
  int? terpilihId,
}) => bukaSheetPilih<PilihanTeknisi>(
  context,
  bangun: (_) => _PilihTeknisiSheet(terpilihId: terpilihId),
);

class _PilihTeknisiSheet extends ConsumerWidget {
  const _PilihTeknisiSheet({this.terpilihId});

  final int? terpilihId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(teknisiAktifProvider);

    final Widget isi = async.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: SkeletonBox(height: 48),
            ),
        ],
      ),
      error: (e, _) => PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: e is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.crudItemTeknisiGagal,
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.invalidate(teknisiAktifProvider),
        ),
      ),
      data: (teknisi) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          ListTile(
            key: const Key('teknisi-tanpa'),
            selected: terpilihId == null,
            leading: const ExcludeSemantics(child: Icon(Icons.person_off_outlined)),
            title: Text(l10n.crudItemTanpaTeknisi),
            onTap: () => Navigator.of(context).pop<PilihanTeknisi>(
              (id: null, nama: null),
            ),
          ),
          if (teknisi.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.crudItemTeknisiKosong),
            ),
          for (final t in teknisi)
            ListTile(
              key: Key('teknisi-${t.id}'),
              selected: terpilihId == t.id,
              leading: const ExcludeSemantics(child: Icon(Icons.badge_outlined)),
              title: Text(
                t.nama.trim().isEmpty ? t.email : t.nama,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: t.employeeId.isEmpty ? null : Text(t.employeeId),
              onTap: () => Navigator.of(context).pop<PilihanTeknisi>(
                (id: t.id, nama: t.nama.trim().isEmpty ? t.email : t.nama),
              ),
            ),
        ],
      ),
    );

    return KerangkaSheetPilih(judul: l10n.crudItemPilihTeknisi, isi: isi);
  }
}
