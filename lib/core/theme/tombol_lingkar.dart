import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Gaya tombol "btn-12" (acuan desain Uiverse karya doniaskima): pil hitam
/// bertepi 2 dp, dan waktu disentuh empat batang putih meluncur masuk —
/// dua dari bawah, dua dari atas, saling selang-seling sampai treknya ketutup
/// penuh. Labelnya nggak ganti warna: dia dilukis dengan blend `difference`,
/// jadi dia BALIK sendiri jadi hitam persis di bagian yang ketiban batang.
///
/// ## Kenapa lewat `backgroundBuilder`, bukan widget tombol baru
///
/// Di app ini ada 129 tempat yang manggil `FilledButton`/`OutlinedButton`
/// (lewat `AppButton` maupun langsung). Bikin widget baru berarti nyentuh
/// semuanya satu-satu. `ButtonStyle.backgroundBuilder` nyisipin lapisan di
/// antara warna dasar Material dan isi tombol, dan dia dipasang **sekali** di
/// `ThemeData` — jadi semua tombol dapat gaya ini tanpa satu pun call site
/// diubah.
///
/// ## Kenapa warna batangnya beda antara primary dan secondary
///
/// `difference` cuma rapi kalau lawannya hitam/putih murni. Labelnya SELALU
/// ditulis putih; yang nentuin dia kebaca hitam atau putih itu apa yang ada di
/// belakangnya. Jadi:
///
///  - primary — dasar hitam, batang PUTIH. Label putih di atas hitam tetap
///    putih; begitu ketiban batang putih dia jadi hitam.
///  - secondary — dasar tembus pandang, batang `onSurface` (hitam di tema
///    terang, putih di tema gelap). Label putih di atas latar terang jadi
///    nyaris hitam, di atas batang gelap balik jadi putih. Satu aturan, dua
///    tema, nggak ada warna yang dihardcode per-tema.
class TombolBergaris {
  const TombolBergaris._();

  /// Lama batang meluncur. `transition: transform .2s ease` di CSS acuannya.
  static const durasi = Duration(milliseconds: 200);

  /// Lapisan batang. Pasang ke [ButtonStyle.backgroundBuilder].
  static Widget Function(BuildContext, Set<WidgetState>, Widget?) latar(
    Color warnaBatang,
  ) {
    return (context, states, child) {
      // Di HP nggak ada hover — kalau cuma `hovered` yang dipantau, animasinya
      // nggak pernah kelihatan sama sekali di perangkat yang justru paling
      // banyak dipakai teknisi. Jadi tekan ikut memicu.
      final aktif =
          !states.contains(WidgetState.disabled) &&
          (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused));

      return _Batang(maju: aktif, warna: warnaBatang, child: child);
    };
  }

  /// Pembalik warna label + HURUF BESAR. Pasang ke
  /// [ButtonStyle.foregroundBuilder].
  static Widget Function(BuildContext, Set<WidgetState>, Widget?)
  get labelBerbalik {
    return (context, states, child) {
      final isi = _hurufBesar(child);

      // Tombol mati nggak ikut dibalik: `difference` bikin warna redup jadi
      // terang lagi, dan tombol yang nggak bisa dipencet malah keliatan nyala.
      if (states.contains(WidgetState.disabled)) return isi;

      return _CampurBeda(child: isi);
    };
  }

  /// `text-transform: uppercase` versi Flutter.
  ///
  /// Flutter nggak punya padanan properti itu — satu-satunya jalan mengubah
  /// string-nya. Dikerjakan di sini supaya `FilledButton`/`OutlinedButton`
  /// yang dipanggil langsung (mis. tombol dialog) ikut kebagian tanpa 43 call
  /// site diubah satu-satu.
  ///
  /// Cuma anak yang memang [Text] polos yang disentuh; bentuk lain (Row
  /// beserta ikonnya, indikator loading) dibiarkan apa adanya. `semanticsLabel`
  /// tetap teks aslinya — pembaca layar nggak perlu ikut teriak.
  static Widget _hurufBesar(Widget? child) {
    if (child is! Text) return child ?? const SizedBox();

    final teks = child.data;
    if (teks == null) return child;

    return Text(
      teks.toUpperCase(),
      style: child.style,
      textAlign: child.textAlign,
      maxLines: child.maxLines,
      overflow: child.overflow,
      softWrap: child.softWrap,
      semanticsLabel: child.semanticsLabel ?? teks,
    );
  }
}

class _Batang extends StatelessWidget {
  const _Batang({required this.maju, required this.warna, this.child});

  final bool maju;
  final Color warna;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Hormati "kurangi gerak": batangnya tetap muncul, cuma nggak meluncur.
    final durasi = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TombolBergaris.durasi;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: maju ? 1.0 : 0.0),
      duration: durasi,
      curve: Curves.easeOut,
      builder: (context, t, isi) => CustomPaint(
        painter: t == 0 ? null : _PelukisBatang(t: t, warna: warna),
        child: isi,
      ),
      child: child,
    );
  }
}

class _PelukisBatang extends CustomPainter {
  _PelukisBatang({required this.t, required this.warna});

  final double t;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = Offset.zero & size;
    canvas.save();
    // Dipotong mengikuti pil, bukan persegi — di CSS ini `overflow: hidden`
    // di atas `border-radius: 99rem`.
    canvas.clipPath(const StadiumBorder().getOuterPath(kotak));

    final cat = Paint()..color = warna;
    final lebarBatang = size.width / 4;
    final naik = size.height * (1 - t);

    // Dua batang dari bawah (`::before`) dan dua dari atas (`::after`),
    // posisinya selang-seling supaya waktu dua-duanya nyampe pil ketutup rata.
    for (final (indeks, geser) in [(0, naik), (1, -naik), (2, naik), (3, -naik)]) {
      // Tiap batang dilebihin setengah piksel ke kiri-kanan. Tanpa itu,
      // batas antar-batang jatuh di koordinat pecahan dan antialias ninggalin
      // garis jahitan tipis waktu pilnya ketutup penuh — kelihatan jelas di
      // layar Windows. Kelebihannya nggak kelihatan: warnanya sama.
      canvas.drawRect(
        Rect.fromLTWH(
          indeks * lebarBatang - 0.5,
          geser,
          lebarBatang + 1,
          size.height,
        ),
        cat,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PelukisBatang old) => old.t != t || old.warna != warna;
}

/// Melukis [child] dengan blend `difference` terhadap apa pun di bawahnya —
/// padanan `mix-blend-mode: difference` di CSS.
class _CampurBeda extends SingleChildRenderObjectWidget {
  const _CampurBeda({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCampurBeda();
}

class _RenderCampurBeda extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.difference,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
