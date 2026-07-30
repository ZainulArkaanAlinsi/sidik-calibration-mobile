import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/tanda_tangan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/tanda_tangan_provider.dart';
import '../../widgets/app_button.dart';

/// Pengaturan tanda tangan yang dicetak di sertifikat — **admin doang**.
///
/// Satu layar pengaturan, **bukan editor per sertifikat**: posisinya disimpan
/// di tingkat template dan berlaku buat semua sertifikat. Sertifikat yang udah
/// terbit itu dokumen terkendali — kalau posisinya bisa diedit per lembar,
/// isinya berubah sesudah diserahkan ke pelanggan.
class TandaTanganScreen extends ConsumerWidget {
  const TandaTanganScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.bolehkah(
      NamaIzin.tandaTanganKelola,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ttdTitle)),
      body: admin ? const _Isi() : _HanyaAdmin(pesan: l10n.ttdHanyaAdmin),
    );
  }
}

class _HanyaAdmin extends StatelessWidget {
  const _HanyaAdmin({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Isi extends ConsumerStatefulWidget {
  const _Isi();

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  bool _sibuk = false;

  /// Posisi yang lagi diutak-atik di slider, belum tentu udah disimpan.
  /// Dipisah dari state provider biar geser slider nggak nembak API tiap
  /// piksel — yang nembak cuma tombol Simpan.
  TandaTanganPosisi? _draf;

  Future<void> _jalankan(
    Future<void> Function() aksi, {
    required String pesanSukses,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);
    try {
      await aksi();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(pesanSukses)));
      }
    } catch (e) {
      if (mounted) {
        // Pesan backend ditampilin APA ADANYA. Buat penolakan PNG, `422`-nya
        // udah nyebut alasan lengkap (JPG nggak transparan → kecetak kotak
        // putih). Diganti "format tidak didukung" malah ngilangin alasannya.
        messenger.showSnackBar(
          SnackBar(content: Text(_pesan(e, l10n.ttdGagalMuat))),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  String _pesan(Object error, String cadangan) {
    final teks = error.toString().replaceFirst('Exception: ', '').trim();
    return teks.isEmpty ? cadangan : teks;
  }

  Future<void> _unggah() async {
    // Dibatasi PNG di picker-nya, bukan cuma ngandelin tolakan backend —
    // lebih cepat ketahuan, dan teknisi nggak kebuang waktu milih file yang
    // pasti ditolak. Backend tetap yang berwenang nolak.
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: false,
    );

    // File picker ngebuka layar sistem, jadi widget-nya bisa udah dilepas
    // waktu balik — mis. admin nutup app dari task switcher pas milih file.
    if (!mounted) return;

    final path = hasil?.files.single.path;
    if (path == null) return;

    final l10n = AppLocalizations.of(context);
    await _jalankan(
      () => ref.read(tandaTanganProvider.notifier).unggah(path),
      pesanSukses: l10n.ttdTerunggah,
    );
  }

  Future<void> _hapus() async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.ttdHapusKonfirmJudul),
        content: Text(l10n.ttdHapusKonfirmIsi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ttdHapus),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    await _jalankan(
      () => ref.read(tandaTanganProvider.notifier).hapus(),
      pesanSukses: l10n.ttdTerhapus,
    );
  }

  Future<void> _simpanPosisi(TandaTanganPosisi posisi) async {
    final l10n = AppLocalizations.of(context);
    await _jalankan(
      () => ref.read(tandaTanganProvider.notifier).setPosisi(posisi),
      pesanSukses: l10n.ttdPosisiTersimpan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(tandaTanganProvider);

    final data = async.value;
    if (data == null) {
      if (async.hasError) {
        return _Gagal(
          pesan: l10n.ttdGagalMuat,
          label: l10n.ttdRetry,
          onCobaLagi: () => ref.read(tandaTanganProvider.notifier).muatUlang(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final posisi = _draf ?? data.info.posisi;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Pratinjau(gambar: data.gambar),
        const SizedBox(height: AppSpacing.md),

        Text(
          l10n.ttdHanyaPng,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: AppButton(
                label: data.ada ? l10n.ttdGanti : l10n.ttdUnggah,
                icon: Icons.upload_outlined,
                isLoading: _sibuk,
                onPressed: _sibuk ? null : _unggah,
              ),
            ),
            if (data.ada) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.ttdHapus,
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.secondary,
                  onPressed: _sibuk ? null : _hapus,
                ),
              ),
            ],
          ],
        ),

        // Pengaturan posisi cuma masuk akal kalau ada yang mau diposisikan.
        if (data.ada) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.ttdPosisiJudul,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ttdPosisiIsi,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Geser(
            label: l10n.ttdGeserX(posisi.geserXMm.toStringAsFixed(1)),
            catatan: l10n.ttdArahX,
            nilai: posisi.geserXMm,
            min: TandaTanganPosisi.minGeser,
            maks: TandaTanganPosisi.maksGeser,
            onUbah: (v) => setState(() => _draf = posisi.salin(geserXMm: v)),
          ),
          _Geser(
            label: l10n.ttdGeserY(posisi.geserYMm.toStringAsFixed(1)),
            // Ditulis di layar, bukan cuma di komentar kode: admin yang
            // ngegeser perlu tau positif itu NAIK, karena kebalikan sama
            // koordinat layar yang dia biasa lihat.
            catatan: l10n.ttdArahY,
            nilai: posisi.geserYMm,
            min: TandaTanganPosisi.minGeser,
            maks: TandaTanganPosisi.maksGeser,
            onUbah: (v) => setState(() => _draf = posisi.salin(geserYMm: v)),
          ),
          _Geser(
            label: l10n.ttdLebar(posisi.lebarMm.toStringAsFixed(1)),
            nilai: posisi.lebarMm,
            min: TandaTanganPosisi.minLebar,
            maks: TandaTanganPosisi.maksLebar,
            onUbah: (v) => setState(() => _draf = posisi.salin(lebarMm: v)),
          ),

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.ttdSimpanPosisi,
            icon: Icons.save_outlined,
            isLoading: _sibuk,
            onPressed: _sibuk || _draf == null
                ? null
                : () => _simpanPosisi(posisi),
          ),
        ],
      ],
    );
  }
}

/// Kotak pratinjau tanda tangan.
class _Pratinjau extends StatelessWidget {
  const _Pratinjau({required this.gambar});

  final dynamic gambar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 160,
      decoration: BoxDecoration(
        // Latar putih dipaksa: tanda tangan itu PNG transparan bergaris gelap.
        // Di atas permukaan tema gelap, garisnya nyaris nggak kelihatan —
        // admin nggak bisa menilai hasil unggahannya.
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.dividerColor),
      ),
      alignment: Alignment.center,
      child: gambar == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.draw_outlined, size: 36, color: Colors.black26),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.ttdBelumAda,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    l10n.ttdBelumAdaIsi,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                ),
              ],
            )
          // `Image.memory`, BUKAN `Image.network`: gambarnya dilayani di balik
          // auth, dan `Image.network` nggak bawa header `Authorization` —
          // hasilnya `401` dan gambarnya nggak pernah muncul.
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Image.memory(gambar, fit: BoxFit.contain),
            ),
    );
  }
}

class _Geser extends StatelessWidget {
  const _Geser({
    required this.label,
    required this.nilai,
    required this.min,
    required this.maks,
    required this.onUbah,
    this.catatan,
  });

  final String label;
  final String? catatan;
  final double nilai;
  final double min;
  final double maks;
  final ValueChanged<double> onUbah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            if (catatan != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '· $catatan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        Slider(
          value: nilai.clamp(min, maks),
          min: min,
          max: maks,
          // Setengah milimeter: cukup halus buat nyetel, tapi nggak bikin
          // nilainya jadi angka desimal panjang yang nggak ada artinya di
          // hasil cetak.
          divisions: ((maks - min) * 2).round(),
          label: nilai.toStringAsFixed(1),
          onChanged: onUbah,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({
    required this.pesan,
    required this.label,
    required this.onCobaLagi,
  });

  final String pesan;
  final String label;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pesan, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: label,
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              onPressed: onCobaLagi,
            ),
          ],
        ),
      ),
    );
  }
}
