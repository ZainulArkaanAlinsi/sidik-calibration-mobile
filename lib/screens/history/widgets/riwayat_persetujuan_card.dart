import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/peristiwa_persetujuan.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/riwayat_persetujuan_provider.dart';

/// Bagian "Riwayat persetujuan" di detail sesi — tiap penolakan beserta
/// alasannya, pengajuan ulang, persetujuan.
///
/// **Khusus admin & super admin** (keputusan pemilik proyek 6 Okt 2026). Untuk
/// peran lain bagian ini tidak digambar dan endpoint-nya tidak pernah dipanggil
/// (server juga menolaknya 403).
///
/// **Dimuat saat dibuka**, bukan saat layar detail dibuka: kebanyakan kunjungan
/// ke detail sesi tidak butuh riwayat, dan memanggil server di tiap kunjungan
/// cuma menambah beban (dan menggantung timer di test layar detail).
class RiwayatPersetujuanBagian extends ConsumerStatefulWidget {
  const RiwayatPersetujuanBagian({super.key, required this.sesiId});

  final int sesiId;

  static bool bolehLihat(UserRole? peran) => peran == UserRole.admin || peran == UserRole.superAdmin;

  @override
  ConsumerState<RiwayatPersetujuanBagian> createState() => _RiwayatPersetujuanBagianState();
}

class _RiwayatPersetujuanBagianState extends ConsumerState<RiwayatPersetujuanBagian> {
  bool _dibuka = false;

  @override
  Widget build(BuildContext context) {
    // Peran dibaca dari sesi login yang SUDAH hidup — tidak menyalakannya.
    // Di aplikasi `authProvider` selalu hidup sejak login; menyalakannya dari
    // sini di layar yang belum memakainya ikut memulai pemeriksaan sesi ke
    // server (timer menggantung di test layar detail, 6 Okt 2026).
    if (!ref.exists(authProvider)) return const SizedBox.shrink();
    final peran = ref.watch(authProvider).value?.role;
    if (!RiwayatPersetujuanBagian.bolehLihat(peran)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return Card(
      key: const ValueKey('riwayat-persetujuan'),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text(l10n.riwayatPersetujuanJudul),
        subtitle: Text(l10n.riwayatPersetujuanKetuk),
        onExpansionChanged: (buka) {
          if (buka && !_dibuka) setState(() => _dibuka = true);
        },
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          if (_dibuka)
            ref.watch(riwayatPersetujuanProvider(widget.sesiId)).when(
              data: (daftar) => RiwayatPersetujuanCard(daftar: daftar),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l10n.riwayatPersetujuanGagal),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(riwayatPersetujuanProvider(widget.sesiId)),
                  child: Text(l10n.riwayatPersetujuanCobaLagi),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Isi riwayat dari daftar yang sudah ada — dipisah dari pengambilannya
/// supaya bisa diuji tanpa jaringan.
class RiwayatPersetujuanCard extends StatelessWidget {
  const RiwayatPersetujuanCard({super.key, required this.daftar});

  final List<PeristiwaPersetujuan> daftar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final jumlahTolak = daftar.where((p) => p.ditolak).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.riwayatPersetujuanRingkas(jumlahTolak), style: theme.textTheme.titleSmall),
        if (daftar.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(l10n.riwayatPersetujuanKosong),
          )
        else
          for (final p in daftar) _Peristiwa(peristiwa: p, theme: theme, l10n: l10n),
      ],
    );
  }
}

class _Peristiwa extends StatelessWidget {
  const _Peristiwa({required this.peristiwa, required this.theme, required this.l10n});

  final PeristiwaPersetujuan peristiwa;
  final ThemeData theme;
  final AppLocalizations l10n;

  String get _judul => switch (peristiwa.jenis) {
    'ditolak' => l10n.riwayatJenisDitolak,
    'diajukan' => l10n.riwayatJenisDiajukan,
    'diajukan_ulang' => l10n.riwayatJenisDiajukanUlang,
    'disetujui' => l10n.riwayatJenisDisetujui,
    'menunggu_pengesahan' => l10n.riwayatJenisMenungguPengesahan,
    'kembali_ke_draft' => l10n.riwayatJenisKembaliDraft,
    _ => peristiwa.jenis,
  };

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final waktu = peristiwa.waktu == null
        ? '—'
        : DateFormat('d MMM yyyy HH:mm', locale).format(peristiwa.waktu!);
    final ditolak = peristiwa.ditolak;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: ditolak ? AppColors.danger : theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_judul, style: theme.textTheme.titleSmall),
              Text(
                '$waktu · ${peristiwa.olehNama ?? l10n.riwayatOlehSistem}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (ditolak && (peristiwa.alasan ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(peristiwa.alasan!),
          ],
          if (ditolak && peristiwa.kolom.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.riwayatKolomDitandai(peristiwa.kolom.join(', ')),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
