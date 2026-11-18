import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/alat_pelanggan.dart';
import '../../../widgets/status_badge.dart';

/// Lencana status alat dari `status_alat` server — kode yang SAMA dengan yang
/// dilihat pelanggan di aplikasinya (`terkalibrasi`, `mendekati_jadwal`,
/// `lewat_jadwal`, `belum_pernah`, `nonaktif`). Klien tidak menghitung ulang
/// "mendekati jadwal". Server lama tanpa `status_alat` jatuh ke kosakata lab
/// (`aktif`, `overdue`, `nonaktif`); kode asing tampil apa adanya.
class LencanaStatusAlat extends StatelessWidget {
  const LencanaStatusAlat({super.key, required this.alat});

  final AlatRingkas alat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final (String, BadgeTone, IconData)? dikenal = switch (alat.statusAlat) {
      'terkalibrasi' => (
        l10n.saAlatStatusTerkalibrasi,
        BadgeTone.success,
        Icons.verified_outlined,
      ),
      'mendekati_jadwal' => (
        l10n.saAlatStatusMendekati,
        BadgeTone.warning,
        Icons.schedule,
      ),
      'lewat_jadwal' => (
        l10n.saAlatStatusLewat,
        BadgeTone.danger,
        Icons.event_busy_outlined,
      ),
      'belum_pernah' => (
        l10n.saAlatStatusBelum,
        BadgeTone.info,
        Icons.help_outline,
      ),
      'nonaktif' => (
        l10n.saAlatStatusNonaktif,
        BadgeTone.neutral,
        Icons.block_outlined,
      ),
      _ => null,
    };

    if (dikenal != null) {
      return StatusBadge(label: dikenal.$1, tone: dikenal.$2, icon: dikenal.$3);
    }
    // Kode asing dari server baru tampil apa adanya, bukan disembunyikan.
    if (alat.statusAlat != null) {
      return StatusBadge(label: alat.statusAlat!, tone: BadgeTone.neutral);
    }
    return StatusBadge.fromApi(alat.status);
  }
}
