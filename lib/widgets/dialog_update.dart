import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../models/versi_aplikasi.dart';
import '../providers/versi_provider.dart';
import '../services/pasang_pembaruan.dart';
import '../services/pengunduh_apk.dart';

/// Tampilkan [DialogUpdate]. Selesai waktu dialognya tertutup.
///
/// [siap] = APK-nya SUDAH terunduh waktu dialog dibuka. Cuma menentukan label
/// tombol; yang benar-benar dipakai waktu tombolnya ditekan diperiksa ulang
/// saat itu juga oleh `pasangPembaruan`.
Future<void> tampilkanDialogUpdate(
  BuildContext context, {
  required VersiAplikasi rilis,
  required bool siap,
  PengunduhApk? pengunduh,
}) {
  return showDialog<void>(
    context: context,
    // Mengetuk di luar dialog = "Nanti". Selama mengunduh ditahan `PopScope`
    // di dalam dialog, bukan di sini: nilai ini dipatok waktu rutenya
    // didorong dan tidak bisa ikut berubah mengikuti keadaan unduhan.
    builder: (_) =>
        DialogUpdate(rilis: rilis, siap: siap, pengunduh: pengunduh),
  );
}

/// Pop-up "ada versi baru" — satu ketukan dari pemberitahuan ke pemasang.
///
/// Dibuka `PemasangOtomatis` waktu aplikasi dibuka di dashboard, sekali per
/// proses. Bannernya (`BannerUpdate`) tetap di dashboard; dialog ini cuma
/// memastikan pemutakhiran tidak terlewat karena bannernya tidak dibaca.
///
/// ## Rilis wajib tetap boleh "Nanti"
///
/// Keputusan lama di `BannerUpdate` berlaku utuh: aplikasi TIDAK dikunci.
/// Teknisi di lokasi pelanggan tanpa sinyal cukup untuk 68 MB harus tetap bisa
/// mencatat. Yang ditahan pengiriman lembar kerja
/// (`kirimTertahanRilisWajibProvider`), dan dialog ini cuma menyebutnya.
///
/// ## Selama mengunduh dialognya tidak bisa ditutup
///
/// Kedua tombol mati dan `PopScope` menahan tombol kembali serta ketukan di
/// luar dialog. Menutup dialog di tengah unduhan bikin 68 MB jalan terus
/// tanpa ada yang menampilkannya, dan tombol yang bisa ditekan dua kali
/// memulai unduhan kedua ke berkas yang sama. Begitu unduhannya selesai —
/// berhasil atau gagal — "Nanti" kembali bisa ditekan.
class DialogUpdate extends ConsumerStatefulWidget {
  const DialogUpdate({
    super.key,
    required this.rilis,
    required this.siap,
    this.pengunduh,
  });

  final VersiAplikasi rilis;

  /// APK-nya sudah terunduh waktu dialog dibuka — ukuran tidak ditulis.
  final bool siap;

  /// Disuntikkan di test. Null = pakai pengunduh sungguhan.
  final PengunduhApk? pengunduh;

  @override
  ConsumerState<DialogUpdate> createState() => _DialogUpdateState();
}

class _DialogUpdateState extends ConsumerState<DialogUpdate> {
  /// Tombol sudah ditekan dan hasilnya belum datang.
  bool _sibuk = false;

  /// Sedang mengunduh — bukan cuma membuka pemasang buat berkas yang sudah
  /// ada. Bilah progres cuma digambar di keadaan ini.
  bool _mengunduh = false;

  double? _progres;
  String? _galat;

  Future<void> _update() async {
    if (_sibuk) return;

    setState(() {
      _sibuk = true;
      _mengunduh = false;
      _progres = null;
      _galat = null;
    });

    // Tidak pernah melempar — lemparan `pasang` dipulangkan sebagai
    // `ditolakSistem`. Itu yang menjamin `_sibuk` selalu turun lagi: dialog
    // yang tidak bisa ditutup selama memproses itu aplikasi yang terkunci.
    final hasil = await pasangPembaruan(
      widget.rilis,
      penyiap: ref.read(penyiapUpdateProvider),
      pengunduh: widget.pengunduh ?? PengunduhApkAsli(),
      onMulaiUnduh: () {
        if (mounted) setState(() => _mengunduh = true);
      },
      onProgres: (p) {
        if (mounted) setState(() => _progres = p);
      },
    );

    if (!mounted) return;

    if (hasil == HasilPasang.pemasangDibuka) {
      // Layar pemasang Android sudah di depan; tugas dialog ini selesai.
      // Kalau pemasangannya dibatalkan, bannernya masih di dashboard.
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _sibuk = false;
      _mengunduh = false;
      _galat = pesanHasilPasang(hasil, namaTombol: 'Update');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rilis = widget.rilis;
    final wajib = rilis.wajib;
    final ukuran = rilis.ukuranMb;
    final catatan = rilis.catatan?.trim() ?? '';

    // Sama dengan banner: ukuran cuma ditulis kalau memang akan diunduh
    // sekarang. Teknisi di lokasi pelanggan memakai data seluler, dan 68 MB
    // itu keputusan yang harus dia ambil sadar.
    final labelUpdate = !widget.siap && ukuran != null
        ? 'Update ($ukuran)'
        : 'Update sekarang';

    final progres = _progres;

    return PopScope(
      canPop: !_sibuk,
      child: AlertDialog(
        key: const Key('dialog_update'),
        icon: Icon(
          wajib ? Icons.warning_amber_rounded : Icons.system_update,
          color: wajib ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          wajib
              ? 'Versi ${rilis.versi} WAJIB dipasang'
              : 'Versi ${rilis.versi} tersedia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wajib)
                Text(
                  'Pengiriman lembar kerja ditahan sampai versi ini dipasang.',
                  key: const Key('dialog_update_wajib'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (wajib && catatan.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              if (catatan.isNotEmpty)
                Text(catatan, style: theme.textTheme.bodyMedium),
              if (_mengunduh) ...[
                const SizedBox(height: AppSpacing.md),
                // `value: null` menggambar bilah TAK TENTU — dipakai waktu
                // server tidak mengirim Content-Length. Bilah yang diam di 0%
                // terbaca sebagai macet.
                LinearProgressIndicator(value: progres),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  progres == null
                      ? 'Mengunduh…'
                      : 'Mengunduh… ${(progres * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ] else if (_sibuk) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Membuka pemasang…', style: theme.textTheme.bodySmall),
              ],
              if (_galat != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _galat!,
                  key: const Key('dialog_update_galat'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('dialog_update_nanti'),
            onPressed: _sibuk ? null : () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            key: const Key('dialog_update_pasang'),
            onPressed: _sibuk ? null : _update,
            child: Text(labelUpdate),
          ),
        ],
      ),
    );
  }
}
