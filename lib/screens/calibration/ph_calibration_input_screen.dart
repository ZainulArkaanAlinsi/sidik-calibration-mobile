
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/ph_calibration_draft.dart';
import '../../models/standard.dart';
import '../../providers/calibration_input_provider.dart';
import '../../providers/ocr_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/worksheet_ocr.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/result_sheet.dart';

/// Input kalibrasi pH Meter — dua halaman, ngikutin worksheet asli PT Sidik:
/// Halaman 1 identitas alat + pengerjaan + kondisi lingkungan, Halaman 2 data
/// hasil per titik buffer (before & after adjustment).
///
/// Dipisah dari [CalibrationInputScreen] generik karena pH butuh field yang
/// jauh lebih spesifik — dipaksa masuk form generik bakal bikin dua-duanya
/// berantakan.
///
/// **Nggak ada rumus GUM/ILAC-G8 di sini.** Backend yang ngitung ketidakpastian,
/// U95% lingkungan, dan keputusan PASS/FAIL (`Aturan Bisnis Inti.md`) — layar
/// ini cuma nangkep angka mentah lalu ngirim sekali di akhir.
/// Cara ngisi worksheet: diketik sendiri, atau difoto sekali lalu kolomnya
/// keisi otomatis.
enum CaraIsi { manual, foto }

class PhCalibrationInputScreen extends ConsumerStatefulWidget {
  const PhCalibrationInputScreen({super.key});

  @override
  ConsumerState<PhCalibrationInputScreen> createState() =>
      _PhCalibrationInputScreenState();
}

class _PhCalibrationInputScreenState
    extends ConsumerState<PhCalibrationInputScreen> {
  /// `null` = teknisi belum milih. Gerbang ini sengaja di depan, bukan tombol
  /// kamera yang nyempil di tengah form: keputusan "difoto atau diketik" itu
  /// diambil sekali di awal, sebelum tangan kotor kena larutan buffer.
  CaraIsi? _cara;

  /// Hasil baca tabel dari foto di gerbang, dibawa masuk ke wizard buat
  /// ngisi kolom pembacaan begitu form-nya kebuka.
  HasilTabelOcr? _hasilFoto;

  bool _memproses = false;

  /// Pilih "Foto" = **kamera langsung kebuka**, bukan cuma nyetel penanda.
  ///
  /// Versi pertama cuma nandain pilihan lalu nunggu teknisi sampai halaman 2
  /// baru nawarin kamera. Itu salah: orang yang milih "Foto" maunya motret
  /// sekarang, bukan ngisi halaman 1 dulu.
  Future<void> _pilih(CaraIsi cara) async {
    if (cara == CaraIsi.manual) {
      setState(() => _cara = cara);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _memproses = true);
    try {
      final foto = await ref.read(sumberFotoProvider).ambil(imageQuality: 100);

      // Batal motret = balik ke gerbang, bukan nyelonong masuk form kosong
      // dalam mode foto — nanti teknisi nunggu kamera yang nggak bakal muncul.
      if (foto == null) {
        if (mounted) setState(() => _memproses = false);
        return;
      }

      final hasil = await ref
          .read(worksheetOcrServiceProvider)
          .bacaTabel(foto, jumlahTitik: PhCalibrationDraft.labelTitik.length);

      if (!mounted) return;

      // Foto gagal dibaca tetap masuk form — teknisi udah di lapangan sama
      // alatnya, nyuruh dia ngulang dari gerbang cuma bikin buntu. Kolomnya
      // kosong, tinggal diketik.
      if (hasil == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.phCalibFotoTabelKosong)),
        );
      }

      setState(() {
        _hasilFoto = hasil;
        _cara = cara;
        _memproses = false;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.phCalibScanError)));
      setState(() => _memproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final standarAsync = ref.watch(standardListProvider);
    final l10n = AppLocalizations.of(context);

    final standar = standarAsync.value;

    final Widget isi;
    if (_memproses) {
      isi = _MembacaFoto(pesan: l10n.phCalibFotoMembaca);
    } else if (_cara == null) {
      isi = _PilihCaraIsi(onPilih: _pilih);
    } else if (standar != null) {
      isi = _Wizard(
        standarList: standar,
        cara: _cara!,
        hasilFotoAwal: _hasilFoto,
      );
    } else if (standarAsync.hasError) {
      isi = _Gagal(onCobaLagi: () => ref.invalidate(standardListProvider));
    } else {
      isi = const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(gradient: AppColors.gradasiLatar(context)),
      child: Scaffold(
        // Latar dipegang Container di atas biar gradasinya nembus ke belakang
        // app bar — kalau Scaffold-nya ikut ngecat, app bar-nya jadi kotak
        // warna rata yang motong bidang.
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.phCalibTitle)),
        body: isi,
      ),
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
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.calibLoadPilihanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.calibRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

/// Thermohygro yang aktif di lab (`FORM VALIDASI.csv`: "adding TH-3 s/d 7").
/// Sentinel di luar rentang biar nggak pernah ketuker sama ID alat asli
/// kalau lab nambah unit baru.
const _thermohygroCustom = '__custom__';
const _thermohygroPresets = ['TH-1', 'TH-2', 'TH-3', 'TH-4', 'TH-5', 'TH-6', 'TH-7'];

/// Controller teks buat satu titik buffer — nilai acuan (+ versi as-found)
/// dan 5×2 pembacaan (pH + suhu) untuk tiap tahap, plus standar buffer yang
/// dipakai KHUSUS titik ini (`PhBufferPoint.standardId`).
class _TitikControllers {
  _TitikControllers()
    : nilaiAcuan = TextEditingController(),
      nilaiAcuanSebelum = TextEditingController(),
      sebelumPh = List.generate(5, (_) => TextEditingController()),
      sebelumSuhu = List.generate(5, (_) => TextEditingController()),
      sesudahPh = List.generate(5, (_) => TextEditingController()),
      sesudahSuhu = List.generate(5, (_) => TextEditingController());

  /// Nilai buffer yang udah dikoreksi suhu — dikirim sebagai `titik_ukur`.
  /// Sengaja **nggak** dikasih nilai default (dulu '3.99'/'7'/'10.01'): angka
  /// bulat itu nilai mentah sertifikat, dan kalau kekirim sebagai acuan,
  /// koreksi suhunya ilang tanpa error — hasilnya cuma meleset diam-diam.
  final TextEditingController nilaiAcuan;
  final TextEditingController nilaiAcuanSebelum;
  final List<TextEditingController> sebelumPh;
  final List<TextEditingController> sebelumSuhu;
  final List<TextEditingController> sesudahPh;
  final List<TextEditingController> sesudahSuhu;

  /// Mis. "pH Buffer Solution 4" — beda dari standar sesi (Termometer &
  /// Sensor Std.), lihat komentar di [PhBufferPoint.standardId].
  Standard? standarBuffer;

  /// Indeks pembacaan yang diisi hasil scan kamera dan **belum dikonfirmasi
  /// teknisi**. Backend nolak approve selama masih ada yang belum dicentang
  /// (`perlu_verifikasi`), jadi ini bukan sekadar hiasan UI.
  ///
  /// Angka hasil OCR sengaja nggak langsung dianggap sah: yang difoto itu
  /// layar alat yang lagi diuji — kalau salah baca dan lolos, angkanya masuk
  /// sertifikat yang dipegang pelanggan.
  final Set<int> ocrSebelum = {};
  final Set<int> ocrSesudah = {};

  /// Teks OCR mentah per indeks, dikirim ke backend sebagai `ocr_raw_text`.
  final Map<int, String> teksOcrSebelum = {};
  final Map<int, String> teksOcrSesudah = {};

  List<TextEditingController> get semuaKolom => [
    nilaiAcuan,
    nilaiAcuanSebelum,
    ...sebelumPh,
    ...sebelumSuhu,
    ...sesudahPh,
    ...sesudahSuhu,
  ];

  void dispose() {
    for (final c in semuaKolom) {
      c.dispose();
    }
  }
}

/// Pesan setelah foto tabel dibaca. Bungkus tipis di atas
/// [pesanHasilFotoTabel] — logikanya ditaruh di service biar bisa diuji tanpa
/// widget.
String _pesanHasilFoto(AppLocalizations l10n, HasilTabelOcr hasil, int terisi) {
  return pesanHasilFotoTabel(
    terisi: terisi,
    diharapkan: hasil.jumlahSelDiharapkan,
    terdeteksi: hasil.jumlahAngkaTerdeteksi,
    takTerbaca: l10n.phCalibFotoTabelTakTerbaca,
    posisiKacau: l10n.phCalibFotoTabelPosisiKacau,
    berhasil: l10n.phCalibFotoTabelHasil,
    sisa: l10n.phCalibFotoTabelSisa,
  );
}

/// Dua kolom sebaris. Dipakai buat pasangan yang di worksheet emang
/// sebelahan (Merk/Type, Rentang/Kapasitas, Technician ID/Method).
class _PasanganKolom extends StatelessWidget {
  const _PasanganKolom({
    required this.kiriLabel,
    required this.kiriController,
    required this.kananLabel,
    required this.kananController,
  });

  final String kiriLabel;
  final TextEditingController kiriController;
  final String kananLabel;
  final TextEditingController kananController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(label: kiriLabel, controller: kiriController),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppTextField(label: kananLabel, controller: kananController),
        ),
      ],
    );
  }
}

/// Layar tunggu waktu foto lagi dibaca.
///
/// Bukan spinner telanjang: baca satu tabel penuh bisa beberapa detik di HP
/// kelas menengah, dan layar diam tanpa keterangan bikin teknisi ngira
/// app-nya nge-hang lalu nekan-nekan lagi.
class _MembacaFoto extends StatelessWidget {
  const _MembacaFoto({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gerbang depan: diketik manual, atau difoto sekali.
///
/// Ditaruh **sebelum** halaman 1 karena ini keputusan alur kerja, bukan
/// preferensi tampilan. Teknisi yang mau motret worksheet nggak perlu ngisi
/// apa pun dulu — dia motret, kolomnya keisi, tinggal dikoreksi.
class _PilihCaraIsi extends StatelessWidget {
  const _PilihCaraIsi({required this.onPilih});

  final ValueChanged<CaraIsi> onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.phCalibCaraJudul,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.phCalibCaraSub,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _KartuCara(
          ikon: Icons.photo_camera_outlined,
          judul: l10n.phCalibCaraFoto,
          keterangan: l10n.phCalibCaraFotoKeterangan,
          utama: true,
          onTap: () => onPilih(CaraIsi.foto),
        ),
        const SizedBox(height: AppSpacing.md),
        _KartuCara(
          ikon: Icons.edit_outlined,
          judul: l10n.phCalibCaraManual,
          keterangan: l10n.phCalibCaraManualKeterangan,
          utama: false,
          onTap: () => onPilih(CaraIsi.manual),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Dikasih tahu di depan, bukan pas angkanya udah masuk: teknisi yang
        // ngira foto langsung sah bakal ngelewatin pengecekan, dan angka
        // salah baca itu masuk sertifikat.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.phCalibCaraCatatan,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KartuCara extends StatelessWidget {
  const _KartuCara({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.utama,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final bool utama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aksen = utama ? AppColors.success : theme.colorScheme.onSurfaceVariant;

    return SoftRaised(
      onTap: onTap,
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: aksen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(ikon, size: 26, color: aksen),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keterangan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Wizard extends ConsumerStatefulWidget {
  const _Wizard({
    required this.standarList,
    this.cara = CaraIsi.manual,
    this.hasilFotoAwal,
  });

  /// Dipilih di gerbang depan.
  final CaraIsi cara;

  /// Hasil baca tabel dari foto yang diambil **di gerbang**, sebelum form
  /// kebuka. Ditempel ke kolom pembacaan waktu wizard di-init.
  final HasilTabelOcr? hasilFotoAwal;

  final List<Standard> standarList;

  @override
  ConsumerState<_Wizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<_Wizard> {
  static const _jumlahLangkah = 2;

  final _pageController = PageController();
  int _langkah = 0;

  EquipmentLookup? _alat;
  Standard? _standar;
  DateTime _tanggal = DateTime.now();
  DateTime? _tanggalTerima;
  LokasiKalibrasi _lokasi = LokasiKalibrasi.lab;
  final _nomorOrder = TextEditingController();

  // ---- Kolom kepala worksheet (SIDIK-FM-CAL-2403) -------------------------
  //
  // Semuanya kolom ISIAN, bukan label read-only. Sempat dibikin read-only
  // dengan alasan "biar nomor seri nggak beda-beda tiap sesi", tapi itu salah
  // buat pekerjaan lapangan: worksheet diisi di tempat pelanggan, dan yang
  // tertulis di kertas kadang beda dari yang kedaftar (alat diganti, label
  // kebaca lain, order nyusul). Yang dikirim ke sertifikat harus yang
  // dilihat teknisi di lapangan.
  //
  // Kolom yang datanya udah ada di master alat tetap diisi otomatis begitu
  // alatnya dipilih — teknisi tinggal koreksi kalau beda, bukan ngetik dari nol.
  final _certificateNumber = TextEditingController();
  final _namaAlat = TextEditingController();
  final _merk = TextEditingController();
  final _type = TextEditingController();
  final _noSeri = TextEditingController();
  final _rentangUkur = TextEditingController();
  final _kapasitasMax = TextEditingController();
  final _resolusiAlat = TextEditingController();
  final _namaCustomer = TextEditingController();
  final _alamatCustomer = TextEditingController();
  final _technicianId = TextEditingController();
  final _calibrationMethod = TextEditingController();

  // ---- Kaki halaman 2 -----------------------------------------------------
  DateTime? _issuanceDate;

  /// **Inisial** (mis. `NR`) — sesuai worksheet, yang ngitung cukup inisial.
  final _calculatedBy = TextEditingController();

  /// **Nama asli** (mis. `Alex Misramto`) — ini yang tanda tangan sertifikat,
  /// jadi nggak boleh disingkat.
  final _signedBy = TextEditingController();

  /// Isi kolom kepala dari alat yang baru dipilih.
  ///
  /// Cuma ngisi yang MASIH KOSONG. Kalau teknisi udah ngoreksi sesuatu (atau
  /// hasil foto udah nempel di situ), ganti alat nggak boleh ngehapus
  /// kerjaannya.
  void _isiDariAlat(EquipmentLookup alat) {
    void isi(TextEditingController c, String nilai) {
      if (c.text.trim().isEmpty && nilai.trim().isNotEmpty) c.text = nilai;
    }

    isi(_namaAlat, alat.namaAlat);
    isi(_merk, alat.merk);
    isi(_type, alat.model);
    isi(_noSeri, alat.serialNumber);
    isi(_rentangUkur, alat.rentangTeks ?? '');
    isi(_kapasitasMax, alat.kapasitasTeks ?? '');
    isi(_resolusiAlat, alat.resolusiTeks ?? '');
    isi(_namaCustomer, alat.pelangganNama);
  }
  String _thermohygroPreset = 'TH-3';
  final _thermohygro = TextEditingController(text: 'TH-3');

  /// Di-generate SEKALI waktu layar dibuka (bukan tiap tap tombol) — kalau
  /// teknisi tap "Kirim" berkali-kali (mis. sinyal lemot, nungguin respons),
  /// backend ngenalin ini submission yang sama lewat `client_request_id`,
  /// bukan bikin sesi dobel (`docs/kontrak-api.md` §4).
  final _clientRequestId = generateUuidV4();

  final _suhuAwal = TextEditingController();
  final _suhuAkhir = TextEditingController();
  final _kelembabanAwal = TextEditingController();
  final _kelembabanAkhir = TextEditingController();
  final _suhuKoreksi = TextEditingController();
  final _kelembabanKoreksi = TextEditingController();
  final _suhuUStd = TextEditingController();
  final _kelembabanUStd = TextEditingController();

  late final Map<String, _TitikControllers> _titik = {
    for (final label in PhCalibrationDraft.labelTitik) label: _TitikControllers(),
  };

  bool _mengirim = false;

  @override
  void initState() {
    super.initState();

    // Foto dari gerbang ditempel begitu form kebuka. Ditaruh di
    // `addPostFrameCallback` karena `_terapkanTabel` manggil `setState` dan
    // nampilin SnackBar — dua-duanya butuh frame pertama udah jadi.
    final hasil = widget.hasilFotoAwal;
    if (hasil == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final terisi = _terapkanTabel(hasil, sebelum: false);
      setState(() {});

      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_pesanHasilFoto(l10n, hasil, terisi)),
        ),
      );

      // Langsung dibawa ke halaman data: yang barusan difoto itu tabelnya,
      // jadi yang mau dilihat teknisi ya hasil tempelannya — bukan halaman
      // identitas yang belum dia sentuh.
      if (terisi > 0) _keLangkah(1);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nomorOrder,
      _thermohygro,
      _suhuAwal,
      _suhuAkhir,
      _kelembabanAwal,
      _kelembabanAkhir,
      _suhuKoreksi,
      _kelembabanKoreksi,
      _suhuUStd,
      _kelembabanUStd,
    ]) {
      c.dispose();
    }
    for (final t in _titik.values) {
      t.dispose();
    }
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _keLangkah(int langkah) {
    // Keyboard ditutup dulu: pindah halaman sambil keyboard masih naik bikin
    // halaman baru kebuka setengah ketutup, dan field pertamanya nggak
    // kelihatan.
    FocusScope.of(context).unfocus();
    setState(() => _langkah = langkah);
    _pageController.animateToPage(
      langkah,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

  }

  void _keluhan(String pesan, {int? diLangkah}) {
    if (diLangkah != null && diLangkah != _langkah) _keLangkah(diLangkah);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  /// Validasi Halaman 1. Dipakai dua kali: waktu tap "Lanjutkan" dan waktu
  /// submit — teknisi bisa balik ke Halaman 1 lalu ngosongin field, jadi
  /// ngecek sekali di pintu masuk aja nggak cukup.
  bool _langkah1Valid(AppLocalizations l10n, {bool lapor = true}) {
    if (_alat == null) {
      if (lapor) _keluhan(l10n.calibValidasiAlat, diLangkah: 0);
      return false;
    }
    if (_standar == null) {
      if (lapor) _keluhan(l10n.calibValidasiStandar, diLangkah: 0);
      return false;
    }

    final lingkunganLengkap = [
      _suhuAwal,
      _suhuAkhir,
      _kelembabanAwal,
      _kelembabanAkhir,
    ].every((c) => _parse(c.text) != null);

    if (!lingkunganLengkap) {
      if (lapor) _keluhan(l10n.phCalibValidasiLingkungan, diLangkah: 0);
      return false;
    }

    return true;
  }

  PhBufferPoint? _bacaTitik(String label) {
    final c = _titik[label]!;
    final nilaiAcuan = _parse(c.nilaiAcuan.text);
    if (nilaiAcuan == null) return null;

    final titik = PhBufferPoint(
      label: label,
      titikUkur: nilaiAcuan,
      titikUkurSebelum: _parse(c.nilaiAcuanSebelum.text),
      standardId: c.standarBuffer?.id,
    );

    for (var i = 0; i < 5; i++) {
      final phSebelum = _parse(c.sebelumPh[i].text);
      if (phSebelum != null) {
        titik.sebelumAdjustment[i] = PhReading(
          ph: phSebelum,
          suhu: _parse(c.sebelumSuhu[i].text),
        );
      }

      final phSesudah = _parse(c.sesudahPh[i].text);
      if (phSesudah != null) {
        titik.sesudahAdjustment[i] = PhReading(
          ph: phSesudah,
          suhu: _parse(c.sesudahSuhu[i].text),
        );
      }
    }

    return titik;
  }

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);

    if (!_langkah1Valid(l10n)) return;

    if (_titik.values.any((c) => c.standarBuffer == null)) {
      _keluhan(l10n.phCalibValidasiStandarBuffer, diLangkah: 1);
      return;
    }

    final points = <PhBufferPoint>[];
    for (final label in PhCalibrationDraft.labelTitik) {
      final titik = _bacaTitik(label);
      if (titik == null) {
        _keluhan(l10n.phCalibValidasiNilaiAcuan, diLangkah: 1);
        return;
      }
      if (titik.sesudahAdjustment.whereType<PhReading>().length <
          PhCalibrationDraft.minPengulangan) {
        _keluhan(
          l10n.phCalibValidasiPembacaan(PhCalibrationDraft.minPengulangan),
          diLangkah: 1,
        );
        return;
      }
      points.add(titik);
    }

    final draftPh =
        PhCalibrationDraft(
            equipmentId: _alat!.id,
            standardId: _standar!.id,
            tanggalKalibrasi: _tanggal,
            thermohygroId: _thermohygro.text.trim(),
            points: points,
          )
          ..suhuAwal = _parse(_suhuAwal.text)
          ..suhuAkhir = _parse(_suhuAkhir.text)
          ..kelembabanAwal = _parse(_kelembabanAwal.text)
          ..kelembabanAkhir = _parse(_kelembabanAkhir.text)
          ..suhuKoreksi = _parse(_suhuKoreksi.text)
          ..kelembabanKoreksi = _parse(_kelembabanKoreksi.text)
          ..suhuUStd = _parse(_suhuUStd.text)
          ..kelembabanUStd = _parse(_kelembabanUStd.text)
          ..nomorOrder = _nomorOrder.text.trim()
          ..tanggalTerima = _tanggalTerima;

    setState(() => _mengirim = true);

    final hasil = await ref
        .read(calibrationSubmitProvider.notifier)
        .submit(
          draftPh.toGenericDraft(
            clientRequestId: _clientRequestId,
            lokasi: _lokasi,
            simpanSebagaiDraft: draft,
            // Dilacak dari jejak scan, bukan dari penanda "belum
            // dikonfirmasi": teknisi yang udah nyentang semua tetap ngirim
            // sesi hasil scan, dan itu yang mau kecatat di statistik lab.
            adaScanKamera: _titik.values.any(
              (t) => t.teksOcrSesudah.isNotEmpty || t.teksOcrSebelum.isNotEmpty,
            ),
          ),
        );

    if (!mounted) return;
    setState(() => _mengirim = false);

    // Hasil kirim ditampilin sebagai sheet, bukan SnackBar: teknisi baru aja
    // ngisi puluhan angka, dan SnackBar yang nongol 3 detik lalu ilang sendiri
    // nggak cukup buat mastiin datanya kekirim atau nggak.
    if (hasil != null) {
      await ResultSheet.tampilkan(
        context,
        status: HasilKirim.berhasil,
        judul: draft ? l10n.sheetDraftBerhasil : l10n.sheetKirimBerhasil,
        pesan: draft
            ? l10n.sheetDraftBerhasilPesan
            : l10n.sheetKirimBerhasilPesan,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      final error = ref.read(calibrationSubmitProvider).error;
      await ResultSheet.tampilkan(
        context,
        status: HasilKirim.gagal,
        judul: l10n.sheetKirimGagal,
        pesan: l10n.calibGagal(error.toString()),
        // Layar sengaja nggak ditutup pas gagal — isian formnya masih utuh,
        // jadi teknisi tinggal nekan kirim lagi tanpa ngetik ulang.
        labelAksi: l10n.sheetCobaLagi,
        onAksi: () => _submit(draft: draft),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _StepHeader(
          langkah: _langkah,
          total: _jumlahLangkah,
          judul: [l10n.phCalibLangkahIdentitas, l10n.phCalibLangkahHasil],
          onPilih: _keLangkah,
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            // Geser bebas sengaja dimatiin. Halaman ini isinya kolom angka
            // rapat — geser horizontal yang nggak sengaja waktu ngetik bakal
            // mindahin halaman dan bikin teknisi kehilangan tempat.
            physics: const NeverScrollableScrollPhysics(),
            children: [_halaman1(l10n), _halaman2(l10n)],
          ),
        ),
        _ActionBar(
          langkah: _langkah,
          mengirim: _mengirim,
          onLanjut: () {
            if (_langkah1Valid(l10n)) _keLangkah(1);
          },
          onKembali: () => _keLangkah(0),
          onKirim: () => _submit(draft: false),
          onDraft: () => _submit(draft: true),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- halaman 1

  Widget _halaman1(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final equipmentAsync = ref.watch(
      // pH Meter selalu kategori "instrumen-analitik" — nggak ada dropdown
      // kategori di layar ini, beda sama form generik.
      equipmentLookupProvider(PhCalibrationDraft.kategori),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        _Seksi(
          ikon: Icons.science_outlined,
          judul: l10n.phCalibIdentitasAlat,
          catatan: l10n.phCalibPelangganOtomatis,
          children: [
            equipmentAsync.when(
              skipLoadingOnReload: true,
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.calibAlatKosong),
              data: (list) => _Dropdown<EquipmentLookup>(
                label: l10n.calibAlat,
                nilai: _alat,
                hint: list.isEmpty ? l10n.calibAlatKosong : l10n.calibAlatHint,
                items: [
                  for (final e in list)
                    DropdownMenuItem(
                      value: e,
                      child: Text('${e.namaAlat} · ${e.serialNumber}'),
                    ),
                ],
                onChanged: list.isEmpty
                    ? null
                    : (value) => setState(() {
                        _alat = value;
                        if (value != null) _isiDariAlat(value);
                      }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Kolom kepala worksheet — ISIAN, bukan label. Yang udah kedaftar
            // di master alat keisi sendiri begitu alat dipilih; sisanya
            // diketik teknisi atau nempel dari hasil foto.
            AppTextField(label: l10n.phCalibIdNamaAlat, controller: _namaAlat),
            const SizedBox(height: AppSpacing.sm),
            _PasanganKolom(
              kiriLabel: l10n.phCalibIdMerk,
              kiriController: _merk,
              kananLabel: l10n.phCalibIdType,
              kananController: _type,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.phCalibIdNoSeri, controller: _noSeri),
            const SizedBox(height: AppSpacing.sm),
            _PasanganKolom(
              kiriLabel: l10n.phCalibIdRentang,
              kiriController: _rentangUkur,
              kananLabel: l10n.phCalibIdKapasitasMax,
              kananController: _kapasitasMax,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.phCalibIdResolusi,
              controller: _resolusiAlat,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        _Seksi(
          ikon: Icons.badge_outlined,
          judul: l10n.phCalibIdentitasCustomer,
          children: [
            AppTextField(
              label: l10n.phCalibIdCustomer,
              controller: _namaCustomer,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.phCalibIdAlamatCustomer,
              controller: _alamatCustomer,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PasanganKolom(
              kiriLabel: l10n.phCalibIdCertificateNumber,
              kiriController: _certificateNumber,
              kananLabel: l10n.phCalibIdOrderNumber,
              kananController: _nomorOrder,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        _Seksi(
          ikon: Icons.assignment_outlined,
          judul: l10n.phCalibPengerjaan,
          children: [
            _Dropdown<Standard>(
              label: l10n.phCalibStandarSesi,
              nilai: _standar,
              hint: l10n.phCalibStandarSesiHint,
              items: _itemStandar(widget.standarList, l10n),
              onChanged: (value) => setState(() => _standar = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _Dropdown<LokasiKalibrasi>(
              label: l10n.calibLokasi,
              nilai: _lokasi,
              items: [
                DropdownMenuItem(
                  value: LokasiKalibrasi.lab,
                  child: Text(l10n.calibLokasiLab),
                ),
                DropdownMenuItem(
                  value: LokasiKalibrasi.onsite,
                  child: Text(l10n.calibLokasiOnsite),
                ),
              ],
              onChanged: (value) => setState(() => _lokasi = value!),
            ),
            const SizedBox(height: AppSpacing.md),
            // Nomor Order pindah ke seksi Customer, ngikutin worksheet — di
            // kertas dia sebaris sama Certificate Number, bukan di blok
            // pengerjaan.
            _PasanganKolom(
              kiriLabel: l10n.phCalibIdTechnicianId,
              kiriController: _technicianId,
              kananLabel: l10n.phCalibIdCalibrationMethod,
              kananController: _calibrationMethod,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PilihTanggal(
                    label: l10n.calibTanggalTerima,
                    nilai: _tanggalTerima,
                    onPilih: (v) => setState(() => _tanggalTerima = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _PilihTanggal(
                    label: l10n.calibTanggal,
                    nilai: _tanggal,
                    onPilih: (v) => setState(() => _tanggal = v!),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        _Seksi(
          ikon: Icons.thermostat_outlined,
          judul: l10n.phCalibKondisiLingkungan,
          children: [
            _Dropdown<String>(
              label: l10n.phCalibThermohygro,
              nilai: _thermohygroPreset,
              items: [
                for (final th in _thermohygroPresets)
                  DropdownMenuItem(value: th, child: Text(th)),
                DropdownMenuItem(
                  value: _thermohygroCustom,
                  child: Text(l10n.phCalibThermohygroCustom),
                ),
              ],
              onChanged: (value) => setState(() {
                _thermohygroPreset = value!;
                if (value != _thermohygroCustom) _thermohygro.text = value;
              }),
            ),
            if (_thermohygroPreset == _thermohygroCustom) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.phCalibThermohygro,
                controller: _thermohygro,
                hint: l10n.phCalibThermohygroHint,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _PasanganAngka(
              kiri: l10n.phCalibSuhuAwal,
              kanan: l10n.phCalibSuhuAkhir,
              kiriController: _suhuAwal,
              kananController: _suhuAkhir,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PasanganAngka(
              kiri: l10n.phCalibKelembabanAwal,
              kanan: l10n.phCalibKelembabanAkhir,
              kiriController: _kelembabanAwal,
              kananController: _kelembabanAkhir,
            ),
            const SizedBox(height: AppSpacing.md),
            _Pemisah(teks: l10n.phCalibOpsional),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.phCalibDariSertifikatTh,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PasanganAngka(
              kiri: l10n.phCalibKoreksiSuhu,
              kanan: l10n.phCalibKoreksiKelembaban,
              kiriController: _suhuKoreksi,
              kananController: _kelembabanKoreksi,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PasanganAngka(
              kiri: l10n.phCalibU95Suhu,
              kanan: l10n.phCalibU95Kelembaban,
              kiriController: _suhuUStd,
              kananController: _kelembabanUStd,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CatatanHitung(pesan: l10n.phCalibDihitungServer),
      ],
    );
  }

  List<DropdownMenuItem<Standard>> _itemStandar(
    List<Standard> list,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return [
      for (final s in list)
        DropdownMenuItem(
          value: s,
          enabled: s.masihBerlaku,
          child: Text(
            s.masihBerlaku ? s.nama : '${s.nama} (${l10n.calibStandarKadaluarsa})',
            style: s.masihBerlaku
                ? null
                : TextStyle(color: theme.colorScheme.error),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------- halaman 2

  /// Foto satu tabel worksheet → isi seluruh kolomnya sekaligus.
  ///
  /// Beda dari tombol scan per-sel (yang motret layar pH meter): ini motret
  /// **lembar worksheet yang udah diisi di lapangan**, dan satu tabel isinya
  /// ketiga buffer × 5 pengulangan. Makanya tombolnya di level halaman, bukan
  /// di dalam kartu titik.
  Future<void> _fotoTabel({required bool sebelum}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ocr = ref.read(worksheetOcrServiceProvider);

    try {
      final foto = await ref.read(sumberFotoProvider).ambil(
        // Tabel penuh angka kecil: kompresi agresif bikin koma ilang dan
        // `4,04` kebaca `404`.
        imageQuality: 100,
      );
      if (foto == null || !mounted) return;

      final hasil = await ocr.bacaTabel(
        foto,
        jumlahTitik: PhCalibrationDraft.labelTitik.length,
      );

      if (!mounted) return;

      if (hasil == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.phCalibFotoTabelKosong)),
        );
        return;
      }

      final terisi = _terapkanTabel(hasil, sebelum: sebelum);
      setState(() {});

      messenger.showSnackBar(
        SnackBar(
          content: Text(_pesanHasilFoto(l10n, hasil, terisi)),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.phCalibScanError)));
      }
    }
    // Sengaja nggak nutup `ocr` di sini: instance-nya dipegang provider dan
    // dipakai ulang tiap scan. Kalau ditutup habis sekali pakai, foto kedua
    // gagal dengan error native yang nggak nyambung ke sebabnya.
  }

  /// Tempelin hasil baca tabel ke kolom-kolom form. Balikin jumlah sel yang
  /// beneran keisi.
  ///
  /// **Cuma sel kosong yang diisi.** Ini aturan intinya: teknisi boleh foto
  /// ulang berkali-kali buat nambal yang kurang, dan angka yang udah dia
  /// betulin manual nggak boleh keganti sama hasil foto berikutnya.
  int _terapkanTabel(HasilTabelOcr hasil, {required bool sebelum}) {
    var terisi = 0;

    for (var baris = 0; baris < hasil.baris.length; baris++) {
      final isi = hasil.baris[baris];

      for (var t = 0; t < PhCalibrationDraft.labelTitik.length; t++) {
        final c = _titik[PhCalibrationDraft.labelTitik[t]]!;
        if (baris >= c.sesudahPh.length) continue;

        final kolomPh = sebelum ? c.sebelumPh[baris] : c.sesudahPh[baris];
        final kolomSuhu = sebelum ? c.sebelumSuhu[baris] : c.sesudahSuhu[baris];

        var kena = false;

        // Aturan "jangan nimpa yang udah keisi" ada di [GabungTabel], bukan di
        // sini — biar bisa diuji tanpa kamera. Lihat komentarnya di sana.
        final phBaru = GabungTabel.nilaiBaru(
          kolomPh.text,
          t < isi.ph.length ? isi.ph[t] : null,
        );
        if (phBaru != null) {
          kolomPh.text = phBaru;
          kena = true;
          terisi++;
        }

        final suhuBaru = GabungTabel.nilaiBaru(
          kolomSuhu.text,
          t < isi.suhu.length ? isi.suhu[t] : null,
        );
        if (suhuBaru != null) {
          kolomSuhu.text = suhuBaru;
          kena = true;
          terisi++;
        }

        // Ditandai butuh konfirmasi, sama kayak hasil scan layar — backend
        // nolak approve selama masih ada yang belum dicentang teknisi.
        if (kena) {
          (sebelum ? c.ocrSebelum : c.ocrSesudah).add(baris);
          (sebelum ? c.teksOcrSebelum : c.teksOcrSesudah)[baris] =
              hasil.teksMentah;
        }
      }
    }

    return terisi;
  }

  Widget _halaman2(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _KartuFotoTabel(
          onFoto: (sebelum) => _fotoTabel(sebelum: sebelum),
          sedangKirim: _mengirim,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < PhCalibrationDraft.labelTitik.length; i++) ...[
          _BufferPointCard(
            // Kolom di kartu ini mirip semua ("BACAAN 1" muncul tiga kali kalau
            // ketiga kartu kebuka), jadi kartunya dikasih key biar test bisa
            // nyasar ke titik yang tepat, bukan ngandelin urutan global.
            key: ValueKey('titik-${PhCalibrationDraft.labelTitik[i]}'),
            label: PhCalibrationDraft.labelTitik[i],
            controllers: _titik[PhCalibrationDraft.labelTitik[i]]!,
            itemStandar: _itemStandar(widget.standarList, l10n),
            // Titik pertama kebuka duluan biar teknisi langsung bisa ngetik;
            // sisanya nutup, jadi bentuk formnya kebaca dulu sebelum keburu
            // ketakutan lihat puluhan kolom sekaligus.
            terbukaAwal: i == 0,
            onStandarChanged: (v) => setState(
              () => _titik[PhCalibrationDraft.labelTitik[i]]!.standarBuffer = v,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Kaki worksheet — Issuance Date + Calculated by / Signed by.
        _Seksi(
          ikon: Icons.draw_outlined,
          judul: l10n.phCalibPengesahan,
          children: [
            _PilihTanggal(
              label: l10n.phCalibIssuanceDate,
              nilai: _issuanceDate,
              onPilih: (v) => setState(() => _issuanceDate = v),
            ),
            const SizedBox(height: AppSpacing.md),
            // Dua kolom ini sengaja beda aturan, sesuai worksheet: yang
            // ngitung cukup INISIAL (`NR`), yang tanda tangan wajib NAMA ASLI
            // (`Alex Misramto`) — nama itu yang kecetak di sertifikat dan yang
            // dipertanggungjawabkan waktu audit.
            AppTextField(
              label: l10n.phCalibCalculatedBy,
              controller: _calculatedBy,
              hint: l10n.phCalibCalculatedByHint,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.phCalibSignedBy,
              controller: _signedBy,
              hint: l10n.phCalibSignedByHint,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CatatanHitung(pesan: l10n.phCalibDihitungServer),
      ],
    );
  }
}

/// Tombol foto tabel worksheet — pintu masuk jalur "isi sekali foto".
///
/// Ditaruh di level halaman, bukan di kartu titik: satu tabel di worksheet
/// isinya **ketiga buffer sekaligus** (3 kolom pH + 3 kolom °C × 5 baris), jadi
/// satu jepretan ngisi tiga kartu sekaligus.
///
/// Dua tombol terpisah (Sesudah / Sebelum) karena worksheet-nya juga dua tabel
/// terpisah. Nanya "ini tabel yang mana" lewat dialog cuma nambah satu ketukan
/// buat informasi yang teknisi udah tahu waktu dia mengarahkan kamera.
class _KartuFotoTabel extends StatelessWidget {
  const _KartuFotoTabel({required this.onFoto, required this.sedangKirim});

  final ValueChanged<bool> onFoto;
  final bool sedangKirim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _Seksi(
      ikon: Icons.document_scanner_outlined,
      judul: l10n.phCalibFotoTabel,
      catatan: l10n.phCalibFotoTabelInfo,
      children: [
        // Ditumpuk, bukan berdampingan. Label tahapnya panjang ("Sesudah
        // adjustment (as left)") dan di layar HP 390px dua tombol sebaris
        // langsung overflow — labelnya nggak bisa dipendekin karena bedanya
        // justru yang harus kebaca jelas: salah tahap = angka as-found yang
        // kesertifikasi.
        AppButton(
          label: l10n.phCalibFotoTabelSesudah,
          icon: Icons.photo_camera_outlined,
          onPressed: sedangKirim ? null : () => onFoto(false),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.phCalibFotoTabelSebelum,
          icon: Icons.photo_camera_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: sedangKirim ? null : () => onFoto(true),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.phCalibOcrBelumDikonfirmasi,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Strip langkah di atas form — kaca beneran (blur) karena dia kecil, diam, dan
/// cuma satu di layar. Kartu isi form pakai [SoftRaised] yang nol biaya raster,
/// lihat alasannya di `glass_surface.dart`.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.langkah,
    required this.total,
    required this.judul,
    required this.onPilih,
  });

  final int langkah;
  final int total;
  final List<String> judul;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        radius: AppSpacing.radiusLg,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StepPill(
                      nomor: i + 1,
                      judul: judul[i],
                      aktif: i == langkah,
                      // Cuma boleh mundur lewat pill. Maju harus lewat
                      // "Lanjutkan" supaya Halaman 1 kevalidasi dulu — kalau
                      // bisa lompat, teknisi bisa ngisi 30 angka lalu baru
                      // ketahuan alatnya belum kepilih.
                      onTap: i < langkah ? () => onPilih(i) : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Text(
                l10n.phCalibLangkahKe(langkah + 1, total),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.nomor,
    required this.judul,
    required this.aktif,
    this.onTap,
  });

  final int nomor;
  final String judul;
  final bool aktif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selesai = onTap != null;
    final warna = aktif
        ? theme.colorScheme.primary
        : selesai
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: warna.withValues(alpha: aktif ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: warna.withValues(alpha: aktif ? 0.45 : 0.16),
            ),
          ),
          child: Row(
            children: [
              // Angka diganti centang begitu langkahnya kelar — tanda "beres"
              // yang kebaca tanpa harus ngitung posisi.
              _Bulatan(
                warna: warna,
                anak: selesai
                    ? Icon(Icons.check, size: 12, color: warna)
                    : Text(
                        '$nomor',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: warna,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: aktif ? theme.colorScheme.onSurface : warna,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bulatan extends StatelessWidget {
  const _Bulatan({required this.warna, required this.anak});

  final Color warna;
  final Widget anak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: warna.withValues(alpha: 0.16),
      ),
      child: anak,
    );
  }
}

/// Bar aksi yang nempel di bawah — kaca beneran, sama alasannya kayak
/// [_StepHeader]: kecil, diam, satu di layar.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.langkah,
    required this.mengirim,
    required this.onLanjut,
    required this.onKembali,
    required this.onKirim,
    required this.onDraft,
  });

  final int langkah;
  final bool mengirim;
  final VoidCallback onLanjut;
  final VoidCallback onKembali;
  final VoidCallback onKirim;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: GlassSurface(
          radius: AppSpacing.radiusLg,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: langkah == 0
              ? AppButton(
                  label: l10n.phCalibLanjutkan,
                  trailingIcon: Icons.arrow_forward,
                  onPressed: onLanjut,
                )
              : Column(
                  children: [
                    AppButton(
                      label: l10n.calibKirimApproval,
                      isLoading: mengirim,
                      onPressed: mengirim ? null : onKirim,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        // Sengaja tanpa ikon. Dua tombol ini bagi dua lebar
                        // layar, dan di HP 390px "← KEMBALI" nggak muat —
                        // ikonnya yang bikin overflow, bukan teksnya.
                        Expanded(
                          child: AppButton(
                            label: l10n.phCalibKembali,
                            variant: AppButtonVariant.secondary,
                            onPressed: mengirim ? null : onKembali,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: l10n.calibSimpanDraft,
                            variant: AppButtonVariant.secondary,
                            isLoading: mengirim,
                            onPressed: mengirim ? null : onDraft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Kartu satu bagian form. Timbul lembut, bukan kaca — kartu ini panjang dan
/// ikut discroll, dan `BackdropFilter` di permukaan segitu bikin ngelag di HP
/// low-end tiap kali teknisi ngetik.
class _Seksi extends StatelessWidget {
  const _Seksi({
    required this.ikon,
    required this.judul,
    required this.children,
    this.catatan,
  });

  final IconData ikon;
  final String judul;
  final List<Widget> children;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftRaised(
      radius: AppSpacing.radiusLg + 4,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Bulatan(warna: theme.colorScheme.primary, anak: Icon(ikon, size: 12)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  judul.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          if (catatan != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              catatan!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Dropdown dengan label HURUF BESAR di atas — biar sebentuk sama
/// [AppTextField], yang labelnya juga di luar kotak.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.nilai,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? nilai;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<T>(
          initialValue: nilai,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PilihTanggal extends StatelessWidget {
  const _PilihTanggal({
    required this.label,
    required this.nilai,
    required this.onPilih,
  });

  final String label;
  final DateTime? nilai;
  final ValueChanged<DateTime?> onPilih;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final dipilih = await showDatePicker(
          context: context,
          initialDate: nilai ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (dipilih != null) onPilih(dipilih);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          nilai == null ? '—' : '${nilai!.day}/${nilai!.month}/${nilai!.year}',
        ),
      ),
    );
  }
}

class _PasanganAngka extends StatelessWidget {
  const _PasanganAngka({
    required this.kiri,
    required this.kanan,
    required this.kiriController,
    required this.kananController,
  });

  final String kiri;
  final String kanan;
  final TextEditingController kiriController;
  final TextEditingController kananController;

  @override
  Widget build(BuildContext context) {
    return Row(
      // start, bukan center: label yang turun baris bikin tinggi kedua kolom
      // beda, dan kalau center kotak inputnya jadi miring sebelah.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField.measurement(label: kiri, controller: kiriController),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppTextField.measurement(label: kanan, controller: kananController),
        ),
      ],
    );
  }
}

class _Pemisah extends StatelessWidget {
  const _Pemisah({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            teks.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}

/// Pengingat kecil bahwa angka turunan bukan urusan form ini. Ditaruh di kaki
/// tiap halaman karena pertanyaan "kok nggak ada kolom koreksi & U95%?" itu
/// yang paling sering muncul waktu form ini dicoba.
class _CatatanHitung extends StatelessWidget {
  const _CatatanHitung({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            pesan,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu titik buffer — bisa dilipat, dan judulnya bawa penunjuk progres.
///
/// Kalau tiga titik dibuka barengan, halaman ini punya 60+ kolom. Digulung
/// lurus begitu, teknisi gampang kehilangan jejak: nggak kelihatan titik mana
/// yang udah kelar, dan satu kolom kelewat baru ketahuan pas submit ditolak
/// validasi — setelah scroll jauh ke bawah.
///
/// Dua tahap (sebelum/sesudah adjustment) juga dipisah jadi tab, bukan
/// ditumpuk: sepuluh baris angka yang mirip, beda cuma di judul di tengahnya,
/// gampang ketuker.
class _BufferPointCard extends StatefulWidget {
  const _BufferPointCard({
    super.key,
    required this.label,
    required this.controllers,
    required this.itemStandar,
    required this.onStandarChanged,
    this.terbukaAwal = false,
  });

  final String label;
  final _TitikControllers controllers;
  final List<DropdownMenuItem<Standard>> itemStandar;
  final ValueChanged<Standard?> onStandarChanged;
  final bool terbukaAwal;

  @override
  State<_BufferPointCard> createState() => _BufferPointCardState();
}

class _BufferPointCardState extends State<_BufferPointCard> {
  late bool _terbuka = widget.terbukaAwal;
  bool _lihatSebelum = false;

  @override
  void initState() {
    super.initState();
    // Didengerin biar angka progres di judul ikut gerak waktu teknisi ngetik,
    // bukan cuma pas kartunya dibuka-tutup.
    for (final c in widget.controllers.semuaKolom) {
      c.addListener(_perbarui);
    }
  }

  @override
  void dispose() {
    for (final c in widget.controllers.semuaKolom) {
      c.removeListener(_perbarui);
    }
    super.dispose();
  }

  void _perbarui() {
    if (mounted) setState(() {});
  }

  int get _bacaanSesudah =>
      widget.controllers.sesudahPh.where((c) => c.text.trim().isNotEmpty).length;

  /// Titik ini cukup buat disubmit. Suhu larutan & seluruh tahap "sebelum"
  /// sengaja nggak ikut dihitung — dua-duanya opsional di backend, dan kalau
  /// ikut, lencananya nggak akan pernah hijau padahal datanya udah sah.
  bool get _siap =>
      widget.controllers.nilaiAcuan.text.trim().isNotEmpty &&
      widget.controllers.standarBuffer != null &&
      _bacaanSesudah >= PhCalibrationDraft.minPengulangan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SoftRaised(
      radius: AppSpacing.radiusLg + 4,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _terbuka = !_terbuka),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 4),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.phCalibTitikBuffer(widget.label),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Pecahan, bukan kalimat: "3/5" kebaca sama di bahasa apa pun
                  // dan muat di judul tanpa mendorong apa-apa.
                  _LencanaProgres(terisi: _bacaanSesudah, total: 5, siap: _siap),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _terbuka ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (!_terbuka && _siap)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.phCalibTitikLengkap,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

          if (_terbuka)
            _IsiTitik(
              controllers: widget.controllers,
              itemStandar: widget.itemStandar,
              onStandarChanged: widget.onStandarChanged,
              lihatSebelum: _lihatSebelum,
              onPilihTahap: (v) => setState(() => _lihatSebelum = v),
              onBerubah: _perbarui,
            ),
        ],
      ),
    );
  }
}

/// Lencana pecahan "3/5" di judul titik. Warnanya cuma dua keadaan: netral
/// selama titiknya belum siap disubmit, hijau begitu siap — bukan gradasi
/// bertahap, biar "kelar" kebaca tegas, bukan kira-kira.
class _LencanaProgres extends StatelessWidget {
  const _LencanaProgres({
    required this.terisi,
    required this.total,
    required this.siap,
  });

  final int terisi;
  final int total;
  final bool siap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = siap ? AppColors.success : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$terisi/$total',
        style: theme.textTheme.labelSmall?.copyWith(
          color: warna,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _IsiTitik extends StatelessWidget {
  const _IsiTitik({
    required this.controllers,
    required this.itemStandar,
    required this.onStandarChanged,
    required this.lihatSebelum,
    required this.onPilihTahap,
    required this.onBerubah,
  });

  final _TitikControllers controllers;
  final List<DropdownMenuItem<Standard>> itemStandar;
  final ValueChanged<Standard?> onStandarChanged;
  final bool lihatSebelum;
  final ValueChanged<bool> onPilihTahap;

  /// Dipanggil waktu penanda OCR berubah. Perlu callback sendiri karena
  /// nyentang "sudah dikonfirmasi" nggak ngubah isi controller mana pun —
  /// jadi listener controller di kartu induk nggak kebangun sendiri.
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controllers;
    final sebelum = lihatSebelum;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dropdown<Standard>(
            label: l10n.phCalibStandarBuffer,
            nilai: c.standarBuffer,
            hint: l10n.phCalibStandarBufferHint,
            items: itemStandar,
            onChanged: onStandarChanged,
          ),
          const SizedBox(height: AppSpacing.md),

          _Tab(sebelum: sebelum, onPilih: onPilihTahap),
          const SizedBox(height: AppSpacing.md),

          // Nilai acuan sengaja beda kolom per tahap: suhu larutan waktu
          // pembacaan as-found nggak persis sama dengan waktu as-left, jadi
          // nilai buffer terkoreksinya juga beda tipis.
          AppTextField.measurement(
            label: sebelum
                ? l10n.phCalibNilaiStandarSebelum
                : l10n.phCalibNilaiStandar,
            controller: sebelum ? c.nilaiAcuanSebelum : c.nilaiAcuan,
            satuan: 'pH',
            hint: sebelum ? '4.0092252' : '4.009244572',
          ),
          const SizedBox(height: AppSpacing.xs),
          _Helper(teks: l10n.phCalibNilaiStandarHelper),
          const SizedBox(height: AppSpacing.md),

          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField.measurement(
                          label: l10n.phCalibPembacaanKe(i + 1),
                          controller: sebelum ? c.sebelumPh[i] : c.sesudahPh[i],
                          satuan: 'pH',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField.measurement(
                          label: l10n.phCalibSuhu,
                          controller: sebelum
                              ? c.sebelumSuhu[i]
                              : c.sesudahSuhu[i],
                          satuan: '°C',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _TombolScan(
                        // Nilai acuan tahap ini jadi patokan parser buat milih
                        // angka pH di antara angka lain di layar (mis. suhu).
                        perkiraan: _angka(
                          sebelum ? c.nilaiAcuanSebelum.text : c.nilaiAcuan.text,
                        ),
                        onHasil: (hasil) {
                          (sebelum ? c.sebelumPh[i] : c.sesudahPh[i]).text =
                              _teks(hasil.nilai);
                          if (hasil.suhu != null) {
                            (sebelum ? c.sebelumSuhu[i] : c.sesudahSuhu[i])
                                .text = _teks(hasil.suhu!);
                          }
                          (sebelum ? c.ocrSebelum : c.ocrSesudah).add(i);
                          (sebelum ? c.teksOcrSebelum : c.teksOcrSesudah)[i] =
                              hasil.teksMentah;
                          onBerubah();
                        },
                      ),
                    ],
                  ),
                  if ((sebelum ? c.ocrSebelum : c.ocrSesudah).contains(i))
                    _BarisKonfirmasi(
                      onKonfirmasi: () {
                        (sebelum ? c.ocrSebelum : c.ocrSesudah).remove(i);
                        onBerubah();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Angka dari kolom teks, `null` kalau kosong/nggak valid.
double? _angka(String teks) =>
    double.tryParse(teks.trim().replaceAll(',', '.'));

/// Balik lagi ke teks buat ditaruh di kolom input.
String _teks(double nilai) =>
    nilai.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
      RegExp(r'\.$'),
      '',
    );

/// Tombol foto layar pH meter buat satu baris pembacaan.
///
/// Kameranya lewat `image_picker` (foto sekali jepret), bukan preview
/// langsung — teknisi butuh lihat layar alat stabil dulu baru motret, dan
/// preview langsung malah bikin gampang kejepret waktu angkanya masih goyang.
class _TombolScan extends ConsumerStatefulWidget {
  const _TombolScan({required this.perkiraan, required this.onHasil});

  final double? perkiraan;
  final ValueChanged<HasilOcr> onHasil;

  @override
  ConsumerState<_TombolScan> createState() => _TombolScanState();
}

class _TombolScanState extends ConsumerState<_TombolScan> {
  bool _sibuk = false;

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);
    final ocr = ref.read(ocrServiceProvider);

    try {
      final foto = await ref.read(sumberFotoProvider).ambil(
        // Layar tujuh-segmen nggak butuh resolusi penuh, dan file gede bikin
        // pengenalannya lambat di HP kelas menengah.
        maxWidth: 1600,
      );
      if (foto == null) return;

      final hasil = await ocr.bacaLayar(foto, perkiraan: widget.perkiraan);

      if (!mounted) return;

      if (hasil == null) {
        // Sengaja nggak ngisi apa-apa: angka tebakan yang salah jauh lebih
        // bahaya daripada teknisi ngetik manual.
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.phCalibScanGagal)),
        );
        return;
      }

      widget.onHasil(hasil);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.phCalibScanError)));
    } finally {
      // `ocr` dibiarin hidup — dipegang provider, dipakai ulang tiap scan.
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      onPressed: _sibuk ? null : _scan,
      tooltip: l10n.phCalibScanTooltip,
      icon: _sibuk
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.photo_camera_outlined),
    );
  }
}

/// Penanda "angka ini dari kamera, belum dicek orang".
///
/// Backend nolak approve sesi yang masih punya pembacaan OCR belum
/// terverifikasi, jadi baris ini bukan hiasan — selama masih nongol, sesinya
/// bakal mental waktu diajukan.
class _BarisKonfirmasi extends StatelessWidget {
  const _BarisKonfirmasi({required this.onKonfirmasi});

  final VoidCallback onKonfirmasi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.phCalibOcrBelumDikonfirmasi,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: onKonfirmasi,
            child: Text(l10n.phCalibOcrKonfirmasi),
          ),
        ],
      ),
    );
  }
}

/// Pemilih tahap. Sengaja dua tombol lebar, bukan `TabBar` tipis: yang
/// sebelah kanan ("sesudah") itu yang masuk sertifikat, dan bedanya harus
/// kebaca sekali lihat — salah tahap berarti angka as-found yang disertifikasi.
class _Tab extends StatelessWidget {
  const _Tab({required this.sebelum, required this.onPilih});

  final bool sebelum;
  final ValueChanged<bool> onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabTombol(
              judul: l10n.phCalibSesudahAdjustment,
              catatan: l10n.phCalibDisertifikasi,
              aktif: !sebelum,
              warnaAktif: AppColors.success,
              onTap: () => onPilih(false),
            ),
          ),
          Expanded(
            child: _TabTombol(
              judul: l10n.phCalibSebelumAdjustment,
              catatan: l10n.phCalibDokumentasi,
              aktif: sebelum,
              warnaAktif: theme.colorScheme.onSurfaceVariant,
              onTap: () => onPilih(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabTombol extends StatelessWidget {
  const _TabTombol({
    required this.judul,
    required this.catatan,
    required this.aktif,
    required this.warnaAktif,
    required this.onTap,
  });

  final String judul;
  final String catatan;
  final bool aktif;
  final Color warnaAktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gelap = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: aktif
                ? (gelap ? AppColors.darkElevated : AppColors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
            boxShadow: aktif
                ? [
                    BoxShadow(
                      color: (gelap ? Colors.black : AppColors.navy).withValues(
                        alpha: gelap ? 0.4 : 0.12,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                judul,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  color: aktif
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                catatan.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  color: aktif
                      ? warnaAktif
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Helper extends StatelessWidget {
  const _Helper({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      teks,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
