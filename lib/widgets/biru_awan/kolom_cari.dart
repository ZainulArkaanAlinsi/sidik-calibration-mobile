import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'tombol_bulat.dart';

/// Kunci cincin fokus [KolomCari] (dipakai tes untuk mengukur letaknya).
const Key kunciCincinFokusKolomCari = ValueKey<String>(
  'cincin-fokus-kolom-cari',
);

/// Kolom cari pil 56 (`DaftarStandar.dc.html`, `LAYAR.md` "cari 56"): kertas,
/// isian 14 di kiri, tombol bulat primer 44 berikon kaca pembesar di kanan.
///
/// - [petunjuk] ("Cari nama, nomor seri, atau besaran") tampil sebagai
///   petunjuk isian DAN menjadi label pembaca layar.
/// - [onCari] dipanggil dengan isi kolom saat tombol bulat diketuk atau papan
///   ketik menekan "cari". Tanpa [onCari] (saring langsung lewat [onChanged])
///   tombol bulat hanya memfokuskan kolom. Komponen tidak mencari apa pun dan
///   tidak menyaring daftar.
/// - Ketukan di mana pun pada pil (bantalan kiri, sela, area tombol) memfokuskan
///   isian.
/// - [enabled] `false`: isian tidak bisa diketik (`TextField.enabled == false`),
///   pil `latarMati` bertepi, tombol bulat mati, pembaca layar menerima keadaan
///   mati.
/// - Fokus: cincin `tinta` 2 dp di LUAR pil, terpisah 2 dp dari tepinya
///   ([UkuranKomponenBiruAwan.jarakCincinFokus]), supaya kontrasnya (>= 3:1)
///   diukur terhadap latar halaman, terang dan gelap. Cincin tidak memengaruhi
///   tata letak; beri ruang >= 4 dp di sekeliling kolom yang berada di tepi
///   wadah yang memotong.
/// - Tombol hapus isi sengaja tidak ada (tidak ada di artboard); pemanggil
///   yang butuh mengosongkan isi lewat [controller].
class KolomCari extends StatefulWidget {
  const KolomCari({
    super.key,
    required this.petunjuk,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onCari,
    this.enabled = true,
    this.autofocus = false,
  });

  final String petunjuk;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCari;
  final bool enabled;
  final bool autofocus;

  @override
  State<KolomCari> createState() => _KolomCariState();
}

class _KolomCariState extends State<KolomCari> {
  late FocusNode _fokus;
  late bool _fokusSendiri;
  late TextEditingController _isi;
  late bool _isiSendiri;
  bool _punyaFokus = false;

  @override
  void initState() {
    super.initState();
    _pasangFokus();
    _pasangIsi();
  }

  @override
  void didUpdateWidget(KolomCari lama) {
    super.didUpdateWidget(lama);
    if (lama.focusNode != widget.focusNode) {
      _lepasFokus();
      _pasangFokus();
    }
    if (lama.controller != widget.controller) {
      _lepasIsi();
      _pasangIsi();
    }
  }

  @override
  void dispose() {
    _lepasFokus();
    _lepasIsi();
    super.dispose();
  }

  void _pasangFokus() {
    final dari = widget.focusNode;
    _fokusSendiri = dari == null;
    _fokus = dari ?? FocusNode();
    _punyaFokus = _fokus.hasFocus;
    _fokus.addListener(_fokusBerubah);
  }

  void _lepasFokus() {
    _fokus.removeListener(_fokusBerubah);
    if (_fokusSendiri) _fokus.dispose();
  }

  void _pasangIsi() {
    final dari = widget.controller;
    _isiSendiri = dari == null;
    _isi = dari ?? TextEditingController();
  }

  void _lepasIsi() {
    if (_isiSendiri) _isi.dispose();
  }

  void _fokusBerubah() {
    if (_punyaFokus == _fokus.hasFocus) return;
    setState(() => _punyaFokus = _fokus.hasFocus);
  }

  void _cari() {
    final onCari = widget.onCari;
    if (onCari == null) {
      _fokus.requestFocus();
    } else {
      onCari(_isi.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final aktif = widget.enabled;
    final fokus = aktif && _punyaFokus;

    final gayaIsi = HurufLanjutBiruAwan.isianCari.copyWith(
      color: aktif ? m.tinta : m.tinta2,
    );
    const tanpaTepi = InputBorder.none;
    final isian = Semantics(
      label: widget.petunjuk,
      child: TextField(
        controller: _isi,
        focusNode: _fokus,
        enabled: aktif,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: widget.onCari,
        style: gayaIsi,
        cursorColor: Theme.of(context).colorScheme.primary,
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

    final pil = GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: aktif ? _fokus.requestFocus : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UkuranBiruAwan.kolomCari),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: aktif ? m.kertas : w.latarMati,
            borderRadius: BorderRadius.circular(BentukBiruAwan.saringan),
            border: Border.all(
              color: aktif ? m.kertasTepi : w.tepiMati,
              width: AppUkuran.garis,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: UkuranLanjutBiruAwan.cariBantalanKiri,
              right: UkuranLanjutBiruAwan.cariBantalanKanan,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: isian),
                const SizedBox(width: AppSpacing.sm),
                TombolBulat(
                  ikon: Icons.search,
                  label: l10n.biruAwanCari,
                  ukuran: UkuranTombolBulat.kecil,
                  ragam: RagamTombolBulat.primer,
                  onPressed: aktif ? _cari : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    const luar = UkuranKomponenBiruAwan.jarakCincinFokus + AppUkuran.garisTebal;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        pil,
        if (fokus)
          Positioned(
            key: kunciCincinFokusKolomCari,
            left: -luar,
            top: -luar,
            right: -luar,
            bottom: -luar,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      UkuranKomponenBiruAwan.sudutCincinSaringan,
                    ),
                    border: Border.fromBorderSide(
                      BorderSide(color: m.tinta, width: AppUkuran.garisTebal),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
