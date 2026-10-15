import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_detail.dart' show CalibrationDetail;
import '../../models/izin.dart';
import '../../models/calibration_history_item.dart';
import '../../models/perhitungan.dart';
import '../../models/validasi.dart';
import '../../providers/history_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/perhitungan_provider.dart';
import '../../services/kode_galat.dart';
import '../../services/perhitungan_service.dart' show HasilApprove;
import '../../widgets/app_button.dart';
import '../../widgets/galat_peran.dart';
import '../auth/widgets/neu.dart';
import '../calibration/instrument_picker_screen.dart'
    show profilLembarKerjaUntuk;
import '../calibration/lembar_kerja_screen.dart';
import 'widgets/data_administrasi.dart';
import 'widgets/dialog_setujui.dart';
import 'bandingkan_screen.dart';
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
/// temuan → **Setujui**. Koreksi lewat **Edit lembar**; **Bandingkan** menunjukkan
/// isian asli teknisi lawan sekarang.
class PerhitunganScreen extends ConsumerStatefulWidget {
  const PerhitunganScreen({
    super.key,
    required this.calibrationId,
    this.statusSesi,
  });

  /// Status sesi waktu layar ini dibuka. `null` = tidak diketahui (pemanggil
  /// lama) dan bilah aksinya tetap lengkap seperti sebelumnya.
  ///
  /// Dipakai menyembunyikan TOLAK/SETUJUI untuk sesi yang memang tidak bisa
  /// disetujui lagi. 16 Sep 2026: sesi yang sudah disetujui tetap memajang
  /// tombol SETUJUI, dan menekannya cuma memunculkan penolakan server "Cuma
  /// sesi yang statusnya `menunggu_approval` yang bisa disetujui." — tombol
  /// yang satu-satunya hasilnya pesan galat.
  final CalibrationStatus? statusSesi;

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

  /// Order Number baru disimpan dari layar ini. Detail sesinya sedang dimuat
  /// ulang, dan selama itu Riverpod masih memegang nilai LAMA (kosong) —
  /// tanpa penanda ini Setujui meminta nomor yang barusan diketik.
  String? _nomorOrderTersimpan;

  bool _perluNomorOrder(CalibrationDetail? detail) =>
      _nomorOrderTersimpan == null && perluNomorOrder(detail);

  /// Buka lembar kerja teknisi di layar yang SAMA dengan teknisi — admin &
  /// super admin mengoreksinya di sana (dengan alasan koreksi kalau sesinya
  /// sudah dikirim). Sesudahnya angka & temuan dimuat ulang: yang tampil di
  /// sini harus angka sesudah koreksi, bukan sebelum.
  void _bandingkan() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BandingkanScreen(calibrationId: widget.calibrationId),
    ),
  );

  Future<void> _bukaLembar() async {
    final detail = await ref.read(
      calibrationDetailProvider(widget.calibrationId).future,
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LembarKerjaScreen(
          sesiId: widget.calibrationId,
          // Sama dengan tombol Edit lembar di detail sesi: profil dari
          // backend dulu, tebakan dari nama cuma cadangan server lama.
          profil:
              detail.profil ??
              profilLembarKerjaUntuk(detail.namaAlat) ??
              'ph_meter',
        ),
      ),
    );
    if (!mounted) return;

    ref
      ..invalidate(perhitunganProvider(widget.calibrationId))
      ..invalidate(calibrationDetailProvider(widget.calibrationId));
    await _periksa();
  }

  /// Setujui = dialog Order Number + No. Sertifikat (K-49-14, K-50-04), lalu
  /// kirim. [isian] terisi waktu mengulang sesudah konfirmasi peringatan
  /// (dialog tidak ditanyakan lagi); [awal] + galat waktu server menolak nomor
  /// (dialog dibuka lagi dengan isian yang sama dan pesan di kotaknya).
  Future<void> _setujui({
    bool abaikanPeringatan = false,
    IsianSetujui? isian,
    IsianSetujui? awal,
    String? galatSertifikat,
    String? galatOrder,
  }) async {
    HasilApprove? hasil;

    var data = isian;
    if (data == null) {
      CalibrationDetail? detail;
      try {
        detail = await ref.read(
          calibrationDetailProvider(widget.calibrationId).future,
        );
      } catch (_) {
        // Detail gagal dimuat: tetap minta nomornya, server yang memutuskan.
      }
      if (!mounted) return;

      final tersimpan =
          (_nomorOrderTersimpan ?? detail?.administrasi.nomorOrder ?? '')
              .trim();
      data = await mintaDataSetujui(
        context,
        nomorOrder: awal?.nomorOrder ?? tersimpan,
        nomorSertifikat: awal?.nomorSertifikat,
        tanpaNomorSertifikat: detail?.sertifikatDitarik ?? false,
        galatSertifikat: galatSertifikat,
        galatOrder: galatOrder,
      );
      if (data == null || !mounted) return;

      // Order Number tidak ada di body approve: disimpan lewat PATCH /admin
      // dulu bila beda dari yang sudah tersimpan.
      if (data.nomorOrder != tersimpan) {
        var ok = false;
        final nomor = data.nomorOrder;
        await _jalankan(() async {
          await _aksi.simpanKolomAdmin(nomorOrder: nomor);
          ok = true;
        });
        if (!ok || !mounted) return;
        setState(() => _nomorOrderTersimpan = nomor);
      }
    }
    final kiriman = data;

    // Kirimnya di dalam `_jalankan` (tombol nyala loading), tapi dialog
    // konfirmasinya DI LUAR — kalau dialog dibuka selagi tombolnya masih
    // muter, admin ditanya sambil layarnya kelihatan sibuk, dan spinner-nya
    // nggak pernah berhenti sampai dia jawab.
    await _jalankan(() async {
      hasil = await _aksi.setujui(
        abaikanPeringatan: abaikanPeringatan,
        nomorSertifikat: kiriman.nomorSertifikat,
      );
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
      // Peringatan yang BENERAN nyala ikut disebut, bukan cuma kalimat umum.
      //
      // Dulu dialog ini nulis "Hasil hitung ulang beda. Lanjut?" untuk SEMUA
      // peringatan, padahal backend punya lima belas kode dan selisih hitung
      // ulang cuma salah satunya. Admin yang membacanya, membuka datanya, lalu
      // menemukan hitung ulangnya baik-baik saja belajar bahwa peringatan di
      // sini bohong — dan sesudah itu "TETAP SETUJUI" ditekan tanpa dibaca,
      // termasuk waktu peringatannya benar.
      //
      // Yang dipakai temuan dari `validasi`, BUKAN `hasil.pesan`: pesan backend
      // ditutup kalimat "kirim ulang dengan `abaikan_peringatan: true`" yang
      // ditujukan ke pemanggil API, bukan ke admin yang di depannya sudah ada
      // tombolnya.
      final peringatan = (hasil!.validasi ?? _validasi)
              ?.pada(TingkatTemuan.peringatan) ??
          const <Temuan>[];

      final lanjut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.perhitKonfirmasiJudul),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in peringatan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${t.pesan}'),
                ),
              Text(l10n.perhitKonfirmasiBody),
            ],
          ),
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
        await _setujui(abaikanPeringatan: true, isian: kiriman);
      }
      return;
    }

    // Server menolak nomor (Order Number kosong, No. Sertifikat kosong / tidak
    // valid / sudah dipakai): dialog dibuka lagi dengan isian yang sama dan
    // pesan yang jelas di kotaknya — status sesi tidak berubah.
    if (kodeIsianSetujui(hasil!.kode)) {
      final orderSalah = hasil!.kode == KodeGalat.nomorOrderWajib;
      final pesan = pesanGalatPeran(
        l10n,
        hasil!.kode,
        pemilikNomor: hasil!.pemilikNomor,
      );
      await _setujui(
        abaikanPeringatan: abaikanPeringatan,
        awal: kiriman,
        galatOrder: orderSalah ? pesan : null,
        galatSertifikat: orderSalah ? null : pesan,
      );
      return;
    }

    // Temuan fatal: approve diblokir, nggak bisa dilewati sama sekali.
    // Pemisahan wewenang dapat kalimat yang menyebut jalan keluarnya.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          pesanGalatPeran(l10n, hasil!.kode) ??
              hasil!.pesan ??
              l10n.perhitApproveDiblokir,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(perhitunganProvider(widget.calibrationId));
    final detail = ref.watch(calibrationDetailProvider(widget.calibrationId));
    // Lembar yang sudah disetujui tidak bisa diubah siapa pun (sertifikatnya
    // sudah terbit) — tombolnya tidak ditawarkan.
    // Lembar bermatriks (Autoklaf) disimpan lewat endpoint alatnya sendiri yang
    // belum punya jalur sunting (`PUT /calibrations/autoclave/{id}`) di app ini:
    // menyimpan dari sini akan MEMBUAT sesi baru. Tombol Edit tidak ditawarkan.
    final autoklaf = (detail.value?.profil ??
            profilLembarKerjaUntuk(detail.value?.namaAlat ?? '')) ==
        'autoclave';
    final bisaDisunting =
        !autoklaf &&
        widget.statusSesi != CalibrationStatus.disetujui &&
        detail.value?.status != CalibrationStatus.disetujui;

    final bolehBandingkan = ref.bolehkah(
      NamaIzin.kalibrasiBandingkan,
      cadangan: ref.watch(authProvider).value?.role.hakAdmin ?? false,
    );

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
          onBukaLembar: bisaDisunting ? _bukaLembar : null,
          onBandingkan: bolehBandingkan ? _bandingkan : null,
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
              statusSesi: widget.statusSesi,
              perluNomorOrder: _perluNomorOrder(detail.value),
              onPeriksa: _periksa,
              onSetujui: _setujui,
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
    this.onBukaLembar,
    this.onBandingkan,
  });

  final Perhitungan perhitungan;
  final HasilValidasi? validasi;
  final int calibrationId;
  final VoidCallback? onBukaLembar;
  final VoidCallback? onBandingkan;

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
        const SizedBox(height: AppSpacing.lg),

        // Kolom Master Data (K-49-14) — paling bawah, persis di atas bilah
        // Setujui: Order Number yang wajib sebelum approve duduk di sebelah
        // tombol yang memintanya.
        KartuDataAdministrasi(
          calibrationId: calibrationId,
          kondisi: perhitungan.kondisiLingkungan,
          tanggalKalibrasi: cust.tanggalKalibrasi,
          onBukaLembar: onBukaLembar,
        ),
        if (onBandingkan != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const ValueKey('tombol-bandingkan'),
            label: l10n.bandingkanTombol,
            icon: Icons.compare_arrows,
            variant: AppButtonVariant.secondary,
            onPressed: onBandingkan,
          ),
        ],
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
    required this.statusSesi,
    required this.onPeriksa,
    required this.onSetujui,
    this.perluNomorOrder = false,
  });

  final bool sibuk;
  final HasilValidasi? validasi;
  final CalibrationStatus? statusSesi;

  /// Order Number kosong menurut detail sesi — Setujui akan memintanya dulu.
  final bool perluNomorOrder;
  final VoidCallback onPeriksa;
  final VoidCallback onSetujui;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Temuan fatal nahan approve TANPA SYARAT — tombolnya dimatiin, bukan
    // cuma dikasih peringatan. Peringatan (kuning) beda: tombolnya tetap
    // hidup, tapi server bakal minta konfirmasi sekali.
    final diblokir = validasi != null && !validasi!.bolehTerbit;

    // `null` = pemanggil tidak menyebut statusnya: bilahnya tetap lengkap.
    final bisaDiputuskan =
        statusSesi == null || statusSesi == CalibrationStatus.menungguApproval;
    final keterangan = switch (statusSesi) {
      CalibrationStatus.disetujui => 'Sesi ini sudah disetujui.',
      CalibrationStatus.perluRevisi => 'Sesi lama ini menunggu perbaikan teknisi.',
      CalibrationStatus.draft => 'Masih draf teknisi — belum dikirim buat diperiksa.',
      _ => '',
    };

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
              // Sesi yang statusnya bukan `menunggu_approval` tidak bisa
              // disetujui lagi — server menolaknya. Tombolnya dicabut,
              // bukan dibiarkan memajang janji yang pasti gagal; PERIKSA tetap
              // ada karena hitung ulang boleh dijalankan kapan saja.
              if (!bisaDiputuskan) ...[
                Text(
                  keterangan,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.perhitPeriksa,
                  icon: Icons.fact_check_outlined,
                  variant: AppButtonVariant.secondary,
                  isLoading: sibuk,
                  onPressed: onPeriksa,
                ),
              ] else ...[
                if (perluNomorOrder && !diblokir) ...[
                  Text(
                    l10n.adminNomorOrderWajibSetujui,
                    key: const ValueKey('petunjuk-nomor-order'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
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
