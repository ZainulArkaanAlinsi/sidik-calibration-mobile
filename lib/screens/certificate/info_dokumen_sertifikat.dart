import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../models/revisi_sertifikat.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Lencana label dokumen. Ikon + teks, tidak pernah warna saja.
StatusSidik statusDokumen(AppLocalizations l10n, StatusDokumen s) =>
    switch (s) {
      StatusDokumen.berlaku => StatusSidik(
        l10n.sertDokBerlaku,
        NadaStatus.lulus,
        Icons.verified_outlined,
      ),
      StatusDokumen.digantikan => StatusSidik(
        l10n.sertDokDigantikan,
        NadaStatus.awas,
        Icons.swap_horiz,
      ),
      StatusDokumen.dibatalkan => StatusSidik(
        l10n.sertDokDibatalkan,
        NadaStatus.gagal,
        Icons.block,
      ),
      StatusDokumen.belumTerbit => StatusSidik(
        l10n.sertDokBelumTerbit,
        NadaStatus.tunggu,
        Icons.hourglass_empty,
      ),
    };

/// Kartu status dokumen di atas detail sertifikat (kontrak A1): lencana,
/// info revisi (tautan ke pendahulu / pengganti), dan info pembatalan.
///
/// Semua field baru boleh kosong (server lama) — kartunya tetap menampilkan
/// lencana turunan dari `status`, tanpa baris yang tak punya isi.
class InfoDokumenSertifikat extends StatelessWidget {
  const InfoDokumenSertifikat({
    super.key,
    required this.sertifikat,
    required this.onBuka,
  });

  final CertificateDetail sertifikat;

  /// Dipanggil dengan id sertifikat tujuan (pendahulu / pengganti).
  final ValueChanged<int> onBuka;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final s = sertifikat;
    final dari = s.revisiDari;
    final oleh = s.digantikanOleh;
    final batal = s.statusDokumen == StatusDokumen.dibatalkan;

    final tglBatal = s.dibatalkanPada?.toLocal();

    return Kertas(
      key: const ValueKey('info-dokumen-sertifikat'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sertDokStatus.toUpperCase(),
                  style: m.gayaEtsa(ukuran: 11),
                ),
              ),
              SidikLencana(statusDokumen(l10n, s.statusDokumen)),
            ],
          ),

          if (s.adalahRevisi) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  dari == null
                      ? l10n.sertDokRevisiKe(s.revisiKe)
                      : '${l10n.sertDokRevisiKe(s.revisiKe)} · ${l10n.sertDokMenggantikan} ',
                  style: theme.textTheme.bodyMedium,
                ),
                if (dari != null)
                  _Tautan(
                    key: const ValueKey('tautan-revisi-dari'),
                    teks: dari.nomor,
                    onTap: () => onBuka(dari.id),
                  ),
              ],
            ),
            if (s.alasanRevisi != null && s.alasanRevisi!.isNotEmpty)
              _Baris(label: l10n.sertDokAlasanRevisi, isi: s.alasanRevisi!),
          ],

          if (oleh != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  '${l10n.sertDokDigantikanOleh} ',
                  style: theme.textTheme.bodyMedium,
                ),
                _Tautan(
                  key: const ValueKey('tautan-digantikan-oleh'),
                  teks: oleh.nomor,
                  onTap: () => onBuka(oleh.id),
                ),
                // Revisi yang belum terbit tampil bersama statusnya, supaya
                // "digantikan" tidak terbaca seolah penggantinya sudah siap.
                if (oleh.status != null && oleh.status != 'terbit')
                  SidikLencana.dariApi(oleh.status),
              ],
            ),
          ],

          if (batal) ...[
            const SizedBox(height: AppSpacing.sm),
            if (tglBatal != null)
              _Baris(
                label: l10n.sertDokDibatalkanPada,
                isi: tanggalPendek(context, tglBatal),
              ),
            if (s.dibatalkanOleh != null)
              _Baris(label: l10n.sertDokDibatalkanOleh, isi: s.dibatalkanOleh!),
            if (s.alasanPembatalan != null && s.alasanPembatalan!.isNotEmpty)
              _Baris(
                label: l10n.sertDokAlasanInternal,
                isi: s.alasanPembatalan!,
                warna: m.gagal,
              ),
          ],

          if (s.catatanPelanggan != null && s.catatanPelanggan!.isNotEmpty)
            _Baris(label: l10n.sertDokCatatanPelanggan, isi: s.catatanPelanggan!),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.isi, this.warna});

  final String label;
  final String isi;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
          Text(
            isi,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: warna),
          ),
        ],
      ),
    );
  }
}

/// Nomor sertifikat yang bisa diketuk. Angka pakai lebar digit tetap.
class _Tautan extends StatelessWidget {
  const _Tautan({super.key, required this.teks, required this.onTap});

  final String teks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          teks,
          style: SidikTheme.gayaAngka(
            ukuran: 14,
            berat: FontWeight.w600,
            warna: m.biru,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
