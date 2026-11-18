import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/alat_pelanggan.dart';
import '../../../widgets/status_badge.dart';

/// Lencana keadaan sertifikat: ikon + kata + warna (bukan warna saja — hasil
/// kalibrasi dibaca juga oleh orang yang buta warna).
class LencanaSertifikat extends StatelessWidget {
  const LencanaSertifikat({super.key, required this.keadaan});

  final KeadaanSertifikat keadaan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, nada, ikon) = switch (keadaan) {
      KeadaanSertifikat.terbit => (
        l10n.saSertTerbit,
        BadgeTone.success,
        Icons.verified_outlined,
      ),
      KeadaanSertifikat.digantikan => (
        l10n.saSertDigantikan,
        BadgeTone.neutral,
        Icons.swap_horiz,
      ),
      KeadaanSertifikat.ditarik => (
        l10n.saSertDitarik,
        BadgeTone.warning,
        Icons.undo,
      ),
      KeadaanSertifikat.dibatalkan => (
        l10n.saSertDibatalkan,
        BadgeTone.danger,
        Icons.do_not_disturb_on_outlined,
      ),
      KeadaanSertifikat.gagal => (
        l10n.saSertGagal,
        BadgeTone.danger,
        Icons.error_outline,
      ),
      KeadaanSertifikat.menunggu => (
        l10n.saSertMenunggu,
        BadgeTone.info,
        Icons.hourglass_empty,
      ),
    };
    return StatusBadge(label: label, tone: nada, icon: ikon);
  }
}
