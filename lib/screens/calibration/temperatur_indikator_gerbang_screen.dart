import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/angka.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tampil_masuk.dart';
import 'instrument_picker_screen.dart';
import 'lembar_kerja_screen.dart';

/// Dua jenis Temperatur Indikator, dan bedanya BUKAN soal tampilan.
///
/// `tanpaSensor` = sensornya nggak ikut dikalibrasi: kalibrator disambung ke
/// terminal indikator dan berperan jadi sensor tiruan, jadi yang diperiksa cuma
/// bacaan indikatornya. `denganSensor` = sensornya ikut: sensor & indikator
/// diperiksa sebagai satu rangkaian.
///
/// Dari situ lembar kerjanya beda seluruhnya — titik ukur, standar acuan, dan
/// rumus ketidakpastiannya. Makanya pilihannya diangkat jadi satu layar
/// sendiri, bukan dropdown di dalam lembar: teknisi yang salah pilih nggak
/// dapat error apa pun, dia cuma ngisi formulir alat lain sampai selesai.
enum VarianTemperaturIndikator { tanpaSensor, denganSensor }

/// Kunci dedupe kartu di layar pilih alat buat dua nama Temperatur Indikator.
///
/// Nilainya sengaja BUKAN nama alat yang mungkin (ada titik dua di tengahnya):
/// kunci ini cuma hidup di [kunciKartuAlat], dan nama alat yang kebetulan sama
/// nggak boleh ikut kegabung diam-diam ke pintu ini.
const kKunciKartuTemperaturIndikator = 'gerbang:temperatur-indikator';

/// Nama alat Temperatur Indikator dalam SEMUA ejaan yang beneran dipakai.
///
/// Lampiran akreditasi LK-285-IDN nulis dua barisnya dengan bahasa yang beda:
/// no. 1 "Temperature Indicator tanpa Sensor" (Inggris) dan no. 2 "Temperatur
/// Indikator dengan Sensor" (Indonesia, "dengan" huruf kecil). Dokumen lab &
/// judul lembar kerjanya nyampur lagi. Jadi yang dicocokin BUKAN daftar ejaan,
/// tapi bentuknya: `temperatur`/`temperature` + `indikator`/`indicator` +
/// `tanpa`/`dengan` + `sensor`.
///
/// Kalau ini dibikin daftar ejaan tetap, satu nama bakal lolos sendirian ke
/// luar gerbang — dan yang lolos itu justru masuk ke lembar apa adanya tanpa
/// pernah nanya sensornya ikut atau nggak. Gagal tanpa gejala, seperti biasa di
/// jalur ini.
final _polaTemperaturIndikator = RegExp(
  r'temperature?\s+indi[ck]ator\s+(tanpa|dengan)\s+sensor',
);

String _rapiin(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Varian yang disebut [namaAlat], atau `null` kalau ini bukan Temperatur
/// Indikator sama sekali.
///
/// Polanya boleh nempel di TENGAH nama, alasannya sama kayak
/// [profilLembarKerjaUntuk]: yang nyampe ke sini teks bebas — nama alat
/// pelanggan sering dapat embel-embel merk ("Temperature Indicator tanpa
/// Sensor Fluke 1524").
VarianTemperaturIndikator? varianTemperaturIndikator(String namaAlat) {
  final cocok = _polaTemperaturIndikator.firstMatch(_rapiin(namaAlat));
  if (cocok == null) return null;

  return cocok.group(1) == 'tanpa'
      ? VarianTemperaturIndikator.tanpaSensor
      : VarianTemperaturIndikator.denganSensor;
}

/// `true` = nama ini salah satu dari dua Temperatur Indikator, jadi dia masuk
/// lewat [TemperaturIndikatorGerbangScreen], bukan langsung ke lembar.
bool namaTemperaturIndikator(String namaAlat) =>
    varianTemperaturIndikator(namaAlat) != null;

/// Kunci "kartu mana" buat satu nama alat di layar pilih alat.
///
/// Nama alat apa adanya, KECUALI dua Temperatur Indikator yang sengaja
/// dipulangkan dengan kunci yang sama supaya jadi SATU pintu. Yang milih
/// varian teknisi di gerbang, bukan ejaan mana yang kebetulan duluan di daftar
/// kemampuan.
String kunciKartuAlat(String namaAlat) => namaTemperaturIndikator(namaAlat)
    ? kKunciKartuTemperaturIndikator
    : namaAlat;

/// Gerbang Temperatur Indikator — dua pilihan besar sebelum masuk lembar kerja.
///
/// Kenapa layar sendiri, bukan dropdown di dalam lembar: pilihan ini yang
/// nentuin SELURUH isi lembar berikutnya. Dropdown kecil di pojok formulir
/// bobotnya nggak sepadan sama akibatnya, dan teknisi yang kelewat nggak punya
/// gejala apa pun — dia ngisi sembilan titik di formulir yang salah dan
/// angkanya tetap masuk.
///
/// Baris kemampuannya dibaca dari [categoryDetailProvider] yang SAMA dengan
/// yang dipakai layar pilih alat, jadi nggak ada permintaan kedua ke server dan
/// nggak ada dua salinan daftar alat yang bisa beda diam-diam.
class TemperaturIndikatorGerbangScreen extends ConsumerWidget {
  const TemperaturIndikatorGerbangScreen({super.key, required this.kategori});

  final Category kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kemampuan =
        ref.watch(categoryDetailProvider(kategori.kode)).value?.kemampuan;

    // Layar ini cuma bisa dibuka dari kartu yang lahir dari daftar kemampuan,
    // jadi datanya praktis selalu udah ke-cache. Loader-nya buat jaga-jaga
    // cache yang keburu dibuang (mis. app balik dari latar), bukan jalur biasa.
    if (kemampuan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.calibTiNama)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibTiNama)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        // `ListView(children:)`, bukan `.builder` — dua kartu, kebangun
        // sekaligus, jadi aman dianimasikan berurutan tanpa risiko jalan ulang
        // waktu digulir balik. Nggak ada tabel di layar ini, jadi nggak ada
        // yang perlu dikecualikan dari animasi.
        children: berurutan([
          Text(
            l10n.calibTiGerbangPengantar,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PilihanCard(
            kategori: kategori,
            kemampuan: kemampuan,
            varian: VarianTemperaturIndikator.tanpaSensor,
          ),
          const SizedBox(height: AppSpacing.md),
          _PilihanCard(
            kategori: kategori,
            kemampuan: kemampuan,
            varian: VarianTemperaturIndikator.denganSensor,
          ),
        ]),
      ),
    );
  }
}

/// Baris kemampuan PERTAMA yang namanya nyebut [varian], atau null kalau server
/// ini nggak kenal namanya sama sekali.
CalibrationCapability? barisVarian(
  List<CalibrationCapability> kemampuan,
  VarianTemperaturIndikator varian,
) {
  for (final k in kemampuan) {
    if (varianTemperaturIndikator(k.namaAlat) == varian) return k;
  }
  return null;
}

/// Kode profil lembar kerja buat [varian] di server ini, atau `null` = lembarnya
/// BELUM ADA di sini.
///
/// Urutannya sama persis kayak di kartu alat: `profil` dari server duluan,
/// tebakan-dari-nama cuma jaring buat server lama. Yang beda cuma akibat
/// null-nya — di kartu alat itu berarti "pakai form generik", di sini berarti
/// "jangan dibuka".
///
/// **`null` di sini sengaja NGGAK dijatuhkan ke kode tetap `'tits'`/`'tids'`.**
/// Backend milih lembar dari `?profil=`, dan kode yang nggak dia kenal nggak
/// bikin error — dia jatuh ke pH Meter (`CalibrationProfileRegistry::default()`,
/// dan itu perilaku yang memang dijanjiin `docs/kontrak-api.md` §4). Jadi
/// ngirim `tids` ke server yang belum punya profilnya BUKAN "coba dulu siapa
/// tau jalan": itu ngasih teknisi lembar pH Meter dengan judul Temperatur
/// Indikator, tanpa satu pun error yang bunyi.
String? profilVarian(
  List<CalibrationCapability> kemampuan,
  VarianTemperaturIndikator varian,
) {
  final baris = barisVarian(kemampuan, varian);
  if (baris == null) return null;

  return baris.profil ?? profilLembarKerjaUntuk(baris.namaAlat);
}

/// Dukungan NYATA satu varian, dirangkai dari baris kemampuannya sendiri.
///
/// ## Kenapa dihitung, bukan ditulis
///
/// Yang ditanya pemilik proyek sederhana: "alat baru yang udah ketambah apa
/// aja?" — dan sebelum ini layar suhu tidak menjawabnya sama sekali. Dua kartu
/// yang sama persis bunyinya sebelum & sesudah `TidsProfile` mendarat, jadi
/// satu-satunya cara tahu ada yang berubah itu membuka lembarnya.
///
/// Godaannya menempelkan label "BARU" di kartunya. Itu tidak dilakukan, dan
/// alasannya bukan selera: label begitu ditulis tangan sekali lalu **tidak
/// pernah dicabut**, dan enam bulan lagi dia menunjuk alat yang sudah lama ada
/// sementara yang benar-benar baru lewat tanpa tanda. Yang dipajang di sini
/// keadaan yang dihitung ulang tiap layarnya dibuka — metode, rentang, dan CMC
/// dari baris kemampuan yang dikirim server. Alat yang dukungannya masuk
/// kelihatan karena angkanya muncul; yang belum, kosong dan bertanda.
///
/// [jumlahBaris] ikut dipajang karena satu alat bisa punya beberapa baris CMC
/// yang naik mengikuti rentang (TIDS: 0,86 / 1,4 / 3,1 °C), dan "3 baris" itu
/// keterangan yang membedakan dukungan yang lengkap dari yang baru sebagian.
typedef DukunganVarian = ({
  String? metode,
  String? rentang,
  String? cmc,
  int jumlahBaris,
});

/// Rangkum baris kemampuan [varian] jadi [DukunganVarian].
///
/// Semua bagiannya boleh `null` sendiri-sendiri: baris kemampuan yang belum
/// punya CMC itu hal biasa (`tanpa_cmc` di kontrak), dan yang kosong DITULIS
/// kosong — bukan diisi tanda hubung yang kelihatan seperti angka.
DukunganVarian dukunganVarian(
  List<CalibrationCapability> kemampuan,
  VarianTemperaturIndikator varian,
) {
  final baris = [
    for (final k in kemampuan)
      if (varianTemperaturIndikator(k.namaAlat) == varian) k,
  ];

  if (baris.isEmpty) {
    return (metode: null, rentang: null, cmc: null, jumlahBaris: 0);
  }

  T? pertama<T>(T? Function(CalibrationCapability) ambil) {
    for (final k in baris) {
      final v = ambil(k);
      if (v != null && !(v is String && v.trim().isEmpty)) return v;
    }
    return null;
  }

  List<double> semua(double? Function(CalibrationCapability) ambil) => [
    for (final k in baris)
      if (ambil(k) != null) ambil(k)!,
  ];

  String satuankan(String angka, String? satuan) =>
      satuan == null || satuan.isEmpty ? angka : '$angka $satuan';

  // Rentangnya GABUNGAN semua baris: tiga baris TIDS yang bersambung
  // (-20…150, 150…400, 400…600) itu satu rentang ukur -20…600 °C dibagi tiga
  // kelas CMC, bukan tiga rentang terpisah.
  final min = semua((k) => k.rangeMin);
  final max = semua((k) => k.rangeMax);

  final rentang = min.isEmpty || max.isEmpty
      ? null
      : satuankan(
          '${formatNilai(min.reduce(math.min))} … '
          '${formatNilai(max.reduce(math.max))}',
          pertama((k) => k.satuan),
        );

  final u = semua((k) => k.ketidakpastianTerbaik);
  final cmc = u.isEmpty
      ? null
      : satuankan(
          u.reduce(math.min) == u.reduce(math.max)
              ? formatNilai(u.first)
              : '${formatNilai(u.reduce(math.min))}–'
                    '${formatNilai(u.reduce(math.max))}',
          pertama((k) => k.satuanKetidakpastian),
        );

  return (
    metode: pertama((k) => k.metode),
    rentang: rentang,
    cmc: cmc,
    jumlahBaris: baris.length,
  );
}

class _PilihanCard extends StatelessWidget {
  const _PilihanCard({
    required this.kategori,
    required this.kemampuan,
    required this.varian,
  });

  final Category kategori;
  final List<CalibrationCapability> kemampuan;
  final VarianTemperaturIndikator varian;

  IconData get _ikon => switch (varian) {
    // Bedanya digambar, bukan cuma ditulis: yang tanpa sensor kabelnya nyolok
    // ke indikator, yang dengan sensor bawa batang sensornya sendiri.
    VarianTemperaturIndikator.tanpaSensor => Icons.cable_outlined,
    VarianTemperaturIndikator.denganSensor => Icons.thermostat_outlined,
  };

  String _judul(AppLocalizations l10n) => switch (varian) {
    VarianTemperaturIndikator.tanpaSensor => l10n.calibTiTanpaSensorJudul,
    VarianTemperaturIndikator.denganSensor => l10n.calibTiDenganSensorJudul,
  };

  String _keterangan(AppLocalizations l10n) => switch (varian) {
    VarianTemperaturIndikator.tanpaSensor => l10n.calibTiTanpaSensorKeterangan,
    VarianTemperaturIndikator.denganSensor =>
      l10n.calibTiDenganSensorKeterangan,
  };

  void _buka(BuildContext context, String profil, CalibrationCapability baris) {
    // Nama alat yang dioper JUDUL dari server, bukan label pilihan di layar
    // ini: yang tercetak di lembar & nyambung ke baris CMC-nya `nama_alat`
    // lampiran akreditasi, dan itu beda ejaan antara dua varian ini.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LembarKerjaScreen(profil: profil, judulTambahan: baris.namaAlat),
      ),
    );
  }

  void _kabarinBelumSiap(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.calibTiBelumSiapPesan(_judul(l10n)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final profil = profilVarian(kemampuan, varian);
    final baris = barisVarian(kemampuan, varian);
    final siap = profil != null && baris != null;

    // Yang belum siap tetap KELIHATAN, bukan disembunyiin. Pilihan yang hilang
    // bikin teknisi ngira alatnya nggak didukung sama sekali dan dia nyari
    // kartu lain yang salah; pilihan yang kelihatan tapi ditandai bikin dia
    // tau ini bakal ada, cuma belum di server yang lagi dia pakai.
    final warnaIsi = siap
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : theme.colorScheme.surfaceContainerHighest;
    final warnaJudul = siap
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: siap
            ? () => _buka(context, profil, baris)
            : () => _kabarinBelumSiap(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: warnaIsi,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _ikon,
                      size: 28,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _judul(l10n),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: warnaJudul,
                      ),
                    ),
                  ),
                  if (siap)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _keterangan(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Dukungan yang beneran ada di server ini, dipajang APA ADANYA.
              // Ini yang bikin layarnya berhenti diam: kartu yang lembarnya
              // baru mendarat langsung kelihatan bedanya — metode, rentang, dan
              // CMC-nya muncul — tanpa ada satu pun label "BARU" yang ditulis
              // tangan dan nggak pernah dicabut.
              if (siap) ...[
                const SizedBox(height: AppSpacing.md),
                _Dukungan(dukungan: dukunganVarian(kemampuan, varian)),
              ],

              if (!siap) ...[
                const SizedBox(height: AppSpacing.md),
                StatusBadge(
                  label: l10n.calibTiBelumSiap,
                  tone: BadgeTone.warning,
                  icon: Icons.info_outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiga keterangan pendek yang bikin kartu suhu berhenti diam.
///
/// Sengaja BUKAN tabel dan bukan kartu kedua: yang dijawab di sini cuma "alat
/// ini didukung sampai mana", dan jawabannya muat di tiga baris. Yang mau
/// angkanya lengkap membuka lembarnya.
class _Dukungan extends StatelessWidget {
  const _Dukungan({required this.dukungan});

  final DukunganVarian dukungan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final gaya = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget baris(IconData ikon, String teks) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(teks, style: gaya)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Yang null DILEWAT, bukan digambar bertanda hubung. Baris kemampuan
        // yang belum punya CMC itu hal biasa, dan "—" di sebelah label CMC
        // kebaca sebagai angka yang kebetulan kosong, bukan sebagai keterangan
        // yang memang belum diturunkan.
        if (dukungan.metode != null)
          baris(Icons.description_outlined, dukungan.metode!),
        if (dukungan.rentang != null)
          baris(Icons.straighten, l10n.calibTiRentang(dukungan.rentang!)),
        if (dukungan.cmc != null)
          baris(
            Icons.rule,
            l10n.calibTiCmc(dukungan.cmc!, dukungan.jumlahBaris),
          ),
      ],
    );
  }
}
