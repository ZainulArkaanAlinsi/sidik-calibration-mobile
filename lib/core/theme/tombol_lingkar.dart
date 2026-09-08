import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gaya tombol "animated-button" (acuan desain Uiverse karya ryota1231):
/// waktu disentuh, satu lingkaran mekar dari tengah sampai memenuhi tombolnya,
/// dan pilnya sekalian berubah jadi kotak membulat.
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
/// ## Panah di acuannya SENGAJA nggak dibawa
///
/// Tombol acuannya punya panah yang bertukar sisi waktu disentuh. Panah itu
/// berarti "lanjut/maju" — dan tombol di app ini nggak semuanya begitu.
/// Memasang panah di **HAPUS** atau **NONAKTIFKAN** bukan hiasan yang salah
/// tempat, tapi janji yang salah: orang membaca panah sebagai "ini membawaku
/// ke langkah berikutnya", bukan "ini menghapus".
///
/// Tombol yang memang berarti maju sudah punya jalannya sendiri —
/// `AppButton(trailingIcon: ...)`, yang dipakai mis. di tombol masuk.
///
/// ## Warna label
///
/// Dioper terang-terangan lewat [label] — dua warna, satu buat diam satu buat
/// disentuh. Lihat catatan di situ soal kenapa trik `difference` yang lebih
/// ringkas justru salah begitu lingkarannya berwarna.
class TombolLingkar {
  const TombolLingkar._();

  /// Lama lingkaran mekar. Di CSS acuannya `.8s cubic-bezier(.23,1,.32,1)` —
  /// kurva yang lari cepat di awal lalu mendarat pelan.
  static const durasi = Duration(milliseconds: 520);

  /// Padanan `cubic-bezier(0.23, 1, 0.32, 1)`.
  static const kurva = Curves.easeOutExpo;

  /// Bentuk waktu diam: pil.
  static const bentukDiam = StadiumBorder();

  /// Bentuk waktu disentuh: kotak membulat — `border-radius: 100px` jadi
  /// `12px` di CSS acuannya. Peralihannya dianimasikan sendiri oleh `Material`
  /// (`_MaterialInterior`), jadi cukup dibedakan per-keadaan di `ButtonStyle`.
  static final bentukSentuh = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );

  /// Apakah keadaan ini dianggap "lagi disentuh".
  ///
  /// Tekan ikut dihitung, bukan cuma hover: di HP nggak ada hover sama sekali,
  /// dan HP adalah perangkat yang paling banyak dipakai teknisi. Kalau cuma
  /// `hovered` yang dipantau, seluruh gerakan ini nggak akan pernah kelihatan
  /// di sana.
  static bool disentuh(Set<WidgetState> states) =>
      !states.contains(WidgetState.disabled) &&
      (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused));

  /// Lapisan lingkaran. Pasang ke [ButtonStyle.backgroundBuilder].
  static Widget Function(BuildContext, Set<WidgetState>, Widget?) latar(
    Color warnaLingkar,
  ) {
    return (context, states, child) =>
        _Lingkaran(maju: disentuh(states), warna: warnaLingkar, child: child);
  }

  /// Warna label + HURUF BESAR. Pasang ke [ButtonStyle.foregroundBuilder].
  ///
  /// [diam] dipakai waktu tombolnya belum disentuh, [sentuh] waktu lingkaran
  /// sudah menutupinya. Peralihannya dianimasikan dengan kurva & durasi yang
  /// sama dengan lingkarannya.
  ///
  /// Versi pertama nggak pakai warna sama sekali — labelnya ditulis putih lalu
  /// dilukis dengan blend `difference`, biar satu aturan cukup buat semua
  /// keadaan. Itu rapi di atas hitam-putih, tapi salah begitu lingkarannya
  /// berwarna: putih di atas mint jadi (96, 10, 27) — MERAH TUA, bukan gelap
  /// netral. Warna eksplisit lebih panjang ditulis, tapi dia yang benar.
  static Widget Function(BuildContext, Set<WidgetState>, Widget?) label(
    Color diam,
    Color sentuh,
  ) {
    return (context, states, child) {
      final isi = _hurufBesar(child);

      // Tombol mati warnanya diurus `disabledForegroundColor` di tema; jangan
      // ditimpa dari sini, nanti yang nggak bisa dipencet malah keliatan
      // nyala.
      if (states.contains(WidgetState.disabled)) return isi;

      final tujuan = disentuh(states) ? sentuh : diam;
      final durasi = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TombolLingkar.durasi;

      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: tujuan),
        duration: durasi,
        curve: TombolLingkar.kurva,
        child: isi,
        builder: (context, warna, anak) => DefaultTextStyle.merge(
          style: TextStyle(color: warna),
          child: IconTheme.merge(
            data: IconThemeData(color: warna),
            child: anak!,
          ),
        ),
      );
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

class _Lingkaran extends StatelessWidget {
  const _Lingkaran({required this.maju, required this.warna, this.child});

  final bool maju;
  final Color warna;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Hormati "kurangi gerak": lingkarannya tetap muncul, cuma nggak mekar.
    final durasi = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TombolLingkar.durasi;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: maju ? 1.0 : 0.0),
      duration: durasi,
      curve: TombolLingkar.kurva,
      // Anaknya dibangun SEKALI dan dioper lewat `child`: yang berubah tiap
      // frame cuma lukisan lingkarannya, bukan isi tombolnya.
      child: child,
      builder: (context, t, isi) => CustomPaint(
        painter: t == 0 ? null : _PelukisLingkaran(t: t, warna: warna),
        child: isi,
      ),
    );
  }
}

class _PelukisLingkaran extends CustomPainter {
  _PelukisLingkaran({required this.t, required this.warna});

  final double t;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Dipotong mengikuti bentuk tombol yang SEDANG berlaku, bukan kotak.
    //
    // Sempat cuma `clipRect` dengan alasan "bentuk membulatnya kan diurus
    // Material lewat `shape`". Ternyata potongan Material nggak sampai ke
    // lapisan ini: hasilnya lingkaran mint bersudut siku di ujung tombol yang
    // pilnya membulat. Jari-jarinya dilerp pakai `t` yang sama dengan
    // lingkarannya, jadi potongannya selalu pas sama bentuk yang lagi
    // dianimasikan Material.
    final radius = Radius.circular(
      (size.height / 2) + (12 - size.height / 2) * t,
    );
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
    );

    // Jari-jari akhir = setengah diagonal, supaya lingkarannya benar-benar
    // menutup pojok terjauh. Dihitung dari ukuran nyata, bukan dipatok 220 px
    // seperti CSS acuannya: tombol di app ini lebarnya dari 90 sampai 600 dp,
    // dan angka mati bikin yang lebar nggak pernah ketutup penuh.
    final rMaks = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      t * rMaks,
      Paint()..color = warna,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PelukisLingkaran old) => old.t != t || old.warna != warna;
}
