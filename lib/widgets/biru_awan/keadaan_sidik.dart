import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'hero_langit.dart';
import 'toast_sidik.dart';
import 'tombol_sidik.dart';

/// Ragam [KeadaanMemuat].
enum RagamMemuat {
  /// Daftar kerangka: baris putih dengan blok berdenyut.
  kerangka,

  /// Spinner 36 yang baru tampil setelah menunggu 400 ms.
  spinner,
}

/// Keadaan memuat Biru Awan (`ELEMEN.md` §Keadaan).
///
/// - [RagamMemuat.kerangka] ([baris] baris 64, sudut 18): blok berdenyut 1,2 dtk,
///   antar baris bergeser 150 ms. Denyut berhenti setelah 5 siklus dan begitu
///   widget dilepas (artboard menulis "infinite"; dibatasi supaya `pumpAndSettle`
///   selesai dan gerak otomatis tidak lebih dari beberapa detik). "Kurangi
///   gerak" = diam sejak awal.
/// - [RagamMemuat.spinner]: 36 primer di rel kabut, tampil HANYA bila menunggu
///   lebih dari 400 ms (sebelumnya ruangnya dipesan kosong supaya tata letak
///   tidak melompat). Dengan "kurangi gerak" busurnya diam. Ini satu-satunya
///   gerak berulang tanpa batas (pemutar harus terus berputar selama menunggu).
/// - Pembaca layar: satu simpul live region berlabel [label] (bawaan "Memuat").
///   Komponen tidak menampilkan kemajuan angka.
class KeadaanMemuat extends StatefulWidget {
  const KeadaanMemuat.kerangka({super.key, this.baris = 3, this.label})
    : ragam = RagamMemuat.kerangka;

  const KeadaanMemuat.spinner({super.key, this.label})
    : ragam = RagamMemuat.spinner,
      baris = 0;

  final RagamMemuat ragam;
  final int baris;
  final String? label;

  @override
  State<KeadaanMemuat> createState() => _KeadaanMemuatState();
}

class _KeadaanMemuatState extends State<KeadaanMemuat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _tunda;
  bool _spinnerTampil = false;
  bool _berdenyut = false;

  @override
  void initState() {
    super.initState();
    // Dibuat di sini (bukan `late final` berinisialisasi malas): ragam spinner
    // tidak memakainya, dan pembuatan malas di `dispose` membuat ticker pada
    // elemen yang sudah nonaktif.
    _c = AnimationController(vsync: this);
    if (widget.ragam == RagamMemuat.spinner) {
      _tunda = Timer(UkuranUmpanBalikBiruAwan.spinnerTunda, () {
        if (mounted) setState(() => _spinnerTampil = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.ragam != RagamMemuat.kerangka) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
      _berdenyut = false;
    } else if (!_berdenyut) {
      _berdenyut = true;
      _c.duration = _total(widget.baris);
      _c.forward(from: 0);
    }
  }

  static Duration _total(int baris) =>
      UkuranUmpanBalikBiruAwan.kerangkaDenyut *
          UkuranUmpanBalikBiruAwan.kerangkaDenyutMaks +
      UkuranUmpanBalikBiruAwan.kerangkaGeser * math.max(0, baris - 1);

  @override
  void dispose() {
    _tunda?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Opasitas baris ke-[i] saat pengendali di [nilai]: 1 -> alfa rendah -> 1
  /// (kosinus, seperti ease-in-out), mulai [i] x 150 ms, sebanyak 5 siklus.
  double _opasitas(double nilai, int i) {
    final totalMs = _c.duration?.inMilliseconds ?? 0;
    if (totalMs == 0) return 1;
    final t =
        (nilai * totalMs -
            i * UkuranUmpanBalikBiruAwan.kerangkaGeser.inMilliseconds) /
        UkuranUmpanBalikBiruAwan.kerangkaDenyut.inMilliseconds;
    if (t <= 0 || t >= UkuranUmpanBalikBiruAwan.kerangkaDenyutMaks) return 1;
    final denyut = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    return 1 - denyut * (1 - UkuranUmpanBalikBiruAwan.kerangkaAlfaRendah);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final u = WarnaUmpanBalikBiruAwan.of(context);

    final Widget isi;
    if (widget.ragam == RagamMemuat.spinner) {
      final reduksi = MediaQuery.disableAnimationsOf(context);
      isi = Center(
        heightFactor: 1,
        child: SizedBox.square(
          dimension: UkuranUmpanBalikBiruAwan.spinner,
          child: _spinnerTampil
              ? CircularProgressIndicator(
                  strokeWidth: UkuranUmpanBalikBiruAwan.spinnerGaris,
                  value: reduksi ? 0.25 : null,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: m.biruTipis,
                )
              : null,
        ),
      );
    } else {
      isi = AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.baris; i++) ...[
              if (i > 0) const SizedBox(height: JarakBiruAwan.blok),
              Opacity(
                opacity: _opasitas(_c.value, i),
                child: _BarisKerangka(
                  isi: m.kertas,
                  blok: u.kerangka,
                  blokKedua: u.kerangkaKedua,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.label ?? l10n.biruAwanMemuat,
      excludeSemantics: true,
      child: isi,
    );
  }
}

class _BarisKerangka extends StatelessWidget {
  const _BarisKerangka({
    required this.isi,
    required this.blok,
    required this.blokKedua,
  });

  final Color isi;
  final Color blok;
  final Color blokKedua;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isi,
        borderRadius: BorderRadius.circular(
          UkuranUmpanBalikBiruAwan.kerangkaRadius,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: UkuranUmpanBalikBiruAwan.kerangkaBaris,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JarakBiruAwan.blok),
          child: Row(
            children: [
              SizedBox.square(
                dimension: UkuranUmpanBalikBiruAwan.kerangkaUbin,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: blok,
                    borderRadius: BorderRadius.circular(
                      UkuranUmpanBalikBiruAwan.kerangkaUbinRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: JarakBiruAwan.blok),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor:
                          UkuranUmpanBalikBiruAwan.kerangkaBatang1Lebar,
                      child: SizedBox(
                        height: UkuranUmpanBalikBiruAwan.kerangkaBatang1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: blok,
                            borderRadius: BorderRadius.circular(
                              UkuranUmpanBalikBiruAwan.kerangkaBatang1Radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FractionallySizedBox(
                      widthFactor:
                          UkuranUmpanBalikBiruAwan.kerangkaBatang2Lebar,
                      child: SizedBox(
                        height: UkuranUmpanBalikBiruAwan.kerangkaBatang2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: blokKedua,
                            borderRadius: BorderRadius.circular(
                              UkuranUmpanBalikBiruAwan.kerangkaBatang2Radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keadaan kosong Biru Awan: ubin langit sudut 24 (min tinggi 260) dengan motif
/// skala putih, judul 20/26 800, satu kalimat (maks 220 lebar), dan SATU aksi
/// navy (pil 48; artboard 44, dinaikkan ke sasaran sentuh 48).
///
/// Teks dan aksi dari pemanggil (l10n). Tanpa [aksi] ubinnya tidak membawa
/// tombol. Teks navy di atas langit (putih DILARANG, 2,26:1); motif hiasan.
class KeadaanKosong extends StatelessWidget {
  const KeadaanKosong({
    super.key,
    required this.judul,
    required this.isi,
    this.aksi,
    this.onAksi,
  });

  final String judul;
  final String isi;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final lanjut = WarnaLanjutBiruAwan.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lanjut.isiHero,
        borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: UkuranUmpanBalikBiruAwan.keadaanMin,
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            UkuranUmpanBalikBiruAwan.keadaanBantalan,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: UkuranUmpanBalikBiruAwan.motifKosongLebar,
                  ),
                  child: AspectRatio(
                    aspectRatio: MotifSkala.lebar / MotifSkala.tinggi,
                    child: CustomPaint(
                      painter: PelukisMotifSkala(warna: lanjut.motifHero),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                label: '$judul. $isi',
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      judul,
                      textAlign: TextAlign.center,
                      style: HurufBiruAwan.judulAnak.copyWith(
                        color: lanjut.tintaHero,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: UkuranUmpanBalikBiruAwan.keadaanIsiLebarMaks,
                      ),
                      child: Text(
                        isi,
                        textAlign: TextAlign.center,
                        style: HurufBiruAwan.keterangan.copyWith(
                          color: lanjut.tintaHero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (aksi != null) ...[
                const SizedBox(height: AppSpacing.md),
                TombolSidik(
                  label: aksi!,
                  onPressed: onAksi,
                  ragam: RagamTombolSidik.tegas,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Keadaan galat Biru Awan: ubin koral tipis sudut 24, ubin ikon koral 48,
/// judul, kalimat (pesan server apa adanya bila ada, dari pemanggil) dan satu
/// tombol navy "Coba lagi" (pil 48; artboard 44, dinaikkan ke sasaran 48).
///
/// Pembaca layar: simpul live region "judul. isi" supaya galat yang muncul
/// diumumkan; tombolnya simpul sendiri. Tanpa [aksi] tidak ada tombol.
class KeadaanGalat extends StatelessWidget {
  const KeadaanGalat({
    super.key,
    required this.judul,
    required this.isi,
    this.aksi,
    this.onAksi,
  });

  final String judul;
  final String isi;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.isi(IsiBiruAwan.koralTipis),
        borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: UkuranUmpanBalikBiruAwan.keadaanMin,
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            UkuranUmpanBalikBiruAwan.keadaanBantalan,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const UbinUmpanBalik(
                ikon: Icons.warning_amber_rounded,
                warna: IsiBiruAwan.koral,
                ukuran: UkuranUmpanBalikBiruAwan.galatUbin,
                radius: UkuranUmpanBalikBiruAwan.galatUbinRadius,
                ukuranIkon: UkuranUmpanBalikBiruAwan.galatIkon,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                liveRegion: true,
                label: '$judul. $isi',
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      judul,
                      textAlign: TextAlign.center,
                      style: HurufBiruAwan.judulAnak.copyWith(color: m.tinta),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isi,
                      textAlign: TextAlign.center,
                      style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
                    ),
                  ],
                ),
              ),
              if (aksi != null) ...[
                const SizedBox(height: AppSpacing.md),
                TombolSidik(
                  label: aksi!,
                  onPressed: onAksi,
                  ragam: RagamTombolSidik.tegas,
                  ikon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
