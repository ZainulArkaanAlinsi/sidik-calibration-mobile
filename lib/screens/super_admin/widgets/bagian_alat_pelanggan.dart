import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/customer.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/riwayat_alat_provider.dart';
import '../riwayat_sertifikat_alat_screen.dart';
import '../../../widgets/app_button.dart';
import '../hak_super_admin.dart';
import '../pindahkan_alat_screen.dart';
import 'kartu_alat.dart';
import 'kerangka_kursor.dart';

/// Bagian "Alat pelanggan" di detail pelanggan (sliver): alat dimuat per
/// halaman kursor saat gulir mendekati ujung, dengan tombol Muat lebih banyak
/// sebagai jalan cadangan (pembaca layar, daftar yang pendek). Mengetuk alat
/// membuka riwayat sertifikatnya: pelanggan → alat → sertifikat.
class BagianAlatPelanggan extends ConsumerWidget {
  const BagianAlatPelanggan({super.key, required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tanpa izin `pelanggan.alat-lihat` bagian ini TIDAK ada, dan server tidak
    // ditanya (provider alat tidak dibuat).
    if (!ref.bolehLihatAlatPelanggan) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final bolehRiwayat = ref.bolehLihatRiwayatSertifikat;
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final provider = alatPelangganProvider(pelanggan.id);
    final async = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final daftar = async.value;

    // Pindahkan alat: izin sendiri (`pelanggan.pindah-alat`), dan hanya bila
    // ada alat untuk dipindah.
    final bisaPindah =
        ref.bolehPindahAlat && daftar != null && daftar.items.isNotEmpty;

    final judul = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.saAlatJudul, style: tema.textTheme.titleMedium),
            ),
            if (bisaPindah) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('pindahkan-alat'),
                label: l10n.saPindahTombol,
                icon: Icons.drive_file_move_outline,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                onPressed: () async {
                  final berhasil = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => PindahkanAlatScreen(asal: pelanggan),
                    ),
                  );
                  if (berhasil == true) ctl.muatUlang();
                },
              ),
            ],
          ],
        ),
      ),
    );

    if (daftar == null) {
      if (async.hasError) {
        final galat = async.error!;
        return SliverMainAxisGroup(
          slivers: [
            judul,
            SliverToBoxAdapter(
              child: PesanInlineKursor(
                key: const Key('alat-galat'),
                teks: galat is TokenHilangException
                    ? l10n.historySessionExpired
                    : pesanDaftarKursor(l10n, galat, l10n.saAlatGagal),
                saatCoba: ctl.muatUlang,
              ),
            ),
          ],
        );
      }
      return SliverMainAxisGroup(
        slivers: [
          judul,
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: KerangkaKartuKursor(),
            ),
          ),
        ],
      );
    }

    if (daftar.items.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          judul,
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l10n.saAlatKosong,
                key: const Key('alat-kosong'),
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        judul,
        SliverList.builder(
          itemCount: daftar.items.length,
          itemBuilder: (context, i) {
            final a = daftar.items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KartuAlatRingkas(
                alat: a,
                // Riwayat sertifikat punya izin sendiri (`alat.riwayat-sertifikat`).
                saatTekan: bolehRiwayat
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RiwayatSertifikatAlatScreen(alat: a),
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: KakiDaftarKursor(
            memuatLagi: daftar.memuatLagi,
            galat: daftar.galatLanjut == null
                ? null
                : pesanDaftarKursor(
                    l10n,
                    daftar.galatLanjut!,
                    l10n.saAlatLanjutGagal,
                  ),
            adaLagi: daftar.adaLagi,
            saatMuat: () => ctl.muatLebihBanyak(paksa: true),
          ),
        ),
      ],
    );
  }
}
