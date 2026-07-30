import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/kirim_email.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/kirim_email_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';

/// Kirim sertifikat ke email pelanggan + riwayat percobaannya — **admin doang**.
class KirimEmailScreen extends ConsumerWidget {
  const KirimEmailScreen({
    super.key,
    required this.certificateId,
    required this.nomorSertifikat,
  });

  final int certificateId;
  final String nomorSertifikat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.bolehkah(
      NamaIzin.sertifikatKirim,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emailTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                nomorSertifikat,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: admin
          ? _Isi(certificateId: certificateId)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.emailHanyaAdmin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Isi extends ConsumerStatefulWidget {
  const _Isi({required this.certificateId});

  final int certificateId;

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  final _ke = TextEditingController();
  final _cc = TextEditingController();

  bool _mengirim = false;
  String? _errorKe;
  String? _errorCc;

  @override
  void dispose() {
    _ke.dispose();
    _cc.dispose();
    super.dispose();
  }

  /// "a@b.com, c@d.com" → daftar alamat, kosong dibuang.
  List<String> _pisah(String teks) => teks
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Divalidasi longgar — cukup mastiin ada `@` dan titik sesudahnya. Validasi
  /// email yang ketat sering nolak alamat yang sah, dan yang berwenang nolak
  /// beneran tetap server.
  static final _polaEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _periksa(List<String> alamat, {required bool wajib}) {
    final l10n = AppLocalizations.of(context);

    if (alamat.isEmpty) {
      return wajib ? l10n.emailKeKosong : null;
    }
    if (alamat.length > KirimEmailPermintaan.maksAlamat) {
      return l10n.emailKebanyakan(KirimEmailPermintaan.maksAlamat);
    }
    for (final a in alamat) {
      if (!_polaEmail.hasMatch(a)) return l10n.emailAlamatSalah(a);
    }
    return null;
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ke = _pisah(_ke.text);
    final cc = _pisah(_cc.text);

    setState(() {
      _errorKe = _periksa(ke, wajib: true);
      _errorCc = _periksa(cc, wajib: false);
    });
    if (_errorKe != null || _errorCc != null) return;

    setState(() => _mengirim = true);
    try {
      await kirimSertifikatLewatEmail(
        ref,
        certificateId: widget.certificateId,
        isi: KirimEmailPermintaan(ke: ke, cc: cc),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.emailTerkirim)));
      _ke.clear();
      _cc.clear();
    } catch (e) {
      if (!mounted) return;
      // Pesan server apa adanya. Buat `502`, yang penting kebaca admin itu
      // "gagal TAPI tercatat" — bukan sekadar "gagal".
      final teks = e.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(
        SnackBar(content: Text(teks.isEmpty ? l10n.emailGagalMuat : teks)),
      );
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final riwayat = ref.watch(riwayatEmailProvider(widget.certificateId));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          controller: _ke,
          enabled: !_mengirim,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.emailKeLabel,
            hintText: l10n.emailKeHint,
            errorText: _errorKe,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _cc,
          enabled: !_mengirim,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.emailCcLabel,
            errorText: _errorCc,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.emailPisahKoma(KirimEmailPermintaan.maksAlamat),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: l10n.emailKirim,
          icon: Icons.send_outlined,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : _kirim,
        ),

        // Kirimnya SINKRON — nunggu server email beneran nerima, bukan cuma
        // masuk antrean. Bisa makan waktu, jadi alasannya ditulis biar admin
        // nggak ngira app-nya nge-hang lalu mencet dua kali.
        if (_mengirim) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.emailMengirim,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(l10n.emailRiwayatJudul, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),

        switch (riwayat) {
          AsyncData(:final value) => value.isEmpty
              ? Text(
                  l10n.emailRiwayatKosong,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final p in value) _BarisRiwayat(percobaan: p),
                  ],
                ),
          AsyncError() => _GagalRiwayat(
            onCobaLagi: () => ref.invalidate(
              riwayatEmailProvider(widget.certificateId),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

/// Satu percobaan kirim. **Yang gagal ikut ditampilin** — itu justru yang
/// dicari waktu pelanggan ngaku nggak nerima sertifikatnya.
class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.percobaan});

  final PercobaanEmail percobaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final waktu = DateFormat('d MMM yyyy · HH:mm', locale)
        .format(percobaan.waktu);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    percobaan.ke.join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: percobaan.berhasil
                      ? l10n.emailRiwayatBerhasil
                      : l10n.emailRiwayatGagal,
                  tone: percobaan.berhasil
                      ? BadgeTone.success
                      : BadgeTone.danger,
                  icon: percobaan.berhasil
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
              ],
            ),
            if (percobaan.cc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Cc: ${percobaan.cc.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              percobaan.oleh == null
                  ? waktu
                  : '$waktu · ${l10n.emailRiwayatOleh(percobaan.oleh!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Alasan gagalnya ditampilin apa adanya — "mailbox penuh" beda
            // penanganan dari "alamat nggak ada", dan admin yang mutusin.
            if (!percobaan.berhasil && percobaan.error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                percobaan.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GagalRiwayat extends StatelessWidget {
  const _GagalRiwayat({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Text(l10n.emailGagalMuat, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.emailRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
