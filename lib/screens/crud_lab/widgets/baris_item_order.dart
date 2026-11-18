import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order_kelola.dart';
import 'kolom_pilih_crud.dart';

/// Satu alat di form order: nama + nomor seri, pemilih teknisi, dan rincian
/// penerimaan (kondisi, kelengkapan, catatan) yang bisa dibuka-tutup.
///
/// Controller teks hidup di sini (dikunci `ValueKey(alatId)` oleh pemanggil),
/// jadi menghapus satu baris tidak menggeser isian baris lain.
class BarisItemOrder extends StatefulWidget {
  const BarisItemOrder({
    super.key,
    required this.item,
    required this.saatUbah,
    required this.saatBuang,
    required this.saatPilihTeknisi,
    this.galat,
    this.aktif = true,
  });

  final ItemOrderForm item;
  final ValueChanged<ItemOrderForm> saatUbah;
  final VoidCallback saatBuang;
  final VoidCallback saatPilihTeknisi;

  /// Pesan server untuk baris ini (`items.N.*`).
  final String? galat;
  final bool aktif;

  @override
  State<BarisItemOrder> createState() => _BarisItemOrderState();
}

class _BarisItemOrderState extends State<BarisItemOrder> {
  late final _kondisi = TextEditingController(text: widget.item.kondisiTerima);
  late final _kelengkapan = TextEditingController(
    text: widget.item.kelengkapan,
  );
  late final _catatan = TextEditingController(text: widget.item.catatan);

  @override
  void dispose() {
    _kondisi.dispose();
    _kelengkapan.dispose();
    _catatan.dispose();
    super.dispose();
  }

  void _teksBerubah() => widget.saatUbah(
    widget.item.salin(
      kondisiTerima: _kondisi.text,
      kelengkapan: _kelengkapan.text,
      catatan: _catatan.text,
    ),
  );

  Widget _kolom(
    String label,
    TextEditingController c, {
    required int batas,
    int maksBaris = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        label: label,
        child: TextField(
          controller: c,
          enabled: widget.aktif,
          minLines: 1,
          maxLines: maksBaris,
          keyboardType: TextInputType.multiline,
          inputFormatters: [LengthLimitingTextInputFormatter(batas)],
          onChanged: (_) => _teksBerubah(),
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final alat = widget.item;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alat.namaAlat,
                        style: tema.textTheme.titleSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (alat.serialNumber.isNotEmpty)
                        Text(
                          alat.serialNumber,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('buang-${alat.alatId}'),
                  tooltip: l10n.crudOrderBuangAlat(alat.namaAlat),
                  icon: const Icon(Icons.close),
                  onPressed: widget.aktif ? widget.saatBuang : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: KotakPilihCrud(
                label: l10n.crudItemTeknisi,
                petunjuk: l10n.crudItemTanpaTeknisi,
                nilai: alat.namaTeknisi,
                saatTekan: widget.saatPilihTeknisi,
                aktif: widget.aktif,
              ),
            ),
            if (widget.galat != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs, right: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.galat!,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ),
              ),
            Theme(
              data: tema.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: Key('rincian-${alat.alatId}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                ),
                title: Text(
                  l10n.crudItemRincian,
                  style: tema.textTheme.labelLarge,
                ),
                children: [
                  _kolom(l10n.crudItemKondisi, _kondisi, batas: 1000),
                  _kolom(
                    l10n.crudItemKelengkapan,
                    _kelengkapan,
                    batas: 255,
                    maksBaris: 2,
                  ),
                  _kolom(l10n.crudItemCatatan, _catatan, batas: 1000),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
