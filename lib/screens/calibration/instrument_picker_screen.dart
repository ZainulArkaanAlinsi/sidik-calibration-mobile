import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/tampil_masuk.dart';
import 'calibration_input_screen.dart';
import 'lembar_kerja_screen.dart';

/// Langkah 2: dalam satu kategori (mis. Instrumen Analitik), tampilin tiap
/// jenis alat spesifik yang punya kemampuan kalibrasi terdaftar (`GET
/// /api/categories/{kode}`, `CalibrationCapability.namaAlat` + `metode`) —
/// datanya dari lampiran akreditasi LK-285-IDN, bukan dikarang.
///
/// Sebagian jenis alat punya form kalibrasi sendiri ([LembarKerjaScreen]) karena
/// strukturnya jauh lebih spesifik dari form generik — pH Meter, Turbidimeter,
/// Chlorin Meter, & Refractometer (lihat [profilLembarKerjaUntuk]). Jenis alat
/// lain lanjut ke
/// [CalibrationInputScreen] generik, dengan kategori udah ke-pre-fill biar
/// teknisi nggak milih ulang.
class InstrumentPickerScreen extends ConsumerWidget {
  const InstrumentPickerScreen({super.key, required this.kategori});

  final Category kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(categoryDetailProvider(kategori.kode));
    final l10n = AppLocalizations.of(context);

    final data = detailAsync.value;

    final Widget isi;
    if (data != null) {
      final instrumen = _dedupeNamaAlat(data.kemampuan);
      isi = instrumen.isEmpty
          ? _Kosong(l10n: l10n)
          : _Isi(kategori: kategori, instrumen: instrumen);
    } else if (detailAsync.hasError) {
      isi = _Gagal(
        onCobaLagi: () => ref.invalidate(categoryDetailProvider(kategori.kode)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(kategori.nama)),
      body: isi,
    );
  }

  /// `CalibrationCapability` bisa punya beberapa baris per jenis alat (beda
  /// rentang/parameter/titik ukur — mis. pH Meter py 6 baris buat titik pH
  /// 4/7/10 generik & presisi). Buat layar pilihan, cukup 1 kartu per nama
  /// alat unik; metode-nya diambil dari baris pertama yang punya nilai.
  List<CalibrationCapability> _dedupeNamaAlat(List<CalibrationCapability> list) {
    final terlihat = <String>{};
    final hasil = <CalibrationCapability>[];
    for (final k in list) {
      if (terlihat.add(k.namaAlat)) hasil.add(k);
    }
    return hasil;
  }
}

/// Jenis alat yang punya lembar kerja khusus ([LembarKerjaScreen]) — nama alat
/// → kode profil backend. Jenis lain lanjut ke form generik. Nambah alat
/// berikutnya yang butuh lembar sendiri = tambah satu baris di sini.
///
/// Kuncinya HURUF KECIL semua — lihat [profilLembarKerjaUntuk].
const _profilKhusus = {
  'ph meter': 'ph_meter',
  'turbidimeter': 'turbidimeter',
  // Lampiran akreditasi LK-285-IDN no. 42 nulisnya "Chlorin Meter" (tanpa 'e'),
  // sementara lembar kerjanya SIDIK-FM-CAL-0531 nulis "Chlorine Meter".
  // Dua-duanya didaftarin: yang nyampe ke sini teks dari backend, dan backend
  // narik namanya dari lampiran.
  'chlorin meter': 'chlorine_meter',
  'chlorine meter': 'chlorine_meter',
  'refractometer': 'refractometer',
  // Lampiran akreditasi nulis "Conductivitymeter" (satu kata) sementara
  // sertifikat & lembar kerjanya nulis "Conductivity Meter". Dua-duanya
  // didaftarin, alasan yang sama kayak Chlorin/Chlorine di atas: yang nyampe
  // ke sini teks bebas dari backend, bukan enum.
  'conductivity meter': 'conductivity_meter',
  'conductivitymeter': 'conductivity_meter',
  // TIGA ejaan, dan ketiganya beneran ada di data lab: master Excel &
  // `DATABASE.csv` nulis "Spectrophotometer", `kemampuan-kalibrasi.json` nulis
  // "Spektrofotometer" (tiga baris CMC yang nggak dipakai jalur hitung, tapi
  // KARTUNYA tetap muncul di picker), dan alat pelanggannya sendiri terdaftar
  // "Visible Spectrofotometer". Ketiganya nunjuk ke satu profil backend.
  'spectrophotometer': 'spectrophotometer',
  'spektrofotometer': 'spectrophotometer',
  'spectrofotometer': 'spectrophotometer',
  'viscometer': 'viscometer',
  // Lampiran akreditasi & DATABASE nulis "DO Meter"; sebagian data alat
  // pelanggan nulisnya tanpa spasi. Dua-duanya didaftarin — yang nyampe ke
  // sini teks bebas dari backend, bukan enum.
  'do meter': 'do_meter',
  'dometer': 'do_meter',
  // Lampiran akreditasi nulis "Gas Detector"; lembar kerja & sertifikatnya
  // nyebut "Multi Gas Detector", dan sebagian data alat pelanggan nulisnya
  // tanpa spasi. Ketiganya didaftarin — yang nyampe ke sini teks bebas dari
  // backend, bukan enum.
  'gas detector': 'gas_detector',
  'multi gas detector': 'gas_detector',
  'gasdetector': 'gas_detector',
  // Lampiran akreditasi LK-285-IDN no. 48 nulis "Autoklaf"; lembar kerjanya
  // SIDIK-FM-CAL-0539 & DATABASE nulis "Autoclave". Dua-duanya didaftarin —
  // yang nyampe ke sini teks bebas dari backend. Autoklaf pakai layar khusus
  // (AutoclaveInputScreen), bukan LembarKerjaScreen generik.
  'autoklaf': 'autoclave',
  'autoclave': 'autoclave',
};

/// Cocokin nama alat ke kode profil lembar kerja, **case-insensitive, spasi
/// dirapetin, dan boleh nempel di tengah nama**. `null` = alat ini nggak punya
/// lembar khusus, pakai form generik.
///
/// Dulu dicocokin persis (`_profilKhusus[namaAlat]`). Itu rapuh: `namaAlat` teks
/// bebas dari lampiran akreditasi, bukan enum — beda satu huruf besar/kecil atau
/// spasi dobel bikin alatnya diam-diam jatuh ke form generik. Gagal tanpa
/// gejala: teknisi dapat form yang salah dan nggak ada satu pun yang error.
///
/// Cocok-persisnya sendiri masih kurang, dan itu ketahuan dari dua pemanggil
/// yang ngoper **nama alat pelanggan**, bukan nama jenis alat: Alur Kerja dan
/// layar detail sesi (`profilLembarKerjaUntuk(sesi.namaAlat) ?? 'ph_meter'`).
/// Alat di master pelanggan namanya "Visible Spectrofotometer",
/// "Turbidimeter Hach", "pH Meter Mettler Toledo" — nggak ada satu pun yang
/// cocok persis, jadi semuanya jatuh ke `ph_meter` dan sesi yang dibuka lagi
/// dapat lembar pH. Sekarang kunci yang paling panjang dicoba duluan, biar nama
/// yang kebetulan nyimpen dua kunci (mis. "Chlorine Meter" vs "Meter") mendarat
/// di yang paling spesifik.
String? profilLembarKerjaUntuk(String namaAlat) {
  final n = namaAlat.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final tepat = _profilKhusus[n];
  if (tepat != null) return tepat;

  final kunci = _profilKhusus.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final k in kunci) {
    if (n.contains(k)) return _profilKhusus[k];
  }

  return null;
}

/// Ambang jumlah alat sebelum kolom cari ditampilin — kategori kecil
/// (mis. Panjang, cuma 4 alat) nggak perlu, scroll aja udah cukup.
const _ambangCari = 6;

class _Isi extends StatefulWidget {
  const _Isi({required this.kategori, required this.instrumen});

  final Category kategori;
  final List<CalibrationCapability> instrumen;

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  /// Daftar alat ini pakai `ListView.separated` yang recycle item-nya. Tanpa
  /// catatan ini, tiap kartu yang digulir balik animasi masuknya jalan lagi —
  /// dan daftar yang berkedip tiap discroll kebaca sebagai scroll yang berat.
  final _jejak = JejakMasuk();

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tampilkanCari = widget.instrumen.length > _ambangCari;
    final terfilter = _query.isEmpty
        ? widget.instrumen
        : widget.instrumen
              .where((k) => k.namaAlat.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Column(
      children: [
        if (tampilkanCari)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.calibCariInstrumenHint,
              ),
            ),
          ),
        Expanded(
          child: terfilter.isEmpty
              ? Center(child: Text(l10n.calibInstrumenTidakDitemukan))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    tampilkanCari ? 0 : AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: terfilter.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => TampilMasuk(
                    indeks: index,
                    jejak: _jejak,
                    child: _InstrumenCard(
                      kategori: widget.kategori,
                      kemampuan: terfilter[index],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _InstrumenCard extends StatelessWidget {
  const _InstrumenCard({required this.kategori, required this.kemampuan});

  final Category kategori;
  final CalibrationCapability kemampuan;

  /// Ikon per jenis alat — dicocokin lewat keyword nama karena
  /// `namaAlat` sumbernya teks bebas dari lampiran akreditasi (bukan enum),
  /// jadi nggak ada daftar tetap buat di-switch persis.
  IconData get _ikon {
    final n = kemampuan.namaAlat.toLowerCase();
    return switch (n) {
      _ when n.contains('ph meter') => Icons.science_outlined,
      _ when n.contains('conductivity') => Icons.bolt_outlined,
      _ when n.contains('turbidi') => Icons.blur_on_outlined,
      _ when n.contains('chlorin') => Icons.water_drop_outlined,
      _ when n.contains('viscomet') => Icons.opacity_outlined,
      _ when n.contains('refractomet') => Icons.remove_red_eye_outlined,
      _ when n.contains('do meter') => Icons.air_outlined,
      // Tiga ejaan yang beneran dipakai lab — lihat [_profilKhusus].
      _ when n.contains('spektro') || n.contains('spectro') =>
        Icons.gradient_outlined,
      _ when n.contains('autoklaf') => Icons.local_fire_department_outlined,
      _ when n.contains('thermohygro') => Icons.thermostat_outlined,
      _ when n.contains('thermo') || n.contains('termo') => Icons.device_thermostat_outlined,
      _ when n.contains('oven') || n.contains('furnace') || n.contains('bath') =>
        Icons.local_fire_department_outlined,
      _ when n.contains('inkubator') || n.contains('refrigerator') =>
        Icons.kitchen_outlined,
      _ when n.contains('timbangan') => Icons.scale_outlined,
      _ when n.contains('pipet') || n.contains('buret') || n.contains('dispensett') =>
        Icons.science_outlined,
      _ when n.contains('gelas ukur') || n.contains('labu ukur') || n.contains('picnometer') =>
        Icons.opacity_outlined,
      _ when n.contains('pressure') || n.contains('vacuum') || n.contains('manometer') =>
        Icons.speed_outlined,
      _ when n.contains('utm') || n.contains('load cell') || n.contains('proving ring') =>
        Icons.compress_outlined,
      _ when n.contains('flow') => Icons.waves_outlined,
      _ when n.contains('hydrometer') => Icons.blur_on_outlined,
      _ when n.contains('caliper') || n.contains('micrometer') || n.contains('dial') =>
        Icons.straighten_outlined,
      _ when n.contains('timer') || n.contains('stopwatch') || n.contains('tachometer') =>
        Icons.timer_outlined,
      _ when n.contains('centrifuge') => Icons.autorenew,
      _ => Icons.build_outlined,
    };
  }

  void _pilih(BuildContext context) {
    final profil = profilLembarKerjaUntuk(kemampuan.namaAlat);

    // Autoklaf ikut `LembarKerjaScreen` kayak sembilan alat lain sejak 20 Agu
    // 2026. Tabelnya masih beda — baris = besaran, kolom = titik waktu — tapi
    // bentuk itu sekarang dituturkan backend (`bagian.matriks`) dan digambar
    // `LembarKerjaMatriks`, jadi nggak perlu layar sendiri. Endpoint simpan &
    // olah datanya tetap `/calibrations/autoclave`; yang disatukan layarnya,
    // bukan bentuk datanya.
    if (profil != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LembarKerjaScreen(
            profil: profil,
            judulTambahan: kemampuan.namaAlat,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationInputScreen(kategoriAwal: kategori.kode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final metode = kemampuan.metode;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => _pilih(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _ikon,
                  size: 21,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kemampuan.namaAlat,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (metode != null && metode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.calibInstrumenMetodeLabel}: $metode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(l10n.calibInstrumenKosong));
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 140),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 100),
            ],
          ),
        ),
      ),
    );
  }
}
