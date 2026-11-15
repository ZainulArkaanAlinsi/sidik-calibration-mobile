import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';

/// Ragam [TombolSidik]. Satu aksi utama per layar; sisanya 48.
enum RagamTombolSidik {
  /// Primer, 56, penuh. Satu per layar.
  utama,

  /// Navy, 48: aksi kedua yang tetap penting.
  tegas,

  /// Putih bertepi kontrol, 48.
  sekunder,

  /// Tanpa isi, teks `primerTua`, 48: batal, lewati, tautan aksi.
  teks,

  /// Isi `error` (merah), 48: tarik, hapus, tolak. Labelnya kata kerja jelas
  /// ("Hapus", "Tarik sertifikat"), tidak pernah "OK" atau "Ya".
  bahaya,
}

/// Tombol pil Biru Awan (`docs/desain-ulang/referensi-html/Komponen.dc.html`):
/// utama 56, lainnya 48. Pengganti `AppButton` (beku, tetap dipakai lembar
/// kerja) di layar yang didesain ulang.
///
/// - [onPressed] `null` = mati; isi netral dan label tinta kedua (tetap
///   terbaca). Aksi yang mati menjelaskan alasannya lewat [alasanMati], tampil
///   tepat di atas tombol.
/// - [sibuk] mematikan tombol dan menolak ketukan, memutar pemutar kecil
///   menggantikan ikon; pembaca layar menerima "label, sedang diproses". Dengan
///   "kurangi gerak" pemutar diam (busur tetap).
/// - [lebarPenuh] bawaan `true` untuk [RagamTombolSidik.utama]; hanya dipakai di
///   induk yang lebarnya terbatas.
/// - Fokus papan ketik: cincin `tinta` 2 dp digambar di LUAR tombol, terpisah
///   2 dp dari tepinya (`UkuranKomponenBiruAwan.jarakCincinFokus`). Di luar,
///   supaya kontrasnya terhadap latar halaman (>= 3:1) tidak bergantung pada isi
///   tombol: navy di atas navy (tegas) tidak terlihat. Tekan: skala 0,97
///   (`TekanSkala`).
/// - Label membungkus bila panjang atau huruf diperbesar; tombol ikut tumbuh.
///
/// Warna dari tema ([SidikMaterial], `colorScheme`); tidak ada nilai mentah.
class TombolSidik extends StatefulWidget {
  const TombolSidik({
    super.key,
    required this.label,
    required this.onPressed,
    this.ragam = RagamTombolSidik.utama,
    this.ikon,
    this.sibuk = false,
    this.lebarPenuh,
    this.alasanMati,
  });

  final String label;

  /// `null` = mati.
  final VoidCallback? onPressed;
  final RagamTombolSidik ragam;
  final IconData? ikon;
  final bool sibuk;

  /// `null` = ikut ragam (penuh hanya untuk utama).
  final bool? lebarPenuh;

  /// Kalimat pendek di atas tombol saat mati ("Isi 2 sel wajib dulu").
  final String? alasanMati;

  /// Tinggi tombol menurut ragam: utama 56, lainnya 48.
  static double tinggiUntuk(RagamTombolSidik ragam) =>
      ragam == RagamTombolSidik.utama
      ? UkuranBiruAwan.tombolUtama
      : UkuranBiruAwan.tombolTegas;

  @override
  State<TombolSidik> createState() => _TombolSidikState();
}

class _TombolSidikState extends State<TombolSidik> {
  /// Keadaan tombol Material (fokus, tekan, mati); hanya fokus yang dipakai di
  /// sini, untuk cincin di luar tombol.
  final WidgetStatesController _keadaan = WidgetStatesController();
  bool _fokus = false;

  @override
  void initState() {
    super.initState();
    _keadaan.addListener(_keadaanBerubah);
  }

  @override
  void dispose() {
    _keadaan.removeListener(_keadaanBerubah);
    _keadaan.dispose();
    super.dispose();
  }

  void _keadaanBerubah() {
    final fokus = _keadaan.value.contains(WidgetState.focused);
    if (fokus != _fokus) setState(() => _fokus = fokus);
  }

  bool get _aktif => widget.onPressed != null && !widget.sibuk;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final ragam = widget.ragam;
    final ikon = widget.ikon;
    final sibuk = widget.sibuk;
    final m = SidikMaterial.of(context);
    final s = Theme.of(context).colorScheme;
    final w = WarnaBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final penuh = widget.lebarPenuh ?? ragam == RagamTombolSidik.utama;
    final tinggi = TombolSidik.tinggiUntuk(ragam);

    // (isi, tinta, tepi): tepi hanya untuk sekunder.
    final (Color isi, Color tinta, Color? tepi) = _aktif
        ? switch (ragam) {
            RagamTombolSidik.utama => (s.primary, s.onPrimary, null),
            RagamTombolSidik.tegas => (m.tinta, m.kertas, null),
            RagamTombolSidik.sekunder => (m.kertas, m.tinta, m.garisTegas),
            RagamTombolSidik.teks => (Colors.transparent, m.biruTinta, null),
            RagamTombolSidik.bahaya => (s.error, s.onError, null),
          }
        : switch (ragam) {
            RagamTombolSidik.sekunder => (
              m.kertas,
              w.tintaTombolMati,
              m.kertasTepi,
            ),
            RagamTombolSidik.teks => (
              Colors.transparent,
              w.tintaTombolMati,
              null,
            ),
            _ => (w.isiTombolMati, w.tintaTombolMati, null),
          };

    final gayaTeks = ragam == RagamTombolSidik.utama
        ? HurufBiruAwan.label
        : HurufBiruAwan.tombol;
    final tepiBiasa = tepi == null
        ? BorderSide.none
        : BorderSide(color: tepi, width: AppUkuran.garis);

    final reduksi = MediaQuery.disableAnimationsOf(context);

    final gaya = ButtonStyle(
      // Peralihan isi dan tinta (mati/sibuk <-> aktif) memakai 200 ms bawaan
      // Material; dengan "kurangi gerak" harus seketika.
      animationDuration: reduksi ? Duration.zero : null,
      minimumSize: WidgetStatePropertyAll(
        Size(penuh ? double.infinity : AppUkuran.sasaranSentuh, tinggi),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: JarakBiruAwan.samping,
          vertical: AppSpacing.sm,
        ),
      ),
      backgroundColor: WidgetStatePropertyAll(isi),
      foregroundColor: WidgetStatePropertyAll(tinta),
      textStyle: WidgetStatePropertyAll(gayaTeks),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
        ),
      ),
      // Eksplisit untuk semua ragam: tema `OutlinedButton` memasang `side`
      // sendiri, dan Material menimpa `side` bentuk dengannya, sehingga tepi
      // "mati" sekunder tidak pernah tampil.
      side: WidgetStatePropertyAll(tepiBiasa),
      // Ukuran sama di HP dan desktop: kerapatan "compact" Windows tidak boleh
      // mengecilkan tombol 56 menjadi 48.
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final Widget? penanda = sibuk
        ? SizedBox.square(
            dimension: UkuranKomponenBiruAwan.ikonTombol,
            child: CircularProgressIndicator(
              strokeWidth: AppUkuran.garisTebal,
              // Dengan "kurangi gerak": busur tetap, tidak berputar.
              value: reduksi ? 0.25 : null,
              color: tinta,
            ),
          )
        : (ikon == null
              ? null
              : Icon(ikon, size: UkuranKomponenBiruAwan.ikonTombol));

    final isiTombol = penanda == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              penanda,
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    final VoidCallback? aksi = _aktif ? widget.onPressed : null;
    final Widget tombol = switch (ragam) {
      RagamTombolSidik.sekunder => OutlinedButton(
        onPressed: aksi,
        style: gaya,
        statesController: _keadaan,
        child: isiTombol,
      ),
      RagamTombolSidik.teks => TextButton(
        onPressed: aksi,
        style: gaya,
        statesController: _keadaan,
        child: isiTombol,
      ),
      _ => FilledButton(
        onPressed: aksi,
        style: gaya,
        statesController: _keadaan,
        child: isiTombol,
      ),
    };

    final Widget semantik = sibuk
        ? Semantics(
            button: true,
            enabled: false,
            label: '$label, ${l10n.biruAwanSedangDiproses}',
            excludeSemantics: true,
            child: tombol,
          )
        : tombol;
    // Cincin fokus di LUAR tombol, terpisah `jarakCincinFokus` dari tepinya;
    // tidak memengaruhi tata letak (Stack meneruskan batas apa adanya).
    const luar = UkuranKomponenBiruAwan.jarakCincinFokus + AppUkuran.garisTebal;
    final Widget denganCincin = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        semantik,
        if (_fokus && _aktif)
          const Positioned(
            key: kunciCincinFokusTombol,
            left: -luar,
            top: -luar,
            right: -luar,
            bottom: -luar,
            child: ExcludeSemantics(
              child: IgnorePointer(child: _CincinFokus()),
            ),
          ),
      ],
    );
    final Widget bertekan = TekanSkala(aktif: _aktif, child: denganCincin);

    final alasanMati = widget.alasanMati;
    final tampilAlasan = !_aktif && !sibuk && alasanMati != null;
    if (!tampilAlasan) return bertekan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: penuh
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            alasanMati,
            style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
          ),
        ),
        bertekan,
      ],
    );
  }
}

/// Kunci cincin fokus [TombolSidik] (dipakai tes untuk mengukur letaknya).
const Key kunciCincinFokusTombol = ValueKey<String>('cincin-fokus-tombol');

/// Cincin fokus: garis `tinta` 2 dp berbentuk pil. Warna dari tema; kontrasnya
/// terhadap latar halaman dijaga `test/biru_awan/tombol_sidik_test.dart`.
class _CincinFokus extends StatelessWidget {
  const _CincinFokus();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
        border: Border.fromBorderSide(
          BorderSide(
            color: SidikMaterial.of(context).tinta,
            width: AppUkuran.garisTebal,
          ),
        ),
      ),
    );
  }
}
