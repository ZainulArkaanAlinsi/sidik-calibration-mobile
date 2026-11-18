import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/customer_lookup.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/master_data_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/skeleton.dart';
import '../../super_admin/widgets/pesan_layar.dart';
import 'kerangka_sheet_pilih.dart';

/// Pemilih pelanggan (PT) dari daftar lookup lab (`GET /customers/lookup`,
/// dicari server lewat `?search=`). Mengembalikan `null` bila ditutup.
Future<CustomerLookup?> pilihPelangganCrud(BuildContext context) =>
    bukaSheetPilih<CustomerLookup>(
      context,
      bangun: (_) => const _PilihPelangganSheet(),
    );

class _PilihPelangganSheet extends ConsumerStatefulWidget {
  const _PilihPelangganSheet();

  @override
  ConsumerState<_PilihPelangganSheet> createState() =>
      _PilihPelangganSheetState();
}

class _PilihPelangganSheetState extends ConsumerState<_PilihPelangganSheet> {
  final _cari = TextEditingController();
  Timer? _debounce;
  String _kata = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _cariBerubah(String kata) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _kata = kata.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final async = ref.watch(customerLookupProvider(_kata));

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
            : l10n.crudOrderPelangganGagal,
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.invalidate(customerLookupProvider(_kata)),
        ),
      ),
      data: (hasil) {
        if (hasil.daftar.isEmpty) {
          return PesanLayar(
            ikon: Icons.business_outlined,
            teks: l10n.crudOrderPelangganKosong,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: hasil.daftar.length,
          itemBuilder: (context, i) {
            final pt = hasil.daftar[i];
            final alamat = (pt.alamat ?? '').trim();
            return ListTile(
              key: Key('pt-${pt.id}'),
              minVerticalPadding: 8,
              leading: const ExcludeSemantics(child: Icon(Icons.business)),
              title: Text(pt.nama, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: alamat.isEmpty
                  ? null
                  : Text(
                      alamat,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall,
                    ),
              onTap: () => Navigator.of(context).pop(pt),
            );
          },
        );
      },
    );

    return KerangkaSheetPilih(
      judul: l10n.crudOrderPilihPelanggan,
      cari: _cari,
      saatCari: _cariBerubah,
      petunjukCari: l10n.crudOrderCariPelanggan,
      isi: isi,
    );
  }
}
