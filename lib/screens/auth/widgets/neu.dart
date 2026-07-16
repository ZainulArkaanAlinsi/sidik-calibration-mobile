import 'package:flutter/material.dart';

import '../../../core/config/lab_profile.dart';

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
    this.distance = 5,
    this.blur = 10,
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

/// Permukaan yang **tenggelam** (kolom input, banner error).
///
/// Dulu inner-shadow-nya dipaint manual pakai `CustomPaint` + `MaskFilter.blur`
/// — cantik tapi BERAT: tiap field maksa `saveLayer` + blur raster tiap kali
/// re-paint (fokus/ngetik), bikin nge-lag di HP low-end. Sekarang kesan
/// "cekung" ditiru murni pakai **gradasi + garis tipis** (tanpa blur, tanpa
/// saveLayer): sisi atas sedikit gelap (bayangan jatuh ke dalam), sisi bawah
/// sedikit terang (cahaya nyangkut di bibir bawah).
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

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(c.base, c.darkShadow, 0.32)!,
            Color.lerp(c.base, c.lightShadow, 0.16)!,
          ],
        ),
        border: Border.all(
          color: c.darkShadow.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Label kecil di atas kolom input (mis. "ID Pegawai / Email", "Password").
class NeuFieldLabel extends StatelessWidget {
  const NeuFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.textMuted,
        ),
      ),
    );
  }
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
                    // Semua border DIPAKSA none di tiap state. Kalau cuma pakai
                    // InputDecoration.collapsed, `focusedBorder` dari tema
                    // Titanium (garis gelap) bocor pas field difokus — itu
                    // "border hitam" yang muncul waktu dipencet. Kolom neu
                    // udah punya bentuk sendiri (NeuInset), jadi nggak perlu.
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 16),
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

/// Tombol utama soft — permukaan timbul **monokrom** (warna dasar yang sama
/// kayak latar, kedalaman datang dari bayangan; ngikutin gambar acuan yang
/// nggak pakai warna aksen). Waktu loading: nggak bisa dipencet + spinner,
/// biar submit nggak dobel.
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
                      valueColor: AlwaysStoppedAnimation(c.text),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: aktif ? c.text : c.textMuted,
                      fontSize: 17,
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
            // Monokrom: link kuat = teks terang tebal (bukan biru), link biasa
            // = abu. Sesuai gambar acuan ("Sign up" putih tebal).
            color: strong ? c.text : c.textMuted,
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

/// Footer identitas lab (PT Sidik + akreditasi KAN), bergaya neu.
/// Nyebut lab yang terakreditasi — nama yang muncul di sertifikat.
class NeuPoweredBy extends StatelessWidget {
  const NeuPoweredBy({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final muted = TextStyle(fontSize: 11, color: c.textMuted);

    return Column(
      children: [
        Text(
          LabProfile.namaSingkat.toUpperCase(),
          textAlign: TextAlign.center,
          style: muted.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Terakreditasi KAN ${LabProfile.nomorAkreditasi} · ${LabProfile.standar}',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }
}

/// Path aset logo resmi PT Sidik. Dipublik biar bisa di-precache di golden test
/// (decode gambar di test di-pause; harus di-precache manual biar nggak kosong).
const String kLogoPtSidik = 'assets/images/logo_pt_sidik.png';

/// Biru brand PT Sidik (disampel dari logo). Dipakai buat aksen halus di badge.
const Color kBrandBlue = Color(0xFF003C9C);

/// Badge brand — "app-icon" berisi **logo resmi PT Sidik**.
///
/// Logo variant: kotak-bulat (squircle) putih dengan gradasi tipis + bingkai
/// biru brand, dibingkai cincin neu yang timbul — berasa lencana resmi, lebih
/// hidup daripada sekadar gambar di lingkaran polos. Kalau [icon] diisi, dia
/// nampilin ikon monokrom bulat (state kontekstual, mis. cakram "email
/// terkirim").
class NeuBrandBadge extends StatelessWidget {
  const NeuBrandBadge({super.key, this.icon});

  /// null → logo PT Sidik. Diisi → ikon monokrom (state kontekstual).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    if (icon != null) {
      return NeuRaised(
        circle: true,
        distance: 6,
        blur: 12,
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.darkShadow,
                Color.lerp(c.darkShadow, Colors.black, 0.4)!,
              ],
            ),
            border: Border.all(color: c.lightShadow, width: 1.5),
          ),
          child: Icon(icon, size: 36, color: c.text),
        ),
      );
    }

    return NeuRaised(
      radius: 26,
      distance: 6,
      blur: 12,
      padding: const EdgeInsets.all(10),
      child: Container(
        height: 88,
        width: 88,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Putih → biru sangat muda: kasih "napas" tanpa ganggu keterbacaan.
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFEAF1FC)],
          ),
          border: Border.all(
            color: kBrandBlue.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Image.asset(
          kLogoPtSidik,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
