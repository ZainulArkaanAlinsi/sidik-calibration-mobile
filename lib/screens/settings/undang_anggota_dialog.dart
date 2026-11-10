import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/undangan_pelanggan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart';
import '../../services/auth_service.dart' show AuthException;

/// Alur "Undang anggota": dialog isian (email + peran) lalu dialog kode.
///
/// Aturan peran ditegakkan SERVER (403 untuk non-admin); pemanggil hanya
/// menyembunyikan tombolnya. Kode undangan cuma ada di respons pembuatan dan
/// tidak bisa dibaca lagi, jadi dialog kode tidak menyimpannya di mana pun.
Future<void> bukaUndangAnggota(BuildContext context, Customer pelanggan) async {
  final hasil = await showDialog<UndanganPelanggan>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogUndang(pelanggan: pelanggan),
  );
  if (hasil == null || !context.mounted) return;

  await showDialog<void>(
    context: context,
    // Kode tidak bisa dilihat lagi: jangan sampai tertutup karena ketukan
    // meleset di luar dialog.
    barrierDismissible: false,
    builder: (_) => DialogKodeUndangan(undangan: hasil),
  );
}

final _polaEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class _DialogUndang extends ConsumerStatefulWidget {
  const _DialogUndang({required this.pelanggan});

  final Customer pelanggan;

  @override
  ConsumerState<_DialogUndang> createState() => _DialogUndangState();
}

class _DialogUndangState extends ConsumerState<_DialogUndang> {
  final _kunci = GlobalKey<FormState>();
  final _email = TextEditingController();
  PeranUndangan _peran = PeranUndangan.staf;
  bool _mengirim = false;
  String? _galat;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    // Penjaga di PINTU fungsi, bukan hanya `onPressed: null` di tombol:
    // dua ketukan beruntun bisa tiba sebelum frame yang menonaktifkan tombol
    // sempat tergambar, dan undangan kedua membatalkan kode pertama.
    if (_mengirim) return;
    if (!(_kunci.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _mengirim = true;
      _galat = null;
    });

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      final hasil = await ref
          .read(undanganPelangganServiceProvider)
          .undang(
            token,
            widget.pelanggan.id,
            email: _email.text.trim(),
            peran: _peran,
          );
      if (!mounted) return;
      Navigator.of(context).pop(hasil);
    } on TokenHilangException {
      if (!mounted) return;
      setState(() {
        _mengirim = false;
        _galat = l10n.historySessionExpired;
      });
    } catch (e) {
      if (!mounted) return;
      // Pesan 422/403 dari server (AuthException) tampil apa adanya; galat
      // lain (mis. FormatException) bukan untuk dibaca pengguna.
      final pesan = e is AuthException && e.message.isNotEmpty
          ? e.message
          : l10n.undangGagalUmum;
      setState(() {
        _mengirim = false;
        _galat = pesan;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.undangJudul(widget.pelanggan.nama)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _kunci,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('undang-email'),
                  controller: _email,
                  enabled: !_mengirim,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.undangEmail),
                  validator: (v) {
                    final teks = (v ?? '').trim();
                    if (teks.isEmpty) return l10n.undangEmailKosong;
                    if (!_polaEmail.hasMatch(teks)) {
                      return l10n.undangEmailTidakValid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.undangPeran, style: tema.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<PeranUndangan>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: PeranUndangan.picUtama,
                      label: Text(l10n.undangPeranPic),
                    ),
                    ButtonSegment(
                      value: PeranUndangan.staf,
                      label: Text(l10n.undangPeranStaf),
                    ),
                  ],
                  selected: {_peran},
                  onSelectionChanged: _mengirim
                      ? null
                      : (s) => setState(() => _peran = s.first),
                ),
                if (_galat != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _galat!,
                    key: const Key('undang-galat'),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _mengirim ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.undangBatal),
        ),
        FilledButton(
          key: const Key('undang-kirim'),
          onPressed: _mengirim ? null : _kirim,
          child: _mengirim
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.undangKirim),
        ),
      ],
    );
  }
}

/// Dialog besar yang menampilkan KODE undangan sekali saja.
///
/// Publik supaya bisa diuji langsung tanpa melewati dialog isian.
class DialogKodeUndangan extends StatelessWidget {
  const DialogKodeUndangan({super.key, required this.undangan});

  final UndanganPelanggan undangan;

  Future<void> _salin(BuildContext context, String kode) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: kode));
    messenger.showSnackBar(SnackBar(content: Text(l10n.undangDisalin)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final kode = undangan.kode;
    final berlaku = undangan.berlakuSampai;

    return AlertDialog(
      title: Text(l10n.undangKodeJudul),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.undangKodeUntuk(undangan.email),
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (kode == null || kode.isEmpty)
                Container(
                  key: const Key('undang-tanpa-kode'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    l10n.undangTanpaKode,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSecondaryContainer,
                    ),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: tema.colorScheme.outlineVariant),
                  ),
                  child: SelectableText(
                    kode,
                    key: const Key('undang-kode'),
                    textAlign: TextAlign.center,
                    style: SidikTheme.gayaAngka(
                      ukuran: 40,
                      berat: FontWeight.w700,
                      warna: tema.colorScheme.onSurface,
                    ).copyWith(letterSpacing: 6),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('undang-salin'),
                    onPressed: () => _salin(context, kode),
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(l10n.undangSalin),
                  ),
                ),
                if (berlaku != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.undangBerlaku(
                      DateFormat('d MMM yyyy', locale).format(berlaku),
                    ),
                    key: const Key('undang-berlaku'),
                    style: tema.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.undangPeringatan,
                  key: const Key('undang-peringatan'),
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tema.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.undangPetunjukPelanggan,
                key: const Key('undang-petunjuk'),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.undangTutup),
        ),
      ],
    );
  }
}
