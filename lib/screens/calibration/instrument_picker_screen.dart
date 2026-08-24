import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/calibration_input_provider.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tampil_masuk.dart';
import 'calibration_input_screen.dart';
import 'lembar_kerja_screen.dart';
import 'temperatur_indikator_gerbang_screen.dart';

/// Langkah 2: dalam satu kategori (mis. Instrumen Analitik), tampilin tiap
/// jenis alat spesifik yang punya kemampuan kalibrasi terdaftar (`GET
/// /api/categories/{kode}`, `CalibrationCapability.namaAlat` + `metode`) —
/// datanya dari lampiran akreditasi LK-285-IDN, bukan dikarang.
///
/// Sebagian jenis alat punya form kalibrasi sendiri ([LembarKerjaScreen]) karena
/// strukturnya jauh lebih spesifik dari form generik — pH Meter, Turbidimeter,
/// Chlorin Meter, & Refractometer. Jenis alat lain lanjut ke
/// [CalibrationInputScreen] generik, dengan kategori udah ke-pre-fill biar
/// teknisi nggak milih ulang.
///
/// Yang menentukan alat masuk yang mana itu `CalibrationCapability.profil` dari
/// server, BUKAN tebakan dari nama alat. [profilLembarKerjaUntuk] cuma jaring
/// buat server lama yang belum ngirim field itu.
class InstrumentPickerScreen extends ConsumerWidget {
  const InstrumentPickerScreen({super.key, required this.kategori});

  final Category kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(categoryDetailProvider(kategori.kode));

    final data = detailAsync.value;

    final Widget isi;
    if (data != null) {
      // Daftar KOSONG pun tetap lewat [_Isi], bukan layar buntu sendiri:
      // kategori yang belum punya satu pun baris kemampuan justru yang paling
      // butuh jalan "tambah sendiri". Dulu di situ teknisi cuma dapat kalimat
      // "belum punya data kemampuan kalibrasi" dan nol tombol — yang artinya
      // dia nelepon admin, dan sesinya nggak jadi hari itu.
      isi = _Isi(
        kategori: kategori,
        instrumen: _dedupeNamaAlat(data.kemampuan),
      );
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
  ///
  /// Yang jadi kunci [kunciKartuAlat], bukan `namaAlat` mentah: dua nama
  /// Temperatur Indikator sengaja dilipat jadi SATU kartu yang mbuka
  /// [TemperaturIndikatorGerbangScreen]. Kalau lipatannya lepas, dua nama itu
  /// balik jadi dua kartu yang langsung nyeret teknisi ke lembar
  /// masing-masing — dan yang menentukan dia ngerjain varian mana jadi ejaan
  /// mana yang kebetulan dia ketuk, bukan sensornya beneran ikut atau nggak.
  List<CalibrationCapability> _dedupeNamaAlat(List<CalibrationCapability> list) {
    final terlihat = <String>{};
    final hasil = <CalibrationCapability>[];
    for (final k in list) {
      if (terlihat.add(kunciKartuAlat(k.namaAlat))) hasil.add(k);
    }
    return hasil;
  }
}

/// Jenis alat yang punya lembar kerja khusus ([LembarKerjaScreen]) — nama alat
/// → kode profil backend. Kuncinya HURUF KECIL semua — lihat
/// [profilLembarKerjaUntuk].
///
/// **Tabel ini CADANGAN, bukan daftar induk.** Daftar induknya sekarang di
/// server (`profil` per baris kemampuan). Alat baru TIDAK perlu ditambahin di
/// sini lagi — nambah baris di sini nggak nolong siapa-siapa yang APK-nya belum
/// di-update, dan itu justru masalah yang bikin sumbernya dipindah ke server.
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
  // yang nyampe ke sini teks bebas dari backend.
  'autoklaf': 'autoclave',
  'autoclave': 'autoclave',
  // TITS — Temperature Indicator tanpa Sensor (alat ke-11). Lampiran
  // akreditasi LK-285-IDN no. 1 nulis "Indicator" (Inggris), sementara judul
  // lembar kerja & dokumen labnya nulis "Indikator" (Indonesia). Dua-duanya
  // didaftarin, alasan yang sama kayak Chlorin/Chlorine di atas.
  //
  // Singkatan "TITS" sengaja TIDAK didaftarin. Pencocokan di
  // [profilLembarKerjaUntuk] nerima kunci yang nempel di TENGAH nama, dan
  // empat huruf itu terlalu pendek buat aman — satu nama alat yang kebetulan
  // memuatnya bakal diam-diam dapat lembar suhu. Nama panjangnya sendiri
  // selalu ada: yang nyampe ke sini `nama_alat` lampiran akreditasi, bukan
  // singkatan yang diketik teknisi.
  'temperature indicator tanpa sensor': 'tits',
  'temperature indikator tanpa sensor': 'tits',

  // ENCLOSURE — lima jenis, satu mesin hitung, tapi LIMA kode profil terpisah
  // karena tiap jenis punya CMC sendiri di lampiran akreditasi (Oven 1,5 °C;
  // Furnace 3,0; Bath 1,2; Inkubator 1,4; Refrigerator 1,5). Jadi kodenya
  // nggak boleh disatukan jadi satu `enclosure`: yang menentukan lantai U95
  // justru jenisnya.
  //
  // Kuncinya persis `nama_alat` di lampiran akreditasi. Diadu ke seluruh 48
  // nama alat di master kemampuan kalibrasi: kelima kata ini nggak nempel di
  // satu pun nama alat lain, jadi pencocokan-di-tengah aman di sini.
  //
  // `bath` cuma empat huruf — sependek "tits" yang sengaja TIDAK didaftarin di
  // atas. Bedanya, `bath` itu nama alat yang sebenarnya di lampiran (bukan
  // singkatan), dan varian yang dipakai lab semuanya memuatnya utuh:
  // "Water Bath", "Oil Bath". Kalau nanti ada alat baru yang namanya
  // kebetulan memuat "bath", yang dibetulkan daftar ini — bukan dibiarkan
  // jatuh diam-diam ke lembar generik.
  'oven': 'oven',
  'furnace': 'furnace',
  'bath': 'bath',
  'inkubator': 'inkubator',
  'incubator': 'inkubator',
  'refrigerator': 'refrigerator',
};

/// Cocokin nama alat ke kode profil lembar kerja, **case-insensitive, spasi
/// dirapetin, dan boleh nempel di tengah nama**. `null` = alat ini nggak punya
/// lembar khusus, pakai form generik.
///
/// **STATUSNYA SEKARANG: CADANGAN, bukan sumber kebenaran.** Yang dipakai
/// duluan `CalibrationCapability.profil` / `equipment.profil` dari server.
/// Fungsi ini cuma jalan kalau field itu nggak ada — yaitu waktu APK baru
/// ketemu server lama. Alasannya: tabel di bawah ikut ke-bundel di dalam APK,
/// jadi begitu admin atau teknisi nambah nama alat baru lewat
/// `POST /api/categories/{kode}/kemampuan`, alat itu MUSTAHIL dapat lembar yang
/// benar dari sini — namanya belum pernah ada waktu APK-nya dibangun.
///
/// **Jangan dihapus.** Masih dipanggil layar detail sesi & Alur Kerja, yang
/// dapat nama alat PELANGGAN dari respons lama, plus belasan test.
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

class _Isi extends ConsumerStatefulWidget {
  const _Isi({required this.kategori, required this.instrumen});

  final Category kategori;
  final List<CalibrationCapability> instrumen;

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  /// Daftar alat ini pakai `ListView.separated` yang recycle item-nya. Tanpa
  /// catatan ini, tiap kartu yang digulir balik animasi masuknya jalan lagi —
  /// dan daftar yang berkedip tiap discroll kebaca sebagai scroll yang berat.
  final _jejak = JejakMasuk();

  final _searchController = TextEditingController();
  String _query = '';

  /// Alat yang barusan ditambah teknisi DI LAYAR INI, urut waktu nambahnya.
  ///
  /// Bukan salinan daftar — cuma penanda buat dua hal yang dijelasin di
  /// [_daftar]: naikin yang barusan ditambah ke paling atas, dan jadi jaring
  /// kalau daftar dari server belum nyusul.
  final _barusanDitambah = <CalibrationCapability>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Kartu ini kena kata yang lagi diketik di kolom cari?
  ///
  /// Dicocokin ke DUA teks: nama alat dari server, dan judul yang beneran
  /// kelihatan di kartunya. Bedanya cuma ada di Temperatur Indikator — kartunya
  /// bertulis "Temperatur Indikator" (Indonesia) sementara baris yang mewakili
  /// dia bernama "Temperature Indicator tanpa Sensor" (Inggris, ejaan lampiran
  /// akreditasi). Kalau yang dicocokin cuma nama server, teknisi yang ngetik
  /// PERSIS judul yang lagi dia tatap malah dapat daftar kosong.
  bool _cocokCari(
    CalibrationCapability k,
    String query,
    AppLocalizations l10n,
  ) {
    final q = query.toLowerCase();
    if (k.namaAlat.toLowerCase().contains(q)) return true;

    return namaTemperaturIndikator(k.namaAlat) &&
        l10n.calibTiNama.toLowerCase().contains(q);
  }

  /// Nama alat dirapiin buat dibandingin. Huruf besar/kecil & spasi dobel
  /// nggak bikin dua nama jadi dua alat — sama aturannya kayak yang dipakai
  /// backend waktu nolak nama kembar.
  String _kunciNama(String nama) =>
      nama.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Daftar yang beneran digambar.
  ///
  /// Isinya daftar dari server, dengan dua penyesuaian buat alat yang barusan
  /// ditambah teknisi:
  ///
  ///  1. **Dinaikin ke paling atas.** Baris baru mendarat di EKOR daftar
  ///     server (id-nya paling besar), dan nyuruh teknisi nge-scroll lewat 40
  ///     kartu buat nyari nama yang dia ketik sedetik lalu itu persis
  ///     kerepotan yang fitur ini mestinya ngilangin.
  ///  2. **Ditempel kalau server belum nyusul.** Servernya udah bilang `201
  ///     Created`, jadi alatnya HARUS kelihatan. Kalau nggak, teknisi
  ///     dibilangin "tersimpan" tapi nggak nemu barangnya — dan yang dia
  ///     lakuin berikutnya nambah lagi dengan nama yang beda tipis.
  List<CalibrationCapability> get _daftar {
    if (_barusanDitambah.isEmpty) return widget.instrumen;

    final baru = _barusanDitambah.map((k) => _kunciNama(k.namaAlat)).toSet();
    final dariServer = widget.instrumen
        .map((k) => _kunciNama(k.namaAlat))
        .toSet();

    final dipin = <CalibrationCapability>[];
    final sisa = <CalibrationCapability>[];
    for (final k in widget.instrumen) {
      (baru.contains(_kunciNama(k.namaAlat)) ? dipin : sisa).add(k);
    }

    final belumNyusul = _barusanDitambah.where(
      (k) => !dariServer.contains(_kunciNama(k.namaAlat)),
    );

    return [...belumNyusul, ...dipin, ...sisa];
  }

  /// [namaAwal] = kata yang lagi diketik di kolom cari. Dioper apa adanya ke
  /// kotaknya biar teknisi **nggak ngetik ulang** nama yang barusan dia cari —
  /// dia baru sadar alatnya nggak ada justru gara-gara nyari.
  Future<void> _tambahAlat(String namaAwal) async {
    final baru = await showDialog<CalibrationCapability>(
      context: context,
      builder: (_) => _TambahAlatDialog(
        kodeKategori: widget.kategori.kode,
        namaAwal: namaAwal,
      ),
    );

    if (baru == null || !mounted) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _barusanDitambah.add(baru);
      // Saringan cari dikosongin: alat barunya belum tentu memuat kata yang
      // diketik (teknisi boleh mbenerin namanya di kotak tadi), dan daftar
      // yang tetap kesaring bikin alat yang barusan disimpan kelihatan nggak
      // ada. Kolomnya sendiri boleh ilang di kategori kecil, jadi `_query`
      // yang nyangkut nggak akan pernah bisa dihapus lagi sama teknisinya.
      _searchController.clear();
      _query = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.calibTambahAlatBerhasil(baru.namaAlat))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semua = _daftar;
    final tampilkanCari = semua.length > _ambangCari;
    final terfilter = _query.isEmpty
        ? semua
        : semua.where((k) => _cocokCari(k, _query, l10n)).toList();

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
              ? _Kosong(query: _query, onTambah: () => _tambahAlat(_query))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    tampilkanCari ? 0 : AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  // +1 buat tombol "tambah sendiri" di ekor daftar.
                  //
                  // Ditaruh IKUT DIGULIR, bukan nempel di bawah layar: yang
                  // dipencet tiap hari itu kartu alat, dan tombol yang selalu
                  // nutupin satu baris kartu bikin jalan yang umum bayar buat
                  // jalan yang jarang. Kategori kecil (≤6 alat) daftarnya
                  // pendek jadi tombolnya kelihatan tanpa digulir sama sekali
                  // — dan justru di situ kolom cari nggak muncul, jadi jalur
                  // "cari dulu, baru sadar nggak ada" nggak kepakai.
                  itemCount: terfilter.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => TampilMasuk(
                    indeks: index,
                    jejak: _jejak,
                    child: index == terfilter.length
                        ? AppButton(
                            label: l10n.calibTambahAlatCta,
                            icon: Icons.add,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _tambahAlat(''),
                          )
                        : _InstrumenCard(
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
      // `temperature` ikut di sini buat TITS — lampiran akreditasi nulisnya
      // "Temperature Indicator tanpa Sensor", nggak ada "thermo" mau pun
      // "termo" di dalamnya, jadi tanpa kata ini kartunya dapat ikon kunci
      // inggris umum.
      _ when n.contains('thermo') ||
              n.contains('termo') ||
              n.contains('temperature') =>
        Icons.device_thermostat_outlined,
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
    // Temperatur Indikator NGGAK pernah langsung ke lembar, walau `profil`-nya
    // udah dituturkan server. Dua nama alatnya — "Temperature Indicator tanpa
    // Sensor" & "Temperatur Indikator dengan Sensor" — lembarnya beda
    // seluruhnya, dan kartu ini mewakili dua-duanya sekaligus (lihat
    // [kunciKartuAlat]). Jadi yang milih varian mesti teknisi di gerbang;
    // kalau dilewati, yang milih jadi urutan baris di daftar kemampuan.
    if (namaTemperaturIndikator(kemampuan.namaAlat)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TemperaturIndikatorGerbangScreen(kategori: kategori),
        ),
      );
      return;
    }

    // `kemampuan.profil` dituturkan server per baris kemampuan — itu yang
    // dipakai. Tebakan-dari-nama cuma dipanggil kalau field-nya nggak ada,
    // yaitu waktu APK ini ketemu server yang belum ngirimnya; lihat catatan di
    // [profilLembarKerjaUntuk].
    //
    // Urutan ini yang bikin alat yang baru ditambah teknisi bisa dapat lembar
    // yang benar TANPA rilis APK baru — dulu mustahil, karena tabel ejaannya
    // ada di HP orang, bukan di server.
    final profil =
        kemampuan.profil ?? profilLembarKerjaUntuk(kemampuan.namaAlat);

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

    // Kartu Temperatur Indikator mewakili DUA nama alat sekaligus, jadi judul &
    // keterangannya nggak boleh dipetik dari salah satunya. Metode TITS
    // (SIDIK-IK-CAL-0502) beda dari TIDS (SIDIK-IK-CAL-0503), dan nyetak salah
    // satunya di kartu gabungan itu keterangan yang salah tapi kelihatan resmi.
    // Yang ditulis di situ justru keputusan yang mesti diambil teknisi di layar
    // berikutnya.
    final gerbangTi = namaTemperaturIndikator(kemampuan.namaAlat);
    final judul = gerbangTi ? l10n.calibTiNama : kemampuan.namaAlat;
    final keterangan = gerbangTi
        ? l10n.calibTiKartuRingkas
        : (metode == null || metode.isEmpty
              ? null
              : '${l10n.calibInstrumenMetodeLabel}: $metode');

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
                  // Baris yang mewakili kartu gabungan bisa jatuh ke ejaan
                  // Indonesia ("Temperatur Indikator dengan Sensor") yang nggak
                  // memuat satu pun kata kunci di [_ikon] — tanpa cabang ini
                  // pintu suhu kadang dapat ikon kunci inggris umum, tergantung
                  // baris mana yang kebetulan duluan di daftar kemampuan.
                  gerbangTi ? Icons.device_thermostat_outlined : _ikon,
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
                      judul,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (keterangan != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        keterangan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Alat yang `tanpa_cmc`-nya true belum punya baris CMC di
                    // lampiran akreditasi — biasanya nama alat yang baru
                    // ditambah teknisi sendiri. Tanpa lantai CMC, sesi yang
                    // memakainya bisa menerbitkan U95 yang lebih KECIL daripada
                    // yang diakreditasi lab, dan nggak ada satu pun error yang
                    // bunyi: angkanya cuma keluar kelihatan terlalu bagus, dan
                    // baru ketahuan waktu diaudit.
                    //
                    // Teknisi TETAP boleh memilihnya — itu memang jalan
                    // masuknya alat baru. Yang nggak boleh, dia nggak tahu.
                    // Jadi penanda ini bukan hiasan, dan jangan dicabut karena
                    // kelihatan cerewet.
                    if (kemampuan.tanpaCmc) ...[
                      const SizedBox(height: AppSpacing.xs),
                      StatusBadge(
                        label: l10n.calibInstrumenTanpaCmc,
                        tone: BadgeTone.warning,
                        icon: Icons.info_outline,
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

/// Daftar kosong. Dua sebabnya beda, tapi ujungnya satu: alatnya nggak ada,
/// dan teknisi butuh jalan keluar — bukan kalimat buntu.
///
///  * [query] kosong = kategorinya emang belum punya baris kemampuan.
///  * [query] isi = yang dicari nggak ketemu.
///
/// Yang kedua ini momen paling pas buat nawarin nambah, dan tawarannya bawa
/// **kata yang barusan dia ketik** — nyuruh ngetik ulang nama yang masih
/// keliatan di kolom cari itu cara paling cepat bikin orang nyerah.
class _Kosong extends StatelessWidget {
  const _Kosong({required this.query, required this.onTambah});

  final String query;
  final VoidCallback onTambah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final ketikan = query.trim();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          ketikan.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          ketikan.isEmpty
              ? l10n.calibInstrumenKosong
              : l10n.calibInstrumenTidakDitemukan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: ketikan.isEmpty
              ? l10n.calibTambahAlatCta
              : l10n.calibTambahAlatDariCari(ketikan),
          icon: Icons.add,
          onPressed: onTambah,
        ),
      ],
    );
  }
}

/// Kotak "tambah jenis alat" — satu-satunya jalan teknisi bikin nama alat
/// baru, dan satu-satunya tempat peringatan CMC-nya muncul.
///
/// **Kirimannya dijalanin DI SINI, bukan di pemanggil.** Kalau kotaknya ditutup
/// duluan terus POST-nya jalan di belakang, penolakan "nama udah kepakai"
/// mendarat di layar yang kotaknya udah nggak ada — nama yang udah diketik
/// ilang, dan teknisi mesti ngulang dari nol cuma buat baca alasannya. Di sini
/// kotaknya tetap kebuka sampai servernya bilang iya.
class _TambahAlatDialog extends ConsumerStatefulWidget {
  const _TambahAlatDialog({required this.kodeKategori, required this.namaAwal});

  final String kodeKategori;

  /// Kata yang lagi diketik di kolom cari, kalau ada.
  final String namaAwal;

  @override
  ConsumerState<_TambahAlatDialog> createState() => _TambahAlatDialogState();
}

class _TambahAlatDialogState extends ConsumerState<_TambahAlatDialog> {
  late final _nama = TextEditingController(text: widget.namaAwal.trim());

  String? _error;
  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    final nama = _nama.text.trim();

    if (nama.isEmpty) {
      setState(() => _error = l10n.calibTambahAlatKosong);
      return;
    }

    setState(() {
      _menyimpan = true;
      _error = null;
    });

    try {
      final baru = await ref
          .read(tambahKemampuanProvider.notifier)
          .tambah(kode: widget.kodeKategori, namaAlat: nama);

      if (mounted) Navigator.of(context).pop(baru);
    } on NamaAlatKembarException catch (e) {
      // Nama kembar itu jawaban NORMAL, bukan kerusakan: alatnya emang udah
      // ada di daftar. Pesannya nyebut itu terang-terangan supaya teknisi
      // nutup kotaknya & nyari kartunya — bukan cuma "gagal", yang bikin dia
      // nyoba lagi pakai "pH Meter 2" sampai ada yang nyangkut.
      if (mounted) {
        setState(() => _error = l10n.calibTambahAlatKembar(e.namaAlat));
      }
    } catch (e) {
      if (mounted) setState(() => _error = l10n.calibTambahAlatGagal(_pesan(e)));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  /// `ApiClient` udah nerjemahin status HTTP jadi kalimat yang layak dibaca,
  /// dan itu yang dipakai. Error lain jangan ditelanjangin ke layar —
  /// "Exception: Bad state" nggak ngasih tau teknisi apa pun.
  String _pesan(Object e) =>
      e is AuthException ? e.message : e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.calibTambahAlatJudul),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: l10n.calibTambahAlatLabel,
              controller: _nama,
              hint: l10n.calibTambahAlatHint,
              errorText: _error,
              enabled: !_menyimpan,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _simpan(),
            ),
            const SizedBox(height: AppSpacing.md),
            const _PeringatanCmc(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _menyimpan ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.calibTambahAlatBatal),
        ),
        // Peringatan di atas NGGAK ngunci tombol ini & nggak ada centang yang
        // mesti diisi. Yang wajib itu teknisi TAU, bukan teknisi dilarang —
        // dia yang berdiri di depan alatnya, dan sesinya mesti tetap jadi.
        AppButton(
          label: l10n.calibTambahAlatSimpan,
          isLoading: _menyimpan,
          onPressed: _simpan,
        ),
      ],
    );
  }
}

/// Peringatan jujur, ditampilin SEBELUM tombol simpan dipencet.
///
/// Alat yang ditambah teknisi nggak punya baris CMC di lampiran akreditasi.
/// Efeknya bukan "kurang rapi": sesi yang memakainya jatuh ke jalur hitung
/// generik, dan angka ± yang terbit bisa lebih KECIL daripada yang diakui
/// akreditasi — **tanpa satu pun error di layar mau pun di sertifikatnya**.
/// Angkanya cuma kelihatan terlalu bagus, dan baru ketahuan waktu diaudit.
///
/// Makanya kalimatnya ada di sini, bukan di snackbar sesudah tersimpan:
/// sesudah sertifikatnya terbit, yang bisa dilakuin teknisi cuma nyesel.
/// Ditulis bahasa lapangan — nggak ada kata "CMC" mau pun "ketidakpastian
/// bentangan" di teksnya, karena yang baca orang yang megang obeng.
class _PeringatanCmc extends StatelessWidget {
  const _PeringatanCmc();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final warna = AppColors.statusPeringatan(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: warna.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, size: 18, color: warna),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.calibTambahAlatPeringatanJudul,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warna,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.calibTambahAlatPeringatanIsi,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
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
