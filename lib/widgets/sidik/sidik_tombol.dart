import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';

/// Ragam tombol. Satu layar cuma boleh punya SATU [RagamTombol.utama].
enum RagamTombol {
  /// Anodisasi biru. Aksi utama layar.
  utama,

  /// Logam polos. Aksi pendamping.
  biasa,

  /// Tanpa permukaan, cuma teks biru. Aksi tersier (Batal, Lewati).
  teks,

  /// Anodisasi merah. Aksi merusak yang sudah dikonfirmasi.
  bahaya,

  /// Garis merah tanpa isi. Aksi merusak yang MASIH akan dikonfirmasi.
  bahayaGaris,
}

/// Tombol fisik: timbul waktu diam, **masuk ke dalam panel waktu ditekan**.
///
/// Travel-nya nyata (turun 1 px) dan bayangannya ikut runtuh. Dua-duanya perlu:
/// bayangan saja tanpa gerakan kebaca sebagai "berubah warna", bukan
/// "tertekan" — dan yang bikin tombol skeuomorphic terasa benar itu justru
/// gerakannya, bukan teksturnya.
///
/// Sengaja TIDAK memakai ripple Material: percikan dilukis di atas gradien dan
/// bikin noda kelabu yang ngotorin permukaannya.
///
/// ```dart
/// SidikTombol(
///   label: 'Kirim ke admin',
///   ikon: Icons.send,
///   onPressed: _kirim,
///   sibuk: _lagiKirim,
/// )
/// ```
class SidikTombol extends StatefulWidget {
  const SidikTombol({
    super.key,
    required this.label,
    this.onPressed,
    this.ragam = RagamTombol.biasa,
    this.ikon,
    this.sibuk = false,
    this.penuh = false,
    this.kecil = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RagamTombol ragam;
  final IconData? ikon;

  /// Tampilkan pemutar dan matikan tombol. **Per tombol**, bukan satu flag
  /// untuk seluruh layar — versi lama memakai satu `_sibuk` bersama, jadi
  /// ketiga tombol berputar padahal cuma satu yang bekerja.
  final bool sibuk;

  final bool penuh;
  final bool kecil;

  bool get _mati => onPressed == null || sibuk;

  @override
  State<SidikTombol> createState() => _SidikTombolState();
}

class _SidikTombolState extends State<SidikTombol> {
  bool _ditekan = false;

  void _setTekan(bool v) {
    if (widget._mati || _ditekan == v) return;
    setState(() => _ditekan = v);
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final tinggi = widget.kecil ? 42.0 : 48.0;
    final radius = widget.kecil
        ? SidikMaterial.sudutLogam - 1
        : SidikMaterial.sudutLogam;

    final (List<Color>? isi, Color? tepi, Color teks) = switch (widget.ragam) {
      RagamTombol.utama => (
        [m.biruAtas, m.biru, const Color(0xFF14306E)],
        const Color(0xFF12275C),
        Colors.white,
      ),
      RagamTombol.bahaya => (
        [const Color(0xFFC63049), m.gagal, const Color(0xFF7E1426)],
        const Color(0xFF6E0F20),
        m.terang ? Colors.white : const Color(0xFF24070D),
      ),
      RagamTombol.bahayaGaris => (null, m.gagal, m.gagal),
      RagamTombol.teks => (null, Colors.transparent, m.biruTinta),
      RagamTombol.biasa => (null, null, m.etsa),
    };

    final datar =
        widget.ragam == RagamTombol.teks ||
        widget.ragam == RagamTombol.bahayaGaris;

    BoxDecoration hiasan;
    if (widget._mati) {
      hiasan = BoxDecoration(
        color: m.kertas2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: m.kertasTepi),
      );
    } else if (datar) {
      hiasan = BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tepi ?? Colors.transparent),
        color: _ditekan ? m.tinta.withValues(alpha: 0.06) : Colors.transparent,
      );
    } else if (_ditekan) {
      hiasan = m.logamTertekan(radius: radius, warna: isi, tepi: tepi);
    } else {
      hiasan = m.logamTimbul(radius: radius, warna: isi, tepi: tepi);
    }

    final warnaTeks = widget._mati ? m.tinta2.withValues(alpha: 0.6) : teks;

    Widget isiTombol = Row(
      mainAxisSize: widget.penuh ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.sibuk)
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: warnaTeks),
            ),
          )
        else if (widget.ikon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(widget.ikon, size: 18, color: warnaTeks),
          ),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: warnaTeks,
              fontSize: widget.kecil ? 14 : 15,
              fontWeight: FontWeight.w600,
              // Teks diukir ke permukaan: kilau di bawah huruf untuk logam
              // terang, bayangan di atas huruf untuk anodisasi gelap.
              shadows: (widget._mati || datar)
                  ? null
                  : [
                      Shadow(
                        color: isi != null
                            ? Colors.black.withValues(alpha: 0.45)
                            : (m.terang
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.55)),
                        offset: Offset(0, isi != null || !m.terang ? -1 : 1),
                      ),
                    ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !widget._mati,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setTekan(true),
        onTapUp: (_) => _setTekan(false),
        onTapCancel: () => _setTekan(false),
        onTap: widget._mati ? null : widget.onPressed,
        // Travel fisiknya: turun 1 px waktu ditekan. Pakai Transform.translate,
        // bukan `AnimatedContainer.transform`, supaya tidak perlu menyentuh
        // Matrix4 sama sekali.
        child: Transform.translate(
          offset: Offset(0, _ditekan ? 1 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOut,
            height: tinggi,
            width: widget.penuh ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.kecil ? 14 : 18),
            alignment: Alignment.center,
            decoration: hiasan,
            child: isiTombol,
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon di panel logam (app bar, bar aksi).
///
/// [label] WAJIB — dia jadi tooltip sekaligus label Semantics. Tombol ikon
/// tanpa label tidak bisa diumumkan pembaca layar.
class SidikTombolIkon extends StatelessWidget {
  const SidikTombolIkon({
    super.key,
    required this.ikon,
    required this.label,
    this.onPressed,
    this.lencana,
  });

  final IconData ikon;
  final String label;
  final VoidCallback? onPressed;

  /// Angka kecil di pojok, mis. jumlah notifikasi belum dibaca.
  final int? lencana;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: onPressed,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: m.logamTimbul(radius: 11),
                  child: Icon(ikon, size: 22, color: m.etsa),
                ),
              ),
              if (lencana != null && lencana! > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19),
                    height: 19,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: m.logamAtas, width: 1.5),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0xFFD4425C), m.gagal],
                      ),
                    ),
                    child: Text(
                      lencana! > 99 ? '99+' : '$lencana',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
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
