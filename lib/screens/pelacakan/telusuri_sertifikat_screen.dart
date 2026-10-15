import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/revisi_sertifikat.dart' show StatusDokumen;
import '../../models/telusuri_sertifikat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart' show pdfDownloaderProvider;
import '../../providers/pengendalian_provider.dart';
import '../../services/buka_berkas.dart';
import '../../services/pdf_downloader.dart';
import '../../widgets/readable_width.dart';
import 'pelacakan_screen.dart';

/// Telusuri No. Sertifikat — pencarian nomor di server (K-50-05). Menggantikan
/// "Pelacakan paket" sebagai pintu menu; tampilan tahap paket tetap bisa
/// dibuka dari tiap hasil lewat [PelacakanScreen].
class TelusuriSertifikatScreen extends ConsumerStatefulWidget {
  const TelusuriSertifikatScreen({super.key});

  @override
  ConsumerState<TelusuriSertifikatScreen> createState() =>
      _TelusuriSertifikatScreenState();
}

class _TelusuriSertifikatScreenState
    extends ConsumerState<TelusuriSertifikatScreen> {
  static const _minHuruf = 2;

  final _cari = TextEditingController();
  Timer? _jeda;
  int _urutan = 0;
  String _kataKunci = '';
  bool _memuat = false;
  bool _gagal = false;
  List<TelusuriSertifikat> _hasil = const [];

  @override
  void dispose() {
    _jeda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _berubah(String q) {
    _jeda?.cancel();
    final kata = q.trim();
    if (kata.length < _minHuruf) {
      _urutan++;
      setState(() {
        _kataKunci = '';
        _hasil = const [];
        _memuat = false;
        _gagal = false;
      });
      return;
    }
    _jeda = Timer(const Duration(milliseconds: 300), () => _jalankan(kata));
  }

  Future<void> _jalankan(String kata) async {
    final urutan = ++_urutan;
    setState(() {
      _kataKunci = kata;
      _memuat = true;
      _gagal = false;
    });
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw StateError('token hilang');
      final hasil = await ref.read(telusuriServiceProvider).cari(token, kata);
      // Jawaban yang datang telat dari ketikan lama dibuang.
      if (!mounted || urutan != _urutan) return;
      setState(() {
        _hasil = hasil;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted || urutan != _urutan) return;
      setState(() {
        _hasil = const [];
        _memuat = false;
        _gagal = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final Widget isi;
    if (_kataKunci.isEmpty) {
      isi = _Pesan(ikon: Icons.manage_search, teks: l10n.telusuriPetunjuk);
    } else if (_memuat) {
      isi = const Center(child: CircularProgressIndicator());
    } else if (_gagal) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: l10n.telusuriGagal,
        onCobaLagi: () => _jalankan(_kataKunci),
      );
    } else if (_hasil.isEmpty) {
      isi = _Pesan(ikon: Icons.search_off, teks: l10n.telusuriKosong);
    } else {
      isi = ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: _hasil.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _KartuHasil(item: _hasil[i]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.telusuriJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _cari,
                autofocus: true,
                onChanged: _berubah,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.telusuriCari,
                ),
              ),
            ),
            Expanded(child: isi),
          ],
        ),
      ),
    );
  }
}

String labelTahapPaket(AppLocalizations l10n, String kode) => switch (kode) {
  'diterima' => l10n.tahapDiterima,
  'dikalibrasi' => l10n.tahapDikalibrasi,
  'menunggu_pemeriksaan' => l10n.tahapMenungguPemeriksaan,
  'menunggu_pengesahan' => l10n.tahapMenungguPengesahan,
  'sertifikat_terbit' => l10n.tahapSertifikatTerbit,
  'siap_diambil' => l10n.tahapSiapDiambil,
  'diserahkan' => l10n.tahapDiserahkan,
  _ => kode,
};

/// Label status dari `status_dokumen` + `revisi_ke`, bukan dari `id`.
String labelStatusTelusuri(AppLocalizations l10n, TelusuriSertifikat s) {
  final dasar = switch (s.statusDokumen) {
    StatusDokumen.berlaku => l10n.telusuriStatusBerlaku,
    StatusDokumen.ditarik => l10n.telusuriStatusDitarik,
    StatusDokumen.digantikan => l10n.telusuriStatusDigantikan,
    StatusDokumen.dibatalkan => l10n.telusuriStatusDibatalkan,
    StatusDokumen.belumTerbit => l10n.telusuriStatusBelumTerbit,
  };
  return s.revisiKe == null ? dasar : '$dasar · R${s.revisiKe}';
}

class _KartuHasil extends ConsumerStatefulWidget {
  const _KartuHasil({required this.item});

  final TelusuriSertifikat item;

  @override
  ConsumerState<_KartuHasil> createState() => _KartuHasilState();
}

class _KartuHasilState extends ConsumerState<_KartuHasil> {
  bool _sibuk = false;

  Future<void> _bukaPdf() async {
    final url = widget.item.pdfUrl;
    if (_sibuk || url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _sibuk = true);
    try {
      final path = await ref
          .read(pdfDownloaderProvider)
          .unduh(token, url, namaFile: '${widget.item.nomor}.pdf');
      final gagal = await bukaBerkas(path);
      if (gagal != null && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(gagal)));
      }
    } on PdfDownloadException catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  void _lihatPaket() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PelacakanScreen(cariAwal: widget.item.perusahaan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final s = widget.item;

    final warna = switch (s.statusDokumen) {
      StatusDokumen.berlaku => AppColors.statusSukses(context),
      StatusDokumen.belumTerbit ||
      StatusDokumen.digantikan => theme.colorScheme.onSurfaceVariant,
      _ => AppColors.statusPeringatan(context),
    };
    final alat = [
      if (s.alat != null) s.alat!,
      if (s.merk != null) s.merk!,
      if (s.serialNumber != null) 'S/N ${s.serialNumber}',
    ].join(' · ');

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
                    s.nomor,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  labelStatusTelusuri(l10n, s),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: warna,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (s.perusahaan != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(s.perusahaan!, style: theme.textTheme.bodyMedium),
            ],
            if (alat.isNotEmpty)
              Text(
                alat,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (s.tahapPaket != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.telusuriTahap(labelTahapPaket(l10n, s.tahapPaket!)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (s.bisaBukaPdf)
                  OutlinedButton.icon(
                    onPressed: _sibuk ? null : _bukaPdf,
                    icon: _sibuk
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.telusuriBukaPdf),
                  ),
                if (s.tahapPaket != null && s.perusahaan != null)
                  TextButton.icon(
                    onPressed: _lihatPaket,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(l10n.telusuriLihatPaket),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.onCobaLagi});

  final IconData ikon;
  final String teks;
  final VoidCallback? onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(teks, textAlign: TextAlign.center),
            if (onCobaLagi != null)
              TextButton(
                onPressed: onCobaLagi,
                child: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}
