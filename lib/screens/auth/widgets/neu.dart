import 'package:flutter/material.dart';

import '../../../core/config/lab_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sidik_material.dart';

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

  /// Aksen Cobalt buat tombol utama — sama persis sama warna interaktif di
  /// sisa app, biar tombol di layar auth dan di dalam app kebaca satu bahasa.
  final Color accent;
  final Color onAccent;
  final Color danger;

  static NeuColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // Dasarnya ikut palet inti: Bright Ivory di terang, Jet Black di gelap.
  // Dua warna bayangannya cuma versi lebih terang / lebih gelap dari dasar
  // yang sama — itu yang bikin permukaannya kebaca timbul, dan itu bukan
  // pencampuran warna palet.
  // "Meja Kerja Lab": base = MEJA, bayangan terang = KERTAS, bayangan gelap =
  // sisi bawah LOGAM. Dulu `darkShadow` #DBDBD0 — sekarang base-nya meja
  // (#D6D2C8), dan bayangan yang lebih TERANG dari dasarnya bikin kotak
  // terlihat rusak, bukan terangkat.
  static const light = NeuColors(
    base: AppColors.ivory,
    lightShadow: AppColors.white,
    darkShadow: Color(0xFFB3B0A8),
    text: AppColors.ink,
    textMuted: AppColors.textMuted,
    accent: AppColors.cobalt,
    onAccent: AppColors.white,
    danger: AppColors.crimson,
  );

  static const dark = NeuColors(
    base: AppColors.inkDeep,
    lightShadow: AppColors.inkElevated,
    darkShadow: Color(0xFF05070A),
    // Tinta tema gelap (SidikMaterial.gelapDefault.tinta). `AppColors.ivory`
    // yang dulu di sini sekarang berarti MEJA TERANG, bukan teks.
    text: Color(0xFFEAE6DC),
    textMuted: AppColors.inkTextMuted,
    accent: AppColors.cobaltLight,
    onAccent: AppColors.inkDeep,
    danger: AppColors.crimsonLight,
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
    // Bukan neumorfisme lagi: kotak "timbul dari bahan yang sama" itu justru
    // yang membuat layar Masuk, Antrean, dan Perhitungan tidak punya bidang
    // yang jelas untuk dibaca. Di sistem "Meja Kerja Lab" yang terangkat dari
    // meja adalah LEMBAR KERTAS; yang bulat (tombol ikon) adalah benda LOGAM.
    // `distance` & `blur` tetap diterima supaya pemanggil lama terkompilasi.
    final m = SidikMaterial.of(context);
    final BoxDecoration dekor;
    if (circle) {
      // Dibangun utuh, bukan `copyWith` dari logamTimbul(): copyWith tidak bisa
      // MENGHAPUS borderRadius, dan BoxShape.circle + borderRadius = assert.
      final dasar = m.logamTimbul();
      dekor = BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        gradient: color == null ? dasar.gradient : null,
        border: dasar.border,
        boxShadow: dasar.boxShadow,
      );
    } else {
      dekor = m.kertasLembar(
        radius: radius <= 12 ? radius : SidikMaterial.sudutKertas + 3,
        warna: color,
      );
    }
    return RepaintBoundary(
      child: Container(padding: padding, decoration: dekor, child: child),
    );
  }
}

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
    // Cekung = ISIAN di atas kertas: sedikit masuk, dengan garis isian tebal
    // di bawahnya seperti kolom formulir cetak. Menggantikan pelukis bayangan
    // dalam (`MaskFilter.blur`) yang dulu bikin ngelag tiap kali orang mengetik.
    final m = SidikMaterial.of(context);
    return Container(
      padding: padding,
      decoration: m.isian().copyWith(
        borderRadius: BorderRadius.circular(radius <= 8 ? radius : 6),
      ),
      child: child,
    );
  }
}

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

/// Logo resmi PT Sidik di panel timbul. Dipakai di layar yang memang lagi
/// **menyatakan identitas lab** — Splash & Login.
///
/// Sengaja panel membulat, BUKAN lingkaran seperti [NeuBrandBadge]: logonya
/// potret (308x430), dan dipaksa masuk lingkaran bikin dia harus dikecilin
/// sampai lencana KAN "LK-285-IDN" di dalamnya nggak kebaca sama sekali —
/// padahal justru nomor akreditasi itu yang bikin logonya berarti.
///
/// Latarnya dipaksa putih, bukan `c.base`: logonya dirancang di atas putih dan
/// punya bingkai biru sendiri. Ditaruh di atas permukaan neu yang gelap, bagian
/// dalamnya yang putih bakal kelihatan kayak tambalan yang salah potong.
class NeuBrandLogo extends StatelessWidget {
  const NeuBrandLogo({super.key, this.tinggi = 112});

  /// Tinggi logo. Lebarnya ngikut rasio aslinya (~0,72 x tinggi).
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return NeuRaised(
      radius: 18,
      distance: 7,
      blur: 16,
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: Colors.white,
          child: Image.asset(
            LabProfile.logoAsset,
            height: tinggi,
            fit: BoxFit.contain,
            // Kalau asetnya raib, JANGAN nampilin ikon "gambar rusak" ke
            // pengguna — jatuh balik ke medali ikon yang lama. Layar auth tetap
            // utuh; yang ilang cuma logonya.
            errorBuilder: (context, _, _) =>
                SizedBox(height: tinggi, child: const NeuBrandBadge()),
          ),
        ),
      ),
    );
  }
}

/// Medali brand bulat — avatar timbul dengan ikon di dalamnya.
///
/// Dipakai buat **penanda konteks**, bukan branding: gembok di layar lupa
/// password, amplop di layar "email terkirim", kartu nama di Register. Buat
/// identitas lab yang sebenarnya, pakai [NeuBrandLogo].
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
          color: c.accent,
        ),
        child: Icon(icon, size: 38, color: Colors.white),
      ),
    );
  }
}
