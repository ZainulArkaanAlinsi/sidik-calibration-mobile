import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/readable_width.dart';
import 'ganti_sandi_screen.dart';
import 'hak_super_admin.dart';
import 'pelanggan_sa_screen.dart';
import 'pengguna_screen.dart';
import 'widgets/pesan_layar.dart';

/// Pintu ke pengelolaan Super Admin — satu-satunya layar yang dibuka dari
/// baris baru di Kelola lab.
///
/// Isinya tiga pintu, tiap pintu ikut izin server sendiri-sendiri:
/// Pengguna, Pelanggan & anggota, dan Ganti sandi saya. Gaya barisnya sama
/// dengan Kelola lab (kartu bergaris pemisah, ikon logam di kiri).
class PengelolaanSuperAdminScreen extends ConsumerWidget {
  const PengelolaanSuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehPengelolaanSa;

    final pintu = <_Pintu>[
      if (boleh && ref.bolehLihatPengguna)
        _Pintu(
          key: const Key('pintu-pengguna'),
          ikon: Icons.manage_accounts_outlined,
          judul: l10n.saHubPenggunaJudul,
          keterangan: l10n.saHubPenggunaSub,
          layar: () => const PenggunaScreen(),
        ),
      if (boleh && ref.bolehLihatAnggota)
        _Pintu(
          key: const Key('pintu-pelanggan'),
          ikon: Icons.business_outlined,
          judul: l10n.saHubPelangganJudul,
          keterangan: l10n.saHubPelangganSub,
          layar: () => const PelangganSaScreen(),
        ),
      if (boleh)
        _Pintu(
          key: const Key('pintu-ganti-sandi'),
          ikon: Icons.lock_reset,
          judul: l10n.saGantiJudul,
          keterangan: l10n.saHubGantiSub,
          layar: () => const GantiSandiScreen(),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saHubJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin)
            : ReadableWidth(
                maksimum: 720,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (pintu.isEmpty)
                      PesanLayar(
                        ikon: Icons.lock_outline,
                        teks: l10n.saHubKosong,
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
