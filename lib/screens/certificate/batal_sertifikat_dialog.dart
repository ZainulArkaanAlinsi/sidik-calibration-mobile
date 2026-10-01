import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../models/revisi_sertifikat.dart';
import '../../providers/certificate_provider.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Konfirmasi pembatalan sertifikat (admin; kontrak A3).
///
/// Pembatalan FINAL — tidak ada "batalkan pembatalan" — dan tidak menghidupkan
/// pendahulu yang sudah digantikan. Karena itu dialog ini bergaya merusak
/// (tombol merah) dan menampilkan dampaknya ke jadwal kalibrasi ulang alat:
///
/// - `jadwal_dikosongkan` → peringatan: satu-satunya sertifikat sah alat ini.
/// - `jatuh_ke` → info: jadwal alat kembali mengikuti sertifikat sebelumnya.
///
/// Aksinya dijalankan di dalam dialog, bukan oleh pemanggil, supaya galat 422
/// tampil di tempat (dialog tetap terbuka, isiannya tidak hilang). Menutup
/// dengan `true` = berhasil dibatalkan.
class BatalSertifikatDialog extends ConsumerStatefulWidget {
  const BatalSertifikatDialog({super.key, required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  ConsumerState<BatalSertifikatDialog> createState() =>
      _BatalSertifikatDialogState();
}

class _BatalSertifikatDialogState extends ConsumerState<BatalSertifikatDialog> {
  final _alasan = TextEditingController();
  final _catatan = TextEditingController();
  bool _sibuk = false;
  String? _galatAlasan;
  String? _galatCatatan;
  String? _banner;

  @override
  void dispose() {
    _alasan.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (_sibuk) return;
    if (_alasan.text.trim().isEmpty) {
      setState(() => _galatAlasan = l10n.batalAlasanWajib);
      return;
    }

    setState(() {
      _sibuk = true;
      _galatAlasan = null;
      _galatCatatan = null;
      _banner = null;
    });
    try {
      await ref
          .read(sertifikatAksiProvider)
          .batalkan(
            widget.sertifikat.id,
            alasan: _alasan.text,
            catatanPelanggan: _catatan.text,
          );
      navigator.pop(true);
    } on GalatAksi catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galatAlasan = e.untuk('alasan');
        _galatCatatan = e.untuk('catatan_pelanggan');
        // Galat keadaan (`{message}` tanpa `errors`): sudah digantikan, dst.
        _banner = e.adaGalatIsian ? null : e.pesan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _banner = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final dampak = widget.sertifikat.dampakPembatalan;

    return AlertDialog(
      key: const ValueKey('dialog-batal-sertifikat'),
      icon: Icon(Icons.block, color: m.gagal),
      title: Text(l10n.batalJudul(widget.sertifikat.nomor)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.batalPenjelasan, style: theme.textTheme.bodyMedium),
          if (dampak != null && dampak.jadwalDikosongkan) ...[
            const SizedBox(height: AppSpacing.md),
            _Kotak(
              key: const ValueKey('peringatan-jadwal-dikosongkan'),
              ikon: Icons.warning_amber_rounded,
              warna: m.awas,
              latar: m.awasTipis,
              teks: l10n.batalJadwalDikosongkan,
            ),
          ] else if (dampak?.jatuhKe != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Kotak(
              key: const ValueKey('info-jatuh-ke'),
              ikon: Icons.info_outline,
              warna: m.tunggu,
              latar: m.tungguTipis,
              teks: l10n.batalJatuhKe(
                dampak!.jatuhKe!.nomor,
                dampak.jatuhKe!.berlakuSampai == null
                    ? '—'
                    : tanggalPendek(
                        context,
                        DateTime.tryParse(dampak.jatuhKe!.berlakuSampai!),
                      ),
              ),
            ),
          ],
          if (_banner != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Kotak(
              key: const ValueKey('banner-batal'),
              ikon: Icons.error_outline,
              warna: m.gagal,
              latar: m.gagalTipis,
              teks: _banner!,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('isian-batal-alasan'),
            controller: _alasan,
            enabled: !_sibuk,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_galatAlasan != null) setState(() => _galatAlasan = null);
            },
            decoration: InputDecoration(
              labelText: l10n.batalAlasan,
              helperText: l10n.batalAlasanHelper,
              helperMaxLines: 2,
              errorText: _galatAlasan,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('isian-batal-catatan'),
            controller: _catatan,
            enabled: !_sibuk,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.batalCatatan,
              helperText: l10n.batalCatatanHelper,
              helperMaxLines: 2,
              errorText: _galatCatatan,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sibuk ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.custCancel),
        ),
        FilledButton(
          key: const ValueKey('kirim-batal-sertifikat'),
          style: FilledButton.styleFrom(
            backgroundColor: m.gagal,
            foregroundColor: Colors.white,
          ),
          onPressed: _sibuk ? null : _kirim,
          child: _sibuk
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.batalKirim),
        ),
      ],
    );
  }
}

class _Kotak extends StatelessWidget {
  const _Kotak({
    super.key,
    required this.ikon,
    required this.warna,
    required this.latar,
    required this.teks,
  });

  final IconData ikon;
  final Color warna;
  final Color latar;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              teks,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: warna),
            ),
          ),
        ],
      ),
    );
  }
}
