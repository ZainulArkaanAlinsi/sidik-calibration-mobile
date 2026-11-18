import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment_lookup.dart';

/// Hasil [tampilkanPilihAlatRingkas]. Menutup lembar tanpa memilih = `null`
/// (alur berhenti, belum ada lembar yang dibuka).
sealed class HasilPilihAlatRingkas {
  const HasilPilihAlatRingkas();
}

/// Teknisi mengetuk satu alat.
class AlatDipilih extends HasilPilihAlatRingkas {
  const AlatDipilih(this.alat);

  final EquipmentLookup alat;
}

/// Teknisi memilih alat nanti, di lembar kerja.
class AlatNanti extends HasilPilihAlatRingkas {
  const AlatNanti();
}

/// Daftar alat PENDEK untuk jenis lembar yang sudah dikenali: SATU ketukan
/// memilih, tanpa pemilih kategori -> alat. Daftarnya `GET /equipments?profil=`
/// (sudah disaring server ke jenis ini), jadi alat lain tidak muncul.
///
/// Lembar baru dibuka SESUDAH alat dipilih supaya titik ukur dan bentuk
/// lembarnya langsung lahir dari alat itu (kunci formulir memakai id alat).
Future<HasilPilihAlatRingkas?> tampilkanPilihAlatRingkas(
  BuildContext context, {
  required String jenis,
  required List<EquipmentLookup> alat,
}) => showModalBottomSheet<HasilPilihAlatRingkas>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PilihAlatRingkasSheet(jenis: jenis, alat: alat),
);

class PilihAlatRingkasSheet extends StatefulWidget {
  const PilihAlatRingkasSheet({
    super.key,
    required this.jenis,
    required this.alat,
  });

  final String jenis;
  final List<EquipmentLookup> alat;

  /// Di atas jumlah ini kotak cari muncul.
  static const batasKotakCari = 8;

  static const kunciPesan = ValueKey('pa-pesan');
  static const kunciCari = ValueKey('pa-cari');
  static const kunciNanti = ValueKey('pa-nanti');

  static ValueKey<String> kunciBaris(int id) => ValueKey('pa-baris-$id');

  @override
  State<PilihAlatRingkasSheet> createState() => _PilihAlatRingkasSheetState();
}

class _PilihAlatRingkasSheetState extends State<PilihAlatRingkasSheet> {
  String _kata = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    final kata = _kata.trim().toLowerCase();
    final tampil = [
      for (final a in widget.alat)
        if (kata.isEmpty ||
            '${a.namaAlat} ${a.serialNumber} ${a.pelangganNama}'
                .toLowerCase()
                .contains(kata))
          a,
    ];

    return SafeArea(
      child: Padding(
        // Papan ketik tidak boleh menutup kotak cari dan daftarnya.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pindaiPilihAlatJudul,
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.pindaiPilihAlatPesan(widget.jenis, widget.alat.length),
                  key: PilihAlatRingkasSheet.kunciPesan,
                ),
                if (widget.alat.length >
                    PilihAlatRingkasSheet.batasKotakCari) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: PilihAlatRingkasSheet.kunciCari,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.pindaiCariAlat,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _kata = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                for (final a in tampil)
                  ListTile(
                    key: PilihAlatRingkasSheet.kunciBaris(a.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.namaAlat),
                    subtitle: Text(
                      [
                        a.serialNumber,
                        if (a.pelangganNama.isNotEmpty) a.pelangganNama,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, AlatDipilih(a)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: PilihAlatRingkasSheet.kunciNanti,
                  onPressed: () => Navigator.pop(context, const AlatNanti()),
                  child: Text(l10n.pindaiPilihAlatNanti),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
