import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../models/versi_aplikasi.dart';
import '../providers/versi_provider.dart';
import '../services/pengunduh_apk.dart';

/// Pemberitahuan "ada versi baru" + tombol yang benar-benar memasangnya.
///
/// Menggantikan alur lama yang bolak-balik: buka GitHub atau email, unduh
/// manual, cari berkasnya di folder Download, baru pasang. Di sini teknisi
/// menekan satu tombol dan menunggu.
///
/// **Tidak memaksa.** Bannernya bisa ditutup, dan aplikasinya tetap jalan
/// penuh dengan versi lama. Itu disengaja: teknisi yang sedang di lokasi
/// pelanggan dengan sinyal seadanya tidak boleh dipaksa mengunduh 50 MB
/// sebelum boleh bekerja. Rilis yang memang WAJIB punya penandanya sendiri
/// ([VersiAplikasi.wajib]) — dan bahkan itu belum dipakai sampai ada rilis
/// yang benar-benar membutuhkannya.
class BannerUpdate extends ConsumerStatefulWidget {
  const BannerUpdate({super.key, this.pengunduh});

  /// Disuntikkan di test. Null = pakai pengunduh sungguhan.
  final PengunduhApk? pengunduh;

  @override
  ConsumerState<BannerUpdate> createState() => _BannerUpdateState();
}

class _BannerUpdateState extends ConsumerState<BannerUpdate> {
  bool _ditutup = false;
  bool _sedangUnduh = false;
  double? _progres;
  String? _galat;

  Future<void> _pasang(VersiAplikasi rilis) async {
    setState(() {
      _sedangUnduh = true;
      _progres = 0;
      _galat = null;
    });

    final pengunduh = widget.pengunduh ?? PengunduhApkAsli();
    final hasil = await pengunduh.unduhDanPasang(
      rilis.urlUnduh,
      namaBerkas: 'sidik-kalibrasi-${rilis.versi}.apk',
      onProgres: (p) {
        if (mounted) setState(() => _progres = p);
      },
    );

    if (!mounted) return;

    setState(() {
      _sedangUnduh = false;
      _galat = switch (hasil) {
        HasilPasang.pemasangDibuka => null,
        // Pesannya menyebut LAYAR yang harus dituju, bukan "coba lagi":
        // mencoba ulang tanpa memberi izin selalu berujung sama, dan teknisi
        // yang menekan tombol itu tiga kali akan menyimpulkan aplikasinya
        // rusak.
        HasilPasang.ditolakSistem =>
          'Android menolak membuka pemasang. Izinkan "Install unknown apps" '
              'buat aplikasi ini di Pengaturan, lalu tekan Pasang lagi.',
        HasilPasang.gagalUnduh =>
          'Unduhan gagal. Cek sinyal atau ruang penyimpanan, lalu coba lagi.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ditutup) return const SizedBox.shrink();

    final rilis = ref.watch(updateTersediaProvider).value;
    if (rilis == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final ukuran = rilis.ukuranMb;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Versi ${rilis.versi} sudah tersedia',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_sedangUnduh)
                IconButton(
                  key: const Key('banner_update_tutup'),
                  tooltip: 'Nanti saja',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _ditutup = true),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
            ],
          ),

          if (_sedangUnduh) ...[
            const SizedBox(height: AppSpacing.sm),
            // `value: null` menggambar bilah TAK TENTU — dipakai waktu server
            // tidak mengirim Content-Length. Bedanya penting: bilah yang diam
            // di 0% terbaca sebagai macet.
            LinearProgressIndicator(value: _progres),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _progres == null
                  ? 'Mengunduh…'
                  : 'Mengunduh… ${(_progres! * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ] else ...[
            if (_galat != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _galat!,
                key: const Key('banner_update_galat'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('banner_update_pasang'),
                  onPressed: () => _pasang(rilis),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(
                    ukuran == null ? 'Pasang sekarang' : 'Pasang ($ukuran)',
                  ),
                ),
              ],
            ),
            // Ukuran ditulis di tombol, bukan disembunyikan: teknisi di lokasi
            // pelanggan memakai data seluler, dan 50 MB itu keputusan yang
            // harus dia ambil sadar — bukan kejutan sesudah menekan.
          ],
        ],
      ),
    );
  }
}
