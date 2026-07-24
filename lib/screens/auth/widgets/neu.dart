import 'package:flutter/material.dart';

/// Kit "soft UI" / neumorphism — **khusus layar auth** (Login & Register).
///
/// Sengaja dipisah dari design system Titanium yang dipakai sisa app (dashboard,
/// profil). Titanium itu flat, garis tipis, kontras tinggi; ini kebalikannya:
/// permukaan lembut yang "timbul" lewat dua bayangan — terang di kiri-atas,
/// gelap di kanan-bawah, di atas satu warna dasar yang sama. Efek ini cuma
/// jalan kalau latarnya abu terang (light) / abu gelap (dark), makanya
/// palet-nya ngatur diri sendiri, nggak numpang ColorScheme app.
class NeuColors {
  const NeuColors({
    required this.base,
    required this.lightShadow,
    required this.darkShadow,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  /// Warna dasar: latar layar DAN isi kartu/field pakai warna ini. Kedalaman
  /// datang dari bayangan, bukan dari beda warna.
  final Color base;
  final Color lightShadow;
  final Color darkShadow;
  final Color text;
  final Color textMuted;

  /// Aksen biru lembut buat tombol utama — diambil dari gambar acuan.
  final Color accent;
  final Color onAccent;
  final Color danger;

  static NeuColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const light = NeuColors(
    base: Color(0xFFE4E9F0),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFB9C2D4),
    text: Color(0xFF313B4C),
    textMuted: Color(0xFF8A94A6),
    accent: Color(0xFF5B9BB5),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC0413B),
  );

  static const dark = NeuColors(
    base: Color(0xFF262B33),
    lightShadow: Color(0xFF323842),
    darkShadow: Color(0xFF181B21),
    text: Color(0xFFE7ECF3),
    textMuted: Color(0xFF9AA4B4),
    accent: Color(0xFF5FA6C4),
    onAccent: Color(0xFF07141A),
    danger: Color(0xFFE99A96),
  );
}

/// Permukaan yang **timbul** (kartu, tombol, avatar). Dua bayangan bertolak
/// arah bikin ilusi tonjolan.
class NeuRaised extends StatelessWidget {
  const NeuRaised({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
    this.distance = 6,
    this.blur = 14,
    this.circle = false,
    this.color,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double distance;
  final double blur;
  final bool circle;

  /// Override warna permukaan (dipakai tombol aksen). Default = warna dasar.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    // RepaintBoundary: dua BoxShadow blur di sini masih mahal buat di-rasterize,
    // dan tanpa ini widget-nya kena render ulang tiap frame pas scroll (dia
    // duduk di dalam SingleChildScrollView di login/register) — kerasa berat
    // di HP kentang meski nggak lagi ada CustomPaint. Dengan boundary, hasil
    // paint-nya di-cache jadi satu layer dan pas discroll tinggal digeser.
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? c.base,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: c.darkShadow,
              offset: Offset(distance, distance),
              blurRadius: blur,
            ),
            BoxShadow(
              color: c.lightShadow,
              offset: Offset(-distance, -distance),
              blurRadius: blur,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Permukaan yang **tenggelam** (kolom input) — bayangan digambar di sisi
/// DALAM. Flutter nggak punya inner-shadow bawaan, jadi dipaint manual lewat
/// selisih path.
class NeuInset extends StatelessWidget {
  const NeuInset({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return CustomPaint(
      foregroundPainter: _InsetPainter(
        light: c.lightShadow,
        dark: c.darkShadow,
        radius: radius,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.base,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _InsetPainter extends CustomPainter {
  _InsetPainter({
    required this.light,
    required this.dark,
    required this.radius,
  });

  final Color light;
  final Color dark;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    // Gelap masuk dari kiri-atas, terang dari kanan-bawah — kebalikan arah
    // permukaan timbul, jadi kolomnya kebaca "cekung".
    _inner(canvas, size, rrect, dark, const Offset(3, 3));
    _inner(canvas, size, rrect, light, const Offset(-3, -3));
    canvas.restore();
  }

  void _inner(Canvas canvas, Size size, RRect rrect, Color color, Offset o) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final outer = Path()
      ..addRect(
        Rect.fromLTRB(
          -size.width,
          -size.height,
          size.width * 2,
          size.height * 2,
        ),
      );
    final inner = Path()..addRRect(rrect.shift(o));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InsetPainter old) =>
      old.light != light || old.dark != dark || old.radius != radius;
}

/// Kolom input soft: pill cekung, ikon di kiri, placeholder di dalam (bukan
/// label di atas — ngikutin gambar acuan). Error/helper muncul di bawahnya.
///
/// Tetap membungkus [TextField] asli, jadi autofill, toggle password, dan test
/// yang nyari `TextField` semuanya masih jalan.
class NeuTextField extends StatefulWidget {
  const NeuTextField({
    super.key,
    required this.icon,
    this.controller,
    this.hint,
    this.obscure = false,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final IconData icon;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  late bool _tersembunyi = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final adaError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: NeuInset(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: c.textMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    obscureText: _tersembunyi,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: c.accent,
                    style: TextStyle(color: c.text, fontSize: 16),
                    decoration:
                        InputDecoration.collapsed(
                          hintText: widget.hint,
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 16,
                          ),
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                  ),
                ),
                if (widget.obscure)
                  GestureDetector(
                    onTap: () => setState(() => _tersembunyi = !_tersembunyi),
                    child: Icon(
                      _tersembunyi
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: c.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (adaError || widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 6),
            child: Text(
              widget.errorText ?? widget.helperText!,
              style: TextStyle(
                fontSize: 12,
                color: adaError ? c.danger : c.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tombol utama soft — permukaan timbul warna aksen biru. Waktu loading:
/// nggak bisa dipencet + spinner, biar submit nggak dobel.
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final aktif = !loading && onPressed != null;

    return NeuRaised(
      radius: 26,
      distance: 5,
      blur: 12,
      color: c.accent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aktif ? onPressed : null,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(c.onAccent),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: c.onAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Link teks soft (Lupa Password?, Daftar, Masuk).
class NeuTextLink extends StatelessWidget {
  const NeuTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.strong = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            color: strong ? c.accent : c.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Banner error soft — kolom cekung, teks merah lembut. Dipakai Login,
/// Register, & Forgot Password.
class NeuErrorBanner extends StatelessWidget {
  const NeuErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return NeuInset(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: c.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol back bulat timbul.
class NeuBackButton extends StatelessWidget {
  const NeuBackButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuRaised(
        circle: true,
        distance: 4,
        blur: 8,
        padding: const EdgeInsets.all(11),
        child: Icon(Icons.arrow_back, size: 20, color: c.text),
      ),
    );
  }
}

/// Medali brand bulat — avatar timbul dengan lingkaran aksen di dalamnya.
/// Ganti [icon] jadi logo resmi PT Sidik begitu asetnya ada.
class NeuBrandBadge extends StatelessWidget {
  const NeuBrandBadge({super.key, this.icon = Icons.precision_manufacturing});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return NeuRaised(
      circle: true,
      distance: 7,
      blur: 16,
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 76,
        width: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent, Color.lerp(c.accent, Colors.black, 0.28)!],
          ),
        ),
        child: Icon(icon, size: 38, color: Colors.white),
      ),
    );
  }
}
