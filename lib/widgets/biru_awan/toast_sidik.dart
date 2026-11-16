import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';

/// Jenis toast. [kabar] = kabar masuk dari push/realtime (kartu navy + logo).
enum JenisToast { sukses, info, peringatan, galat, kabar }

/// Kunci cincin fokus kontrol kecil (tutup, pil aksi). Hanya satu kontrol
/// berfokus sekaligus, jadi satu kunci cukup untuk tes.
const Key kunciCincinFokusUmpanBalik = ValueKey<String>(
  'cincin-fokus-umpan-balik',
);

/// Tombol kecil yang sasarannya >= 48 dp walau gambarnya lebih kecil, dengan
/// cincin fokus di LUAR gambar (pola `TombolSidik`): 2 dp celah + 2 dp garis,
/// jadi cincin pas di dalam sasaran 48 untuk gambar 40 dan tidak terpotong
/// kartu induknya.
class _KontrolKecil extends StatefulWidget {
  const _KontrolKecil({
    required this.label,
    required this.onPressed,
    required this.cincin,
    required this.bentuk,
    required this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color cincin;
  final OutlinedBorder bentuk;
  final Widget child;

  @override
  State<_KontrolKecil> createState() => _KontrolKecilState();
}

class _KontrolKecilState extends State<_KontrolKecil> {
  bool _fokus = false;

  @override
  Widget build(BuildContext context) {
    final aktif = widget.onPressed != null;
    const luar = UkuranKomponenBiruAwan.jarakCincinFokus + AppUkuran.garisTebal;
    return Semantics(
      container: true,
      button: true,
      enabled: aktif,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onPressed,
        customBorder: widget.bentuk,
        focusColor: Colors.transparent,
        onFocusChange: (f) => setState(() => _fokus = f),
        // `Center` tanpa faktor akan mengisi seluruh tinggi yang tersedia dan
        // membuat kartu induknya setinggi batas; faktor 1 membungkus gambar,
        // lalu `ConstrainedBox` menaikkannya ke sasaran 48.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppUkuran.sasaranSentuh,
            minHeight: AppUkuran.sasaranSentuh,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // Margin selebar celah + garis cincin di semua sisi: cincin yang
            // digambar di luar gambar tetap berada di dalam sasaran.
            child: Padding(
              padding: const EdgeInsets.all(luar),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  widget.child,
                  if (_fokus && aktif)
                    Positioned(
                      key: kunciCincinFokusUmpanBalik,
                      left: -luar,
                      top: -luar,
                      right: -luar,
                      bottom: -luar,
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: widget.bentuk.copyWith(
                                side: BorderSide(
                                  color: widget.cincin,
                                  width: AppUkuran.garisTebal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol tutup bulat berikon "x" (gambar [ukuran], sasaran >= 48). [label]
/// WAJIB (tidak ada kata yang terlihat). Dipakai toast dan lembar bawah.
class TombolTutupSidik extends StatelessWidget {
  const TombolTutupSidik({
    super.key,
    required this.label,
    required this.onPressed,
    this.ukuran = UkuranUmpanBalikBiruAwan.toastUbin,
    this.warnaIkon,
    this.warnaCincin,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Garis tengah gambar (40 di toast, 44 di lembar bawah).
  final double ukuran;

  /// `null` = tinta kedua.
  final Color? warnaIkon;

  /// `null` = tinta.
  final Color? warnaCincin;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return _KontrolKecil(
      label: label,
      onPressed: onPressed,
      cincin: warnaCincin ?? m.tinta,
      bentuk: const CircleBorder(),
      child: SizedBox.square(
        dimension: ukuran,
        child: Center(
          child: Icon(
            Icons.close_rounded,
            size: UkuranUmpanBalikBiruAwan.toastIkonTutup,
            color: warnaIkon ?? m.tinta2,
          ),
        ),
      ),
    );
  }
}

/// Pil aksi kecil di toast dan banner ("Lihat", "Coba lagi", "Pasang"): gambar
/// tinggi 40, sasaran >= 48. [isi] dan [tinta] dari pemanggil (primer di toast
/// biasa, putih di kabar, navy di banner pembaruan); [cincin] harus >= 3:1
/// terhadap latar tempat pil duduk.
class PilAksiSidik extends StatelessWidget {
  const PilAksiSidik({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isi,
    required this.tinta,
    required this.cincin,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color isi;
  final Color tinta;
  final Color cincin;

  @override
  Widget build(BuildContext context) {
    return _KontrolKecil(
      label: label,
      onPressed: onPressed,
      cincin: cincin,
      bentuk: const StadiumBorder(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isi,
          borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: UkuranUmpanBalikBiruAwan.pilAksi,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UkuranUmpanBalikBiruAwan.pilAksiBantalan,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: HurufUmpanBalikBiruAwan.aksiPil.copyWith(color: tinta),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ubin berwarna berisi ikon (toast 40/14, dialog 56/20, galat 48/16). Hiasan:
/// tidak masuk pohon semantik.
class UbinUmpanBalik extends StatelessWidget {
  const UbinUmpanBalik({
    super.key,
    required this.ikon,
    required this.warna,
    required this.ukuran,
    required this.radius,
    required this.ukuranIkon,
  });

  final IconData ikon;
  final IsiBiruAwan warna;
  final double ukuran;
  final double radius;
  final double ukuranIkon;

  @override
  Widget build(BuildContext context) {
    final w = WarnaBiruAwan.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: ukuran,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: w.isi(warna),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Icon(ikon, size: ukuranIkon, color: w.tinta(warna)),
          ),
        ),
      ),
    );
  }
}

/// Kartu toast Biru Awan (`ELEMEN.md` §Toast): ubin ikon 40, judul 15/800, isi
/// 13/18, aksi opsional (pil 40) dan tombol tutup. Kartu saja: tidak memosisikan,
/// menganimasikan, atau menghitung waktu; itu tugas [tampilkanToast] dan
/// `LapisanKabarMasuk`.
///
/// - [jenis] `kabar`: kartu navy, ubin putih berisi logo PT SIDIK, teks putih,
///   aksi pil putih. [onKetuk] membuat seluruh kartu bisa diketuk (kabar masuk
///   membuka tujuannya); kontrol di dalamnya tetap menang atas ketukan kartu.
/// - Pembaca layar menerima SATU simpul berlabel "jenis. judul. isi" (ikon
///   hiasan dikeluarkan), ditambah simpul tombol aksi dan tutup. [wilayahHidup]
///   menandainya sebagai live region (dipakai kabar masuk, yang tidak lewat
///   [tampilkanToast]); [tampilkanToast] sendiri mengumumkan lewat
///   `SemanticsService`.
/// - Tinggi minimum 68; sasaran tutup dan aksi 48 membuat kartu 72 bila ada
///   salah satunya. Lebar kartu < 320 atau huruf > 1,15: aksi pindah ke bawah
///   teks. Kartu tidak lebih tinggi dari setengah layar; isinya bergulir.
class ToastSidik extends StatelessWidget {
  const ToastSidik({
    super.key,
    required this.jenis,
    required this.judul,
    this.isi,
    this.aksi,
    this.onAksi,
    this.onTutup,
    this.onKetuk,
    this.wilayahHidup = false,
  });

  final JenisToast jenis;
  final String judul;
  final String? isi;
  final String? aksi;
  final VoidCallback? onAksi;

  /// `null` = tanpa tombol tutup.
  final VoidCallback? onTutup;

  /// Ketukan di seluruh kartu (kabar masuk).
  final VoidCallback? onKetuk;
  final bool wilayahHidup;

  /// Berapa lama toast tampil sebelum hilang sendiri; `null` = tidak hilang
  /// sendiri. Galat dan toast beraksi tetap sampai ditutup (`ELEMEN.md`).
  static Duration? lamaTampil(JenisToast jenis, {required bool beraksi}) {
    if (jenis == JenisToast.galat || beraksi) return null;
    if (jenis == JenisToast.peringatan) {
      return UkuranUmpanBalikBiruAwan.toastPeringatan;
    }
    return UkuranUmpanBalikBiruAwan.toastSukses;
  }

  static (IconData, IsiBiruAwan) _ikonDan(JenisToast jenis) => switch (jenis) {
    JenisToast.sukses => (Icons.check_rounded, IsiBiruAwan.hijau),
    JenisToast.info => (Icons.info_outline_rounded, IsiBiruAwan.kabut),
    JenisToast.peringatan => (Icons.warning_amber_rounded, IsiBiruAwan.kuning),
    JenisToast.galat => (Icons.close_rounded, IsiBiruAwan.koral),
    JenisToast.kabar => (Icons.notifications_none_rounded, IsiBiruAwan.kabut),
  };

  /// Label simpul pembaca layar.
  static String labelSemantik(
    AppLocalizations l10n,
    JenisToast jenis,
    String judul,
    String? isi,
  ) {
    final kata = switch (jenis) {
      JenisToast.sukses => l10n.biruAwanJenisSukses,
      JenisToast.info => l10n.biruAwanJenisInfo,
      JenisToast.peringatan => l10n.biruAwanJenisPeringatan,
      JenisToast.galat => l10n.biruAwanJenisGalat,
      JenisToast.kabar => '',
    };
    return [kata, judul, isi ?? ''].where((s) => s.isNotEmpty).join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final s = Theme.of(context).colorScheme;
    final u = WarnaUmpanBalikBiruAwan.of(context);
    final kabar = jenis == JenisToast.kabar;

    final latar = kabar ? u.kabarLatar : m.kertas;
    final teks = kabar ? u.kabarTeks : m.tinta;
    final teksKedua = kabar ? u.kabarTeksKedua : m.tinta2;
    final cincin = kabar ? u.kabarTeks : m.tinta;
    final radius = BorderRadius.circular(UkuranUmpanBalikBiruAwan.toastRadius);

    final Widget ubin = kabar
        ? ExcludeSemantics(
            child: SizedBox.square(
              dimension: UkuranUmpanBalikBiruAwan.toastUbin,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: u.kabarUbin,
                  borderRadius: BorderRadius.circular(
                    UkuranUmpanBalikBiruAwan.toastUbinRadius,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo_pt_sidik.png',
                    width: UkuranUmpanBalikBiruAwan.logoKabar,
                    height: UkuranUmpanBalikBiruAwan.logoKabar,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          )
        : UbinUmpanBalik(
            ikon: _ikonDan(jenis).$1,
            warna: _ikonDan(jenis).$2,
            ukuran: UkuranUmpanBalikBiruAwan.toastUbin,
            radius: UkuranUmpanBalikBiruAwan.toastUbinRadius,
            ukuranIkon: UkuranUmpanBalikBiruAwan.toastIkon,
          );

    final punyaIsi = isi != null && isi!.isNotEmpty;
    // Teks tampil saja; pembaca layar menerima labelnya dari simpul kartu di
    // bawah (satu simpul "jenis. judul. isi", bukan dua teks terpisah).
    final Widget teksNode = ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            // Kartu kabar masuk mempertahankan batas baris lama (judul 1,
            // isi 2) supaya teks panjang tidak memenuhi layar selama 5 dtk.
            maxLines: kabar ? 1 : null,
            overflow: kabar ? TextOverflow.ellipsis : null,
            style: HurufUmpanBalikBiruAwan.judulToast.copyWith(color: teks),
          ),
          if (punyaIsi)
            Padding(
              padding: const EdgeInsets.only(top: JarakBiruAwan.baris),
              child: Text(
                isi!,
                maxLines: kabar ? 2 : null,
                overflow: kabar ? TextOverflow.ellipsis : null,
                style: HurufBiruAwan.keteranganKecil.copyWith(color: teksKedua),
              ),
            ),
        ],
      ),
    );

    PilAksiSidik? pil() => aksi == null
        ? null
        : PilAksiSidik(
            label: aksi!,
            onPressed: onAksi,
            isi: kabar ? u.kabarAksiIsi : s.primary,
            tinta: kabar ? u.kabarAksiTinta : s.onPrimary,
            cincin: cincin,
          );

    final tinggiMaks =
        MediaQuery.sizeOf(context).height *
        UkuranUmpanBalikBiruAwan.toastTinggiNisbiMaks;

    // Simpul kartu: label lengkap + live region (bila diminta) + aksi ketuk dari
    // `InkWell` (kabar masuk), yang ikut melebur ke simpul ini. Pil aksi dan
    // tombol tutup `container: true`, jadi tetap simpul tombol sendiri. Jangan
    // pakai `explicitChildNodes` di sini: ketukan `InkWell` akan menjadi simpul
    // tanpa label.
    return Semantics(
      container: true,
      liveRegion: wilayahHidup,
      label: labelSemantik(l10n, jenis, judul, isi),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: latar,
          borderRadius: radius,
          boxShadow: u.bayanganToast,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onKetuk,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: UkuranUmpanBalikBiruAwan.toastTinggiMin,
                maxHeight: tinggiMaks,
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final skala = MediaQuery.textScalerOf(context).scale(1);
                  final bertumpuk =
                      aksi != null &&
                      (c.maxWidth < UkuranUmpanBalikBiruAwan.toastBertumpukDi ||
                          skala > AmbangLab.hurufBesar);
                  final pilAksi = pil();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      JarakBiruAwan.blok,
                      JarakBiruAwan.blok,
                      UkuranUmpanBalikBiruAwan.toastBantalanKanan,
                      JarakBiruAwan.blok,
                    ),
                    child: Row(
                      children: [
                        ubin,
                        const SizedBox(width: JarakBiruAwan.blok),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                teksNode,
                                if (bertumpuk && pilAksi != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.xs,
                                    ),
                                    child: pilAksi,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!bertumpuk && pilAksi != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          pilAksi,
                        ],
                        if (onTutup != null)
                          TombolTutupSidik(
                            label: l10n.biruAwanTutup,
                            onPressed: onTutup,
                            warnaIkon: teksKedua,
                            warnaCincin: cincin,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toast yang sedang tampil (satu sekaligus). Dilepas oleh `dispose` penayang
/// bila entrinya sudah tidak ada di pohon, jadi tidak pernah menyimpan entri
/// basi (overlay yang ikut hilang bersama pohonnya).
OverlayEntry? _aktif;

/// Satu-satunya cara menampilkan toast. Menggantikan `showSnackBar`.
///
/// - Satu toast sekaligus: yang baru menggantikan yang lama.
/// - Muncul di atas, 16 dp di bawah status bar, geser turun + pudar 240 ms
///   (keluar 160 ms); "kurangi gerak" = tanpa animasi.
/// - Hilang sendiri 4 detik (peringatan 6); galat dan toast beraksi TIDAK
///   hilang sendiri ([ToastSidik.lamaTampil]). Tutup lewat tombol "x" atau
///   usap ke atas.
/// - Diumumkan ke pembaca layar lewat `SemanticsService`.
///
/// Tidak melakukan apa pun bila tidak ada `Overlay` di atas [context].
void tampilkanToast(
  BuildContext context, {
  required JenisToast jenis,
  required String judul,
  String? isi,
  String? aksi,
  VoidCallback? onAksi,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _aktif?.remove();
  _aktif = null;

  late final OverlayEntry entri;
  entri = OverlayEntry(
    builder: (_) => _PenayangToast(
      entri: entri,
      jenis: jenis,
      judul: judul,
      isi: isi,
      aksi: aksi,
      onAksi: onAksi,
    ),
  );
  _aktif = entri;
  overlay.insert(entri);

  final tampilan = View.maybeOf(context);
  if (tampilan != null) {
    SemanticsService.sendAnnouncement(
      tampilan,
      [judul, isi ?? ''].where((s) => s.isNotEmpty).join('. '),
      Directionality.of(context),
    );
  }
}

/// Menutup toast yang sedang tampil, bila ada.
void tutupToastSidik() {
  _aktif?.remove();
  _aktif = null;
}

class _PenayangToast extends StatefulWidget {
  const _PenayangToast({
    required this.entri,
    required this.jenis,
    required this.judul,
    this.isi,
    this.aksi,
    this.onAksi,
  });

  final OverlayEntry entri;
  final JenisToast jenis;
  final String judul;
  final String? isi;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  State<_PenayangToast> createState() => _PenayangToastState();
}

class _PenayangToastState extends State<_PenayangToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _hitung;
  bool _mulai = false;
  bool _menutup = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mulai) return;
    _mulai = true;

    _c.duration = AppMotion.hormati(
      context,
      UkuranUmpanBalikBiruAwan.toastMasuk,
    );
    _c.reverseDuration = AppMotion.hormati(
      context,
      UkuranUmpanBalikBiruAwan.toastKeluar,
    );
    if (_c.duration == Duration.zero) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    final lama = ToastSidik.lamaTampil(
      widget.jenis,
      beraksi: widget.aksi != null,
    );
    if (lama != null) _hitung = Timer(lama, _tutup);
  }

  @override
  void dispose() {
    _hitung?.cancel();
    _c.dispose();
    if (identical(_aktif, widget.entri)) _aktif = null;
    super.dispose();
  }

  void _lepas() {
    if (!mounted || !identical(_aktif, widget.entri)) return;
    tutupToastSidik();
  }

  void _tutup() {
    if (_menutup || !mounted) return;
    _menutup = true;
    _hitung?.cancel();
    if (_c.reverseDuration == Duration.zero) {
      _lepas();
    } else {
      _c.reverse().whenComplete(_lepas);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kurva = CurvedAnimation(
      parent: _c,
      curve: AppMotion.masuk,
      reverseCurve: AppMotion.keluar,
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UkuranUmpanBalikBiruAwan.toastJarakLuar,
          UkuranUmpanBalikBiruAwan.toastJarakLuar,
          UkuranUmpanBalikBiruAwan.toastJarakLuar,
          0,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: kurva,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.6),
                end: Offset.zero,
              ).animate(kurva),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: UkuranUmpanBalikBiruAwan.toastLebarMaks,
                ),
                child: Dismissible(
                  key: ValueKey<Object>(widget.entri),
                  direction: DismissDirection.up,
                  movementDuration: AppMotion.hormati(
                    context,
                    UkuranUmpanBalikBiruAwan.toastKeluar,
                  ),
                  onDismissed: (_) => _lepas(),
                  child: ToastSidik(
                    jenis: widget.jenis,
                    judul: widget.judul,
                    isi: widget.isi,
                    aksi: widget.aksi,
                    onAksi: widget.onAksi == null
                        ? null
                        : () {
                            // Ketukan kedua selama animasi keluar (160 ms)
                            // tidak boleh memanggil aksi lagi ("Coba lagi",
                            // kirim): guard yang sama dengan `_tutup`.
                            if (_menutup) return;
                            widget.onAksi!();
                            _tutup();
                          },
                    onTutup: _tutup,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
