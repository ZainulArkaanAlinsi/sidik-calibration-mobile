import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/perhitungan.dart';
import '../../models/validasi.dart';
import '../../providers/history_provider.dart';
import '../../providers/perhitungan_provider.dart';
import '../../services/perhitungan_service.dart' show HasilApprove;
import '../../widgets/app_button.dart';
import 'widgets/blok_kondisi.dart';
import 'widgets/panel_temuan.dart';
import 'widgets/tabel_perhitungan.dart';

/// Lembar PERHITUNGAN — **layar utama admin** (spesifikasi poin 11 & 12A).
///
/// Ini pengganti sheet "PERHITUNGAN" di `Master Olah Data_pH.xlsm`: identitas
/// alat & customer, blok kondisi lingkungan, lalu dua tabel hasil yang ditutup
/// baris Average, Correction, STDEV, dan MAX STDEV.
///
/// **Nol perhitungan di layar ini.** Semua angka udah jadi di respons backend,
/// dan backend-nya udah dicocokkan angka per angka sama Excel milik lab. Ikut
/// menghitung di sini cepat atau lambat bikin angkanya beda dari sertifikat —
/// dan bedanya nggak akan ketahuan sampai ada yang ngebandingin dua dokumen.
///
/// Alur keputusannya: **Periksa** (hitung ulang tanpa nyetujuin) → lihat
/// temuan → **Setujui** / **Tolak**.
class PerhitunganScreen extends ConsumerStatefulWidget {
  const PerhitunganScreen({super.key, required this.calibrationId});

  final int calibrationId;

  @override
  ConsumerState<PerhitunganScreen> createState() => _PerhitunganScreenState();
}

class _PerhitunganScreenState extends ConsumerState<PerhitunganScreen> {
  /// Hasil "Periksa". Ditaruh di layar, bukan provider: cuma layar ini yang
  /// memakainya, dan admin sendiri yang mutusin kapan pemeriksaan jalan.
  HasilValidasi? _validasi;

  bool _sibuk = false;

  AksiAdmin get _aksi => ref.read(aksiAdminProvider(widget.calibrationId));

  Future<void> _jalankan(Future<void> Function() aksi) async {
    setState(() => _sibuk = true);
    try {
      await aksi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _periksa() => _jalankan(() async {
    final hasil = await _aksi.periksa();
    if (mounted) setState(() => _validasi = hasil);
  });

  Future<void> _setujui({bool abaikanPeringatan = false}) async {
    HasilApprove? hasil;

    // Kirimnya di dalam `_jalankan` (tombol nyala loading), tapi dialog
    // konfirmasinya DI LUAR — kalau dialog dibuka selagi tombolnya masih
    // muter, admin ditanya sambil layarnya kelihatan sibuk, dan spinner-nya
    // nggak pernah berhenti sampai dia jawab.
    await _jalankan(() async {
      hasil = await _aksi.setujui(abaikanPeringatan: abaikanPeringatan);
      // Temuannya ikut di responsnya — nggak usah nembak /validasi lagi.
      if (mounted) setState(() => _validasi = hasil!.validasi ?? _validasi);
    });

    if (!mounted || hasil == null) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (hasil!.disetujui) {
      ref.invalidate(antreanApprovalProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.perhitDisetujui)));
      navigator.pop();
      return;
    }

    // Peringatan nahan SEKALI. Admin lihat temuannya, lalu lanjut secara
    // sadar — bukan tombol yang diam-diam ngirim ulang sendiri.
    if (hasil!.butuhKonfirmasi) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.perhitKonfirmasiJudul),
          content: Text(l10n.perhitKonfirmasiBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.perhitKonfirmasiBatal),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.perhitKonfirmasiLanjut),
            ),
          ],
        ),
      );

      if (lanjut == true && mounted) {
        await _setujui(abaikanPeringatan: true);
      }
      return;
    }

    // Temuan fatal: approve diblokir, nggak bisa dilewati sama sekali.
    messenger.showSnackBar(
      SnackBar(content: Text(hasil!.pesan ?? l10n.perhitApproveDiblokir)),
    );
  }

  Future<void> _tolak() async {
    final l10n = AppLocalizations.of(context);

    final catatan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogTolak(),
    );
    if (catatan == null || !mounted) return;

    if (catatan.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.perhitTolakKosong)));
      return;
    }

    await _jalankan(() async {
      await _aksi.tolak(catatan);
      if (!mounted) return;
      ref.invalidate(antreanApprovalProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.perhitDitolak)));
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(perhitunganProvider(widget.calibrationId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.perhitTitle)),
      body: switch (async) {
        AsyncData(:final value) => _Isi(
          perhitungan: value,
          validasi: _validasi,
          calibrationId: widget.calibrationId,
        ),
        AsyncError() => _Gagal(
          onCobaLagi: () =>
              ref.invalidate(perhitunganProvider(widget.calibrationId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: async.hasValue
          ? _BilahAksi(
              sibuk: _sibuk,
              validasi: _validasi,
              onPeriksa: _periksa,
              onSetujui: _setujui,
              onTolak: _tolak,
            )
          : null,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({
    required this.perhitungan,
    required this.validasi,
    required this.calibrationId,
  });

  final Perhitungan perhitungan;
  final HasilValidasi? validasi;
  final int calibrationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alat = perhitungan.identitasAlat;
    final cust = perhitungan.identitasCustomer;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (validasi != null) ...[
          PanelTemuan(validasi: validasi!),
          const SizedBox(height: AppSpacing.md),
        ],

        _Blok(
          judul: l10n.perhitIdentitasAlat,
          baris: [
            (l10n.perhitNamaAlat, alat.namaAlat),
            (l10n.perhitMerk, alat.merk),
            (l10n.perhitType, alat.type),
            (l10n.perhitNoSeri, alat.noSeri),
            (l10n.perhitRentang, _satuan(alat.rentangUkur, alat.satuan)),
            (l10n.perhitKapasitas, _angka(alat.kapasitasMax, alat.satuan)),
            (l10n.perhitResolusi, _angka(alat.resolusi, alat.satuan)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        _Blok(
          judul: l10n.perhitIdentitasCustomer,
          baris: [
            (l10n.perhitCustNama, cust.nama),
            (l10n.perhitCustAlamat, cust.alamat),
            (l10n.perhitTglTerima, cust.tanggalTerima),
            (l10n.perhitTglKalibrasi, cust.tanggalKalibrasi),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        BlokKondisi(
          kondisi: perhitungan.kondisiLingkungan,
          calibrationId: calibrationId,
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          l10n.perhitHasil,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        for (final tabel in perhitungan.hasil) ...[
          TabelPerhitunganWidget(tabel: tabel),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Dua catatan yang paling gampang bikin salah baca angka. Ditulis di
        // layar, bukan cuma di komentar kode, karena yang kebalik nanti itu
        // orangnya — bukan programnya.
        _Catatan(teks: l10n.perhitStandardCatatan),
        const SizedBox(height: AppSpacing.xs),
        _Catatan(teks: l10n.perhitCorrectionCatatan),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  static String? _satuan(String? nilai, String? satuan) {
    if (nilai == null) return null;
    return satuan == null || satuan.isEmpty ? nilai : '$nilai $satuan';
  }

  static String? _angka(double? nilai, String? satuan) {
    if (nilai == null) return null;
    return _satuan(formatAngka(nilai), satuan);
  }
}

class _Blok extends StatelessWidget {
  const _Blok({required this.judul, required this.baris});

  final String judul;
  final List<(String, String?)> baris;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            for (final (label, nilai) in baris)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    Text(': ', style: theme.textTheme.bodySmall),
                    Expanded(
                      child: Text(
                        // Strip, bukan kosong: kolom yang belum diisi harus
                        // kelihatan belum diisi.
                        (nilai == null || nilai.isEmpty) ? '—' : nilai,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            teks,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _BilahAksi extends StatelessWidget {
  const _BilahAksi({
    required this.sibuk,
    required this.validasi,
    required this.onPeriksa,
    required this.onSetujui,
    required this.onTolak,
  });

  final bool sibuk;
  final HasilValidasi? validasi;
  final VoidCallback onPeriksa;
  final VoidCallback onSetujui;
  final VoidCallback onTolak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Temuan fatal nahan approve TANPA SYARAT — tombolnya dimatiin, bukan
    // cuma dikasih peringatan. Peringatan (kuning) beda: tombolnya tetap
    // hidup, tapi server bakal minta konfirmasi sekali.
    final diblokir = validasi != null && !validasi!.bolehTerbit;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (diblokir) ...[
                Text(
                  l10n.perhitApproveDiblokir,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.perhitPeriksa,
                      icon: Icons.fact_check_outlined,
                      variant: AppButtonVariant.secondary,
                      isLoading: sibuk,
                      onPressed: onPeriksa,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: l10n.perhitTolak,
                      variant: AppButtonVariant.secondary,
                      isLoading: sibuk,
                      onPressed: onTolak,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.perhitSetujui,
                icon: Icons.verified_outlined,
                isLoading: sibuk,
                onPressed: diblokir ? null : onSetujui,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTolak extends StatefulWidget {
  const _DialogTolak();

  @override
  State<_DialogTolak> createState() => _DialogTolakState();
}

class _DialogTolakState extends State<_DialogTolak> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.perhitTolakJudul),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: l10n.perhitTolakLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.perhitKonfirmasiBatal),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.perhitTolakKirim),
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.perhitGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.folderRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
