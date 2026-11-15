import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';

/// Kotak isian Biru Awan (`ELEMEN.md` §Isian, `Formulir.dc.html`): label di
/// ATAS (14/700; placeholder bukan label), kotak 56 sudut 16, kalimat bantuan
/// atau galat di bawah. Pengganti `AppTextField` (beku, dipakai lembar kerja)
/// di layar yang didesain ulang.
///
/// Keadaan:
/// - biasa: tepi kontrol (`garisKontrol`, 3:1) 1 dp.
/// - fokus: tepi primer 2 dp.
/// - galat ([galat] terisi): tepi `koralBatang` 2 dp + ikon + kalimat. Warna
///   tidak sendirian: ikon dan kata ikut tampil; kalimat dibaca otomatis oleh
///   pembaca layar (`liveRegion`) dan ikut menjadi petunjuk kolomnya.
/// - mati ([enabled] `false`): latar `latar`, tepi garis halus, teks tinta kedua.
///
/// [wajib] menambah "(wajib)" di label, bukan bintang merah. [mono] untuk kode
/// dan angka (IBM Plex Mono). [akhir] untuk aksi di ujung kotak (mis.
/// "Tampilkan" sandi); aksi itu sendiri wajib >= 48 dp dan berlabel.
///
/// Teks (label, bantuan, galat, petunjuk) dari pemanggil atau l10n. Komponen ini
/// tidak memvalidasi apa pun: galat datang dari pemanggil.
class IsianSidik extends StatefulWidget {
  const IsianSidik({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.petunjuk,
    this.bantuan,
    this.galat,
    this.wajib = false,
    this.enabled = true,
    this.mono = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.maxLines = 1,
    this.akhir,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Contoh isi yang memudar saat kosong. BUKAN pengganti [label].
  final String? petunjuk;

  /// Kalimat bantu di bawah kotak (hilang saat ada [galat]).
  final String? bantuan;

  /// Kalimat galat; `null` atau kosong = tanpa galat.
  final String? galat;
  final bool wajib;
  final bool enabled;
  final bool mono;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final Widget? akhir;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<IsianSidik> createState() => _IsianSidikState();
}

class _IsianSidikState extends State<IsianSidik> {
  late FocusNode _fokus;
  bool _fokusSendiri = false;
  bool _punyaFokus = false;

  @override
  void initState() {
    super.initState();
    _pasang();
  }

  @override
  void didUpdateWidget(IsianSidik lama) {
    super.didUpdateWidget(lama);
    if (lama.focusNode != widget.focusNode) {
      _lepas();
      _pasang();
    }
  }

  @override
  void dispose() {
    _lepas();
    super.dispose();
  }

  void _pasang() {
    final dari = widget.focusNode;
    _fokusSendiri = dari == null;
    _fokus = dari ?? FocusNode();
    _punyaFokus = _fokus.hasFocus;
    _fokus.addListener(_fokusBerubah);
  }

  void _lepas() {
    _fokus.removeListener(_fokusBerubah);
    if (_fokusSendiri) _fokus.dispose();
  }

  void _fokusBerubah() {
    if (_punyaFokus == _fokus.hasFocus) return;
    setState(() => _punyaFokus = _fokus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final adaGalat =
        widget.enabled && widget.galat != null && widget.galat!.isNotEmpty;
    final fokus = widget.enabled && _punyaFokus;

    final (
      Color tepi,
      double lebarTepi,
      Color isi,
      Color teks,
    ) = !widget.enabled
        ? (w.tepiMati, AppUkuran.garis, w.latarMati, m.tinta2)
        : adaGalat
        ? (w.tepiGalat, AppUkuran.garisTebal, m.kertas, m.tinta)
        : fokus
        ? (m.biru, AppUkuran.garisTebal, m.kertas, m.tinta)
        : (m.garisTegas, AppUkuran.garis, m.kertas, m.tinta);

    final labelTampil = widget.wajib
        ? l10n.biruAwanLabelWajib(widget.label)
        : widget.label;
    final pesan = adaGalat ? widget.galat : widget.bantuan;
    final petunjukSemantik = adaGalat ? l10n.biruAwanIsianGalat(pesan!) : pesan;

    final gayaIsi =
        (widget.mono ? HurufBiruAwan.isianMono : HurufBiruAwan.isian).copyWith(
          color: teks,
        );
    // Semua pinggiran dimatikan satu per satu: tema app memasang `filled` dan
    // `enabledBorder` yang kalau tidak dilawan akan tergambar di dalam kotak ini.
    const tanpaTepi = InputBorder.none;
    final kolom = Semantics(
      label: labelTampil,
      hint: petunjukSemantik,
      child: TextField(
        controller: widget.controller,
        focusNode: _fokus,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: gayaIsi,
        cursorColor: m.biru,
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: tanpaTepi,
          enabledBorder: tanpaTepi,
          focusedBorder: tanpaTepi,
          errorBorder: tanpaTepi,
          focusedErrorBorder: tanpaTepi,
          disabledBorder: tanpaTepi,
          hintText: widget.petunjuk,
          hintStyle: gayaIsi.copyWith(color: m.tinta2),
          contentPadding: const EdgeInsets.symmetric(
            vertical: JarakBiruAwan.isianVertikal,
          ),
        ),
      ),
    );

    final skala = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            labelTampil,
            style: HurufBiruAwan.labelKecil.copyWith(
              color: widget.enabled ? m.tinta : m.tinta2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Ketukan di mana pun di kotak (juga bantalan 17 dp kiri-kanan)
        // memfokuskan isian; ketukan di area teks tetap ditangani TextField.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onTap: widget.enabled ? _fokus.requestFocus : null,
          child: AnimatedContainer(
            duration: AppMotion.hormati(context, AppMotion.kilat),
            constraints: const BoxConstraints(
              minHeight: UkuranKomponenBiruAwan.isian,
            ),
            // Tepi 1 atau 2 dp menggeser isi; bantalan menyesuaikan supaya teks
            // tidak melompat saat fokus pindah.
            padding: EdgeInsets.symmetric(
              horizontal: JarakBiruAwan.samping - lebarTepi,
            ),
            decoration: BoxDecoration(
              color: isi,
              borderRadius: BorderRadius.circular(BentukBiruAwan.isian),
              border: Border.all(color: tepi, width: lebarTepi),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: kolom),
                if (widget.akhir != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  widget.akhir!,
                ],
              ],
            ),
          ),
        ),
        if (adaGalat) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            excludeSemantics: true,
            label: widget.galat,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: JarakBiruAwan.baris),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: skala.scale(UkuranKomponenBiruAwan.ikonGalat),
                    color: w.tintaGalat,
                  ),
                ),
                const SizedBox(width: JarakBiruAwan.sisipan),
                Expanded(
                  child: Text(
                    widget.galat!,
                    style: HurufBiruAwan.galat.copyWith(color: w.tintaGalat),
                  ),
                ),
              ],
            ),
          ),
        ] else if (widget.bantuan != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.bantuan!,
            style: HurufBiruAwan.keteranganKecil.copyWith(color: m.tinta2),
          ),
        ],
      ],
    );
  }
}
