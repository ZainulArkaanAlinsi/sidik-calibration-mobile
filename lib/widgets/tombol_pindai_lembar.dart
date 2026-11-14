import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../providers/kesiapan_pindai_lembar_provider.dart';
import '../providers/worksheet_scan_provider.dart';
import '../screens/pindai/pindai_lembar_flow.dart';
import 'app_button.dart';

/// Tombol kedua "Pindai lembar kerja", dipasang di bawah "Mulai kalibrasi" di
/// tiga beranda (teknisi, admin, super admin).
///
/// Menyembunyikan dirinya sendiri (`SizedBox.shrink`, tanpa ruang) kecuali
/// KEDUANYA terpenuhi: saklar `pindaiLembarAktifProvider` menyala DAN daftar
/// jenis lembar server (`kesiapanPindaiLembarProvider`, di-cache sesi) memuat
/// minimal satu jenis yang boleh dipindai. Memuat, gagal, tanpa koneksi, daftar
/// kosong, atau tidak ada yang boleh = tidak tampil, tanpa pesan galat: jalur
/// "Mulai kalibrasi" tidak terpengaruh. Pemasang tidak perlu memeriksa apa pun
/// kecuali PERAN (viewer tidak diberi tombol ini oleh layarnya).
///
/// Tampilannya sengaja polos (tombol sekunder + satu baris keterangan, hanya
/// token): susunan akhirnya dirapikan paket desain beranda.
class TombolPindaiLembar extends ConsumerStatefulWidget {
  const TombolPindaiLembar({
    super.key,
    this.jarakAtas = AppSpacing.sm,
    this.setelahKembali,
  });

  /// Jarak dari widget di atasnya; ikut hilang bersama tombolnya.
  final double jarakAtas;

  /// Dipanggil sesudah lembar kerja yang dibuka dari sini ditutup.
  final Future<void> Function()? setelahKembali;

  static const kunciTombol = ValueKey('tombol-pindai-lembar');

  @override
  ConsumerState<TombolPindaiLembar> createState() => _TombolPindaiLembarState();
}

class _TombolPindaiLembarState extends ConsumerState<TombolPindaiLembar> {
  /// Satu alur pada satu waktu: kamera yang lambat terbuka tidak boleh
  /// melahirkan dua alur karena ketukan kedua.
  bool _berjalan = false;

  Future<void> _tekan() async {
    if (_berjalan) return;
    setState(() => _berjalan = true);

    try {
      await pindaiLembarKerja(
        context: context,
        ref: ref,
        setelahKembali: widget.setelahKembali,
      );
    } finally {
      if (mounted) setState(() => _berjalan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = ref.watch(pindaiLembarAktifProvider);
    // Saklar mati: daftar tidak ikut dipantau (tidak ada panggilan server).
    // Segar-ulang yang gagal menyembunyikan tombol walau daftar lama masih
    // tertahan: alur memakai daftar yang sama dan akan gagal juga.
    final kesiapan = aktif ? ref.watch(kesiapanPindaiLembarProvider) : null;
    final tampil =
        kesiapan != null &&
        !kesiapan.hasError &&
        (kesiapan.value?.adaYangBoleh ?? false);
    if (!tampil) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.jarakAtas),
        AppButton(
          key: TombolPindaiLembar.kunciTombol,
          label: l10n.pindaiLembarTombol,
          icon: Icons.document_scanner_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: _berjalan ? null : _tekan,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.pindaiLembarKeterangan,
          key: const ValueKey('keterangan-pindai-lembar'),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
