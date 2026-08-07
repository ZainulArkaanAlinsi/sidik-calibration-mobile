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
import '../auth/widgets/neu.dart';
import 'widgets/lembar_tolak.dart';
import 'widgets/blok_kondisi.dart';
import 'widgets/panel_temuan.dart';
import 'widgets/tabel_perhitungan.dart';
import '../../widgets/sidik_loader.dart';

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
  /// memakainya.
  HasilValidasi? _validasi;

  bool _sibuk = false;

  @override
  void initState() {
    super.initState();

    // Pemeriksaan jalan SENDIRI begitu layar kebuka.
    //
    // Dulu cuma jalan waktu admin mencet PERIKSA, dan itu bikin temuan basi
    // kelihatan seperti kondisi sekarang. Kejadian 7 Agt 2026: teknisi baru aja
    // ngonfirmasi pembacaan hasil foto dari HP, tapi layar admin masih nampilin
    // "1 Blocks issuance — pembacaan AI Vision belum diverifikasi". Admin
    // mencet Approve, ditolak, dan nggak ada satu pun petunjuk kalau blokirnya
    // sebenarnya UDAH nggak ada. Temuan yang salah lebih menyesatkan daripada
    // nggak ada temuan sama sekali.
    //
    // Tombol PERIKSA-nya TETAP ADA — pemeriksaan itu hitung ulang penuh dari
    // pembacaan mentah, dan admin masih perlu bisa mengulangnya kapan pun tanpa
    // keluar-masuk layar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _periksa();
    });
  }

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

    // Lembar, bukan dialog kotak-kosong. Temuan pemeriksaan yang lagi tampil
    // di layar ikut dibawa masuk supaya admin bisa nap satu-satu daripada
    // ngetik ulang apa yang mesin udah tahu. Lihat docblock `LembarTolak`.
    final kiriman = await showModalBottomSheet<KirimanTolak>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => LembarTolak(temuan: _validasi?.temuan ?? const []),
    );
    if (kiriman == null || !mounted) return;

    await _jalankan(() async {
      await _aksi.tolak(kiriman.catatan, field: kiriman.field);
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

    final c = NeuColors.of(context);

    return Scaffold(
      // Soft-UI, sama kayak Antrean & Login: latar dan isi kartu sewarna,
      // kedalamannya dari bayangan. Lihat catatan di `NeuColors.base`.
      backgroundColor: c.base,
      appBar: AppBar(
        backgroundColor: c.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          l10n.perhitTitle,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
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
        _ => const Center(child: SidikLoader(size: 88)),
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

        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Text(
            l10n.perhitHasil.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: NeuColors.of(context).accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Before & After dibungkus SATU kartu, bukan dua blok berjauhan.
        //
        // Dua-duanya satu lembar perhitungan yang sama — yang dibaca orang itu
        // "alatnya datang segini, sesudah diadjust jadi segini". Ditaruh
        // sebagai dua blok dengan jarak lebar, di layar sempit yang kedua
        // jatuh di luar layar dan kelihatan kayak halaman lain; padahal
        // membandingkan dua tabel itu justru gunanya lembar ini.
        NeuRaised(
          radius: 20,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, tabel) in perhitungan.hasil.indexed) ...[
                if (i > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 1,
                    color: NeuColors.of(
                      context,
                    ).darkShadow.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TabelPerhitunganWidget(
                  tabel: tabel,
                  resolusiAlat: perhitungan.identitasAlat.resolusi,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

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
    final c = NeuColors.of(context);

    return NeuRaised(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: c.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Garis tipis dari bayangan gelap, bukan Divider Material — biar
          // pemisahnya nyatu sama permukaan soft-UI, nggak kayak garis nempel.
          Container(height: 1, color: c.darkShadow.withValues(alpha: 0.35)),
          const SizedBox(height: AppSpacing.sm),
          for (final (label, nilai) in baris)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      // Strip, bukan kosong: kolom yang belum diisi harus
                      // kelihatan belum diisi.
                      (nilai == null || nilai.isEmpty) ? '—' : nilai,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: (nilai == null || nilai.isEmpty)
                            ? c.textMuted
                            : c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: c.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              teks,
              style: TextStyle(fontSize: 11.5, height: 1.45, color: c.textMuted),
            ),
          ),
        ],
      ),
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

    // Temuan fatal nahan approve TANPA SYARAT — tombolnya dimatiin, bukan
    // cuma dikasih peringatan. Peringatan (kuning) beda: tombolnya tetap
    // hidup, tapi server bakal minta konfirmasi sekali.
    final diblokir = validasi != null && !validasi!.bolehTerbit;

    final c = NeuColors.of(context);

    // Bilah aksi ini yang menerbitkan sertifikat, jadi sengaja TIDAK ikut
    // ditenggelamkan jadi permukaan sewarna: dia diberi latar sedikit terangkat
    // + garis pemisah, biar batas antara "isi yang dibaca" dan "tombol yang
    // mengubah keadaan" tetap tegas. Tombol paling merusak kalau ketekan tanpa
    // sadar itu Setujui.
    return Container(
      decoration: BoxDecoration(
        color: c.base,
        border: Border(
          top: BorderSide(color: c.darkShadow.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: c.darkShadow.withValues(alpha: 0.45),
            offset: const Offset(0, -4),
            blurRadius: 14,
          ),
        ],
      ),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.danger,
                  ),
                  textAlign: TextAlign.center,
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

/// Gagal muat. Sengaja soft-UI persis kayak `_Gagal` di Antrean Approval —
/// layar ini latarnya `c.base`, jadi kartu error ber-`colorScheme.error` +
/// tombol Material polos kelihatan nempel dari aplikasi lain. Itu justru layar
/// yang paling sering dilihat waktu backend lagi ngadat.
class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: NeuRaised(
            circle: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Icon(Icons.cloud_off_outlined, size: 44, color: c.danger),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.perhitGagal,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NeuButton(label: l10n.folderRetry, onPressed: onCobaLagi),
      ],
    );
  }
}
