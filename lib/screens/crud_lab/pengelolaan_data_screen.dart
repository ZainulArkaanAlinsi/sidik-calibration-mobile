import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/readable_width.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'arsip_draf_screen.dart';
import 'hak_crud_lab.dart';
import 'kategori_kelola_screen.dart';
import 'order_list_screen.dart';
import 'penugasan_kelola_screen.dart';

/// Pintu ke pengelolaan data lab (Order, Penugasan, Kategori alat, Arsip
/// draf) — satu-satunya layar yang dibuka dari baris baru di Kelola lab.
///
/// Tiap pintu ikut izin server sendiri-sendiri; pintu yang tidak diizinkan
/// tidak digambar. Gaya barisnya sama dengan Kelola lab dan hub Super Admin
/// (kartu bergaris pemisah, ikon logam di kiri).
class PengelolaanDataScreen extends ConsumerWidget {
  const PengelolaanDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehPengelolaanData;

    final pintu = <_Pintu>[
      if (ref.bolehKelolaOrder)
        _Pintu(
          key: const Key('pintu-order'),
          ikon: Icons.receipt_long_outlined,
          judul: l10n.crudHubOrderJudul,
          keterangan: l10n.crudHubOrderSub,
          layar: () => const OrderListScreen(),
        ),
      if (ref.bolehUbahPenugasan || ref.bolehBatalkanPenugasan)
        _Pintu(
          key: const Key('pintu-penugasan'),
          ikon: Icons.assignment_outlined,
          judul: l10n.crudHubPenugasanJudul,
          keterangan: l10n.crudHubPenugasanSub,
          layar: () => const PenugasanKelolaScreen(),
        ),
      if (ref.bolehKelolaKategori)
        _Pintu(
          key: const Key('pintu-kategori'),
          ikon: Icons.category_outlined,
          judul: l10n.crudHubKategoriJudul,
          keterangan: l10n.crudHubKategoriSub,
          layar: () => const KategoriKelolaScreen(),
        ),
      if (ref.bolehPulihkanDraf)
        _Pintu(
          key: const Key('pintu-arsip-draf'),
          ikon: Icons.inventory_2_outlined,
          judul: l10n.crudHubArsipJudul,
          keterangan: l10n.crudHubArsipSub,
          layar: () => const ArsipDrafScreen(),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudHubJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : ReadableWidth(
                maksimum: 720,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (pintu.isEmpty)
                      PesanLayar(
                        ikon: Icons.lock_outline,
                        teks: l10n.crudHubKosong,
                      )
                    else
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < pintu.length; i++) ...[
                              if (i > 0) const Divider(height: 1, indent: 72),
                              _BarisPintu(pintu: pintu[i]),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Pintu {
  const _Pintu({
    required this.key,
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.layar,
  });

  final Key key;
  final IconData ikon;
  final String judul;
  final String keterangan;
  final Widget Function() layar;
}

class _BarisPintu extends StatelessWidget {
  const _BarisPintu({required this.pintu});

  final _Pintu pintu;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Semantics(
      button: true,
      child: InkWell(
        key: pintu.key,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => pintu.layar())),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: m.logamTimbul(radius: 9),
                  child: ExcludeSemantics(
                    child: Icon(pintu.ikon, size: 20, color: m.etsa),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pintu.judul, style: tema.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        pintu.keterangan,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
