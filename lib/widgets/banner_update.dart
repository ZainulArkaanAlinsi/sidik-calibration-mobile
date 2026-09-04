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
/// **Rilis biasa tidak memaksa.** Bannernya bisa ditutup, dan aplikasinya
/// tetap jalan penuh dengan versi lama. Itu disengaja: teknisi yang sedang di
/// lokasi pelanggan dengan sinyal seadanya tidak boleh dipaksa mengunduh 68 MB
/// sebelum boleh bekerja.
///
/// ## Rilis wajib ([VersiAplikasi.wajib])
///
/// Bannernya **tidak bisa ditutup** — tombol tutupnya tidak digambar, dan
/// `_ditutup` sengaja diabaikan supaya jalur penutup baru yang ditambahkan
/// nanti tidak diam-diam melewatinya. Warnanya pindah ke nada bahaya dan
/// kata-katanya menyebut WAJIB.
///
/// **Yang TIDAK dilakukan: mengunci aplikasi.** Tidak ada dialog yang tidak
/// bisa ditutup, tidak ada `PopScope(canPop: false)`. Taruhannya lebih tinggi
/// daripada kenyamanan: teknisi di lokasi pelanggan tanpa sinyal cukup untuk
/// mengunduh 68 MB akan kehilangan SELURUH kemampuan mencatat kalibrasi —
/// datanya balik ke kertas atau hilang. Untuk aplikasi yang datanya masuk
/// sertifikat terakreditasi, memaksa berhenti bekerja lebih mahal daripada
/// membiarkan satu sesi jalan di versi lama.
///
/// **Diputuskan 4 Sep 2026: layar isiannya TIDAK diblokir — yang ditahan
/// pengirimannya.** Penjaganya `kirimTertahanRilisWajibProvider`, dipakai kedua layar
/// isian (`calibration_input_screen` dan `lembar_kerja_screen`). Teknisi tetap
/// bisa mengisi dan tetap bisa "Simpan Draft"; yang ditolak cuma "Kirim".
///
/// Alasan lengkapnya ada di provider itu. Ringkasnya: `wajib` didefinisikan
/// sebagai *"versi lama diam-diam mengirim data yang salah"*, jadi yang harus
/// ditahan langkah yang tidak bisa ditarik balik — bukan pekerjaannya.
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

    // Kalau penyiap latar sudah menyelesaikan unduhannya, langsung ke pemasang
    // — tidak ada 68 MB yang perlu ditunggu lagi. Inilah gunanya seluruh
    // mekanisme latar itu: dari ketukan ke layar pemasang, tanpa jeda.
    final siap = await ref.read(penyiapUpdateProvider).apkSiap(rilis.versi);

    final hasil = siap != null
        ? await pengunduh.pasang(siap)
        : await pengunduh.unduhDanPasang(
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
    final rilis = ref.watch(updateTersediaProvider).value;
    if (rilis == null) return const SizedBox.shrink();

    // `_ditutup` diperiksa SESUDAH rilisnya dibaca, dan sengaja diabaikan
    // waktu wajib. Tombol tutupnya memang sudah tidak digambar di bawah, tapi
    // penjagaan di sini yang bikin penutup baru — gesek, tombol lain, apa pun
    // yang ditambahkan nanti — tidak diam-diam melewati rilis wajib.
    if (_ditutup && !rilis.wajib) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final ukuran = rilis.ukuranMb;
    final wajib = rilis.wajib;

    // Nada bahaya buat rilis wajib. Teks galat ikut pindah ke `warnaIsi`:
    // `colorScheme.error` di atas `errorContainer` itu merah di atas merah —
    // pesan yang tidak terbaca sama saja dengan tidak ada pesan.
    final warnaLatar = wajib
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final warnaIsi = wajib
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    // `false` selama unduhan latar masih jalan ATAU memang tidak jalan (di
    // seluler). Dua-duanya berujung tombol lama yang menyebut ukuran — yang
    // penting teknisi tidak pernah kehilangan cara memasang, cuma kadang
    // caranya lebih cepat.
    final siap = ref.watch(updateSiapProvider).value ?? false;

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
        color: warnaLatar,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                wajib ? Icons.warning_amber_rounded : Icons.system_update,
                size: 20,
                color: warnaIsi,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  wajib
                      ? 'Versi ${rilis.versi} WAJIB dipasang'
                      : siap
                      ? 'Versi ${rilis.versi} siap dipasang'
                      : 'Versi ${rilis.versi} sudah tersedia',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warnaIsi,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_sedangUnduh && !wajib)
                IconButton(
                  key: const Key('banner_update_tutup'),
                  tooltip: 'Nanti saja',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _ditutup = true),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: warnaIsi,
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
                color: warnaIsi,
              ),
            ),
          ] else ...[
            if (_galat != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _galat!,
                key: const Key('banner_update_galat'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: wajib ? warnaIsi : theme.colorScheme.error,
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
                    // Ukuran cuma ditulis kalau memang akan diunduh sekarang.
                    // Sudah siap = tidak ada yang diunduh, jadi menulis "68 MB"
                    // justru bohong dan bikin ragu menekan.
                    siap
                        ? 'Pasang sekarang'
                        : ukuran == null
                        ? 'Pasang sekarang'
                        : 'Pasang ($ukuran)',
                  ),
                ),
              ],
            ),
            // Ukuran ditulis di tombol, bukan disembunyikan: teknisi di lokasi
            // pelanggan memakai data seluler, dan 68 MB itu keputusan yang
            // harus dia ambil sadar — bukan kejutan sesudah menekan.
          ],
        ],
      ),
    );
  }
}
