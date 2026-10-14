/// Grid BACA Studio Data Acuan (S2) — widget bawaan saja: `ListView.builder`
/// tervirtualisasi di dalam gulir horizontal, kepala kolom lengket.
///
/// Kolom, label, satuan, dan tanda `perlu_konfirmasi` datang dari skema
/// server (`skemaAcuan()` profil). Tidak ada satu pun `if` per alat di sini:
/// alat ke-2 sampai ke-32 tampil dengan kode yang sama.
///
/// **Nilai tampil persis.** Tidak dibulatkan, nol belakang tidak dibuang,
/// `20.0` tetap `20.0` dan `200` tetap `200` ([teksAngkaPersis]). Lebar kolom
/// diukur dari isinya supaya angka tidak pernah terpotong elipsis.
///
/// Sunting (F2, tempel TSV, Ctrl+Z) milik fase P2 — belum ada di sini.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/sidik_material.dart';
import '../../../core/theme/sidik_theme.dart';
import '../../../core/utils/angka.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/data_acuan.dart';

/// Teks satu nilai sel APA ADANYA. `null` = nilai JSON `null` — pemanggil
/// yang memberi label "kosong" (beda dari sel yang tidak ada sama sekali).
String? teksNilaiAcuan(Object? nilai) => switch (nilai) {
  null => null,
  final num n => teksAngkaPersis(n),
  final String s => s,
  final bool b => '$b',
  final List l => '[${l.map((e) => teksNilaiAcuan(e) ?? 'null').join(', ')}]',
  _ => jsonEncode(nilai),
};

/// Satu sel terpilih di grid.
typedef SelTerpilihAcuan = ({String kunci, String kolom});

/// Urutan TAMPIL baris.
///
/// Isi kanonik menyimpan kunci peta terurut TEKS (`1.0`, `100.0`, `101.6`,
/// `11.0`, …) — benar untuk sha256, membingungkan untuk dibaca. Lembar
/// berjenis `baris` yang SEMUA kuncinya angka diurutkan numerik; selain itu
/// urutan isi dipertahankan (urutan `daftar` itu posisi, dan posisi bermakna).
/// Kunci dan nilainya tidak disentuh — cuma urutannya.
List<MapEntry<String, Map<String, Object?>>> urutBarisTampilAcuan(
  LembarSkemaAcuan lembar,
  Map<String, Map<String, Object?>> baris,
) {
  final entri = baris.entries.toList();
  if (lembar.jenis != JenisLembarAcuan.baris) return entri;

  final angka = [for (final e in entri) double.tryParse(e.key)];
  if (angka.any((a) => a == null || !a.isFinite)) return entri;

  final urutan = List<int>.generate(entri.length, (i) => i)
    ..sort((a, b) {
      final banding = angka[a]!.compareTo(angka[b]!);
      return banding != 0 ? banding : a.compareTo(b);
    });

  return [for (final i in urutan) entri[i]];
}

bool _tipeAngka(String tipe) => tipe == 'desimal' || tipe == 'bulat';

/// Kolom yang angkanya ditulis huruf angka (IBM Plex Mono).
bool _pakaiMono(KolomSkemaAcuan? kolom, Object? nilai) =>
    nilai is num ||
    nilai is List ||
    kolom == null ||
    _tipeAngka(kolom.tipe) ||
    kolom.tipe == 'daftar_angka' ||
    kolom.tipe == 'tanggal';

TextStyle _gayaMono(SidikMaterial m) =>
    SidikTheme.gayaAngka(ukuran: 14, berat: FontWeight.w500, warna: m.tinta);

TextStyle _gayaTeks(ThemeData theme, SidikMaterial m) =>
    (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
      color: m.tinta,
    );

TextStyle _gayaKepala(ThemeData theme, SidikMaterial m) =>
    (theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14)).copyWith(
      color: m.tinta,
      fontWeight: FontWeight.w600,
    );

TextStyle _gayaSatuan(SidikMaterial m) =>
    SidikTheme.gayaAngka(ukuran: 12, berat: FontWeight.w400, warna: m.tinta2);

/// Isi satu sel: nilai persis, "kosong" untuk `null`, `—` untuk sel yang
/// tidak ada di isi versi ini.
class TeksSelAcuan extends StatelessWidget {
  const TeksSelAcuan({
    super.key,
    required this.ada,
    required this.nilai,
    this.kolom,
    this.rataKanan = false,
    this.ukuran,
  });

  final bool ada;
  final Object? nilai;
  final KolomSkemaAcuan? kolom;
  final bool rataKanan;

  /// Ukuran huruf; `null` = ukuran sel grid.
  final double? ukuran;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final rata = rataKanan ? TextAlign.right : TextAlign.left;

    if (!ada) {
      return Semantics(
        label: l10n.acuanSelTidakAda,
        excludeSemantics: true,
        child: Text(
          '—',
          textAlign: rata,
          style: TextStyle(color: m.tinta2),
        ),
      );
    }

    final teks = teksNilaiAcuan(nilai);
    if (teks == null) {
      return Text(
        l10n.acuanNilaiKosong,
        textAlign: rata,
        style: _gayaTeks(theme, m).copyWith(
          color: m.tinta2,
          fontStyle: FontStyle.italic,
          fontSize: ukuran,
        ),
      );
    }

    final gaya = _pakaiMono(kolom, nilai) ? _gayaMono(m) : _gayaTeks(theme, m);
    return Text(
      teks,
      textAlign: rata,
      softWrap: true,
      style: ukuran == null ? gaya : gaya.copyWith(fontSize: ukuran),
    );
  }
}

/// Grid satu lembar. Lembar `objek` berbaris tunggal digambar MEMANJANG
/// (label · nilai · asal per kolom, seperti tab Konstanta di rancangan);
/// lainnya tabel berkepala lengket.
class GridAcuan extends StatelessWidget {
  const GridAcuan({
    super.key,
    required this.lembar,
    required this.baris,
    required this.onTapSel,
    this.terpilih,
  });

  final LembarSkemaAcuan lembar;

  /// Sudah dalam urutan tampil ([urutBarisTampilAcuan]).
  final List<MapEntry<String, Map<String, Object?>>> baris;

  final void Function(String kunci, KolomSkemaAcuan kolom) onTapSel;
  final SelTerpilihAcuan? terpilih;

  @override
  Widget build(BuildContext context) {
    // Latar KERTAS, bukan meja: grid ini lembar yang dibaca (lihat
    // `sidik_permukaan.dart` — kertas = membaca & mengisi).
    return ColoredBox(
      color: SidikMaterial.of(context).kertas,
      child: lembar.jenis == JenisLembarAcuan.objek && baris.length == 1
          ? _ObjekMemanjang(
              lembar: lembar,
              kunci: baris.single.key,
              sel: baris.single.value,
              onTapSel: onTapSel,
              terpilih: terpilih,
            )
          : _TabelAcuan(
              lembar: lembar,
              baris: baris,
              onTapSel: onTapSel,
              terpilih: terpilih,
            ),
    );
  }
}

class _ObjekMemanjang extends StatelessWidget {
  const _ObjekMemanjang({
    required this.lembar,
    required this.kunci,
    required this.sel,
    required this.onTapSel,
    this.terpilih,
  });

  final LembarSkemaAcuan lembar;
  final String kunci;
  final Map<String, Object?> sel;
  final void Function(String kunci, KolomSkemaAcuan kolom) onTapSel;
  final SelTerpilihAcuan? terpilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, batas) {
        // Di bawah ini label & nilai ditumpuk: dua kolom berdampingan di HP
        // 360dp memaksa angka panjang patah di tengah digit.
        final sempit = batas.maxWidth < 520;

        return ListView.separated(
          itemCount: lembar.kolom.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, thickness: 1, color: m.garis),
          itemBuilder: (context, i) {
            final kolom = lembar.kolom[i];
            final dipilih =
                terpilih?.kunci == kunci && terpilih?.kolom == kolom.kode;
            final keterangan = [?kolom.satuan, ?kolom.asal].join(' · ');

            final kepala = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(kolom.label, style: _gayaKepala(theme, m)),
                    ),
                    if (kolom.perluKonfirmasi) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _TandaKonfirmasi(m: m, l10n: l10n),
                    ],
                  ],
                ),
                if (keterangan.isNotEmpty)
                  Text(keterangan, style: _gayaSatuan(m)),
              ],
            );
            final nilai = TeksSelAcuan(
              ada: sel.containsKey(kolom.kode),
              nilai: sel[kolom.kode],
              kolom: kolom,
              rataKanan: !sempit,
            );

            return Material(
              color: dipilih
                  ? m.biruTipis
                  : kolom.perluKonfirmasi
                  ? m.awasTipis.withValues(alpha: 0.45)
                  : Colors.transparent,
              child: InkWell(
                onTap: () => onTapSel(kunci, kolom),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: sempit
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [kepala, const SizedBox(height: 6), nilai],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 5, child: kepala),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(flex: 5, child: nilai),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TandaKonfirmasi extends StatelessWidget {
  const _TandaKonfirmasi({required this.m, required this.l10n});

  final SidikMaterial m;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: l10n.acuanPerluKonfirmasi,
    child: Semantics(
      label: l10n.acuanPerluKonfirmasi,
      child: Icon(Icons.flag_outlined, size: 16, color: m.awas),
    ),
  );
}

/// Satu kolom tabel. [def] `null` = kolom kunci baris buatan (lembar tanpa
/// kolom kunci di skema, mis. daftar berposisi `0`, `1:3`).
class _Kolom {
  const _Kolom(this.def, this.lebar);

  final KolomSkemaAcuan? def;
  final double lebar;
}

class _TabelAcuan extends StatefulWidget {
  const _TabelAcuan({
    required this.lembar,
    required this.baris,
    required this.onTapSel,
    this.terpilih,
  });

  final LembarSkemaAcuan lembar;
  final List<MapEntry<String, Map<String, Object?>>> baris;
  final void Function(String kunci, KolomSkemaAcuan kolom) onTapSel;
  final SelTerpilihAcuan? terpilih;

  @override
  State<_TabelAcuan> createState() => _TabelAcuanState();
}

class _TabelAcuanState extends State<_TabelAcuan> {
  static const _padH = 12.0;
  static const _lebarLabelMaks = 180.0;
  static const _lebarIsiMaks = 320.0;

  /// Baris yang diukur untuk lebar kolom. Di atas ini lebarnya sudah stabil,
  /// dan sel yang lebih lebar membungkus (tidak terpotong).
  static const _barisDiukurMaks = 1500;

  final _horizontal = ScrollController();
  final _vertikal = ScrollController();

  List<_Kolom>? _kolom;
  Object? _kunciUkur;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertikal.dispose();
    super.dispose();
  }

  static double _lebar(String teks, TextStyle gaya, TextScaler skala) {
    final tp = TextPainter(
      text: TextSpan(text: teks, style: gaya),
      textDirection: TextDirection.ltr,
      textScaler: skala,
      maxLines: 1,
    )..layout();
    final lebar = tp.width;
    tp.dispose();
    return lebar;
  }

  List<_Kolom> _ukurKolom(BuildContext context) {
    final skala = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    final kunci = (widget.lembar, widget.baris, skala, theme.brightness);
    if (_kolom != null && _kunciUkur == kunci) return _kolom!;

    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final mono = _gayaMono(m);
    final teks = _gayaTeks(theme, m);
    final kepala = _gayaKepala(theme, m);
    final satuan = _gayaSatuan(m);
    final diukur = widget.baris.take(_barisDiukurMaks).toList();

    final kolom = <_Kolom>[];

    if (widget.lembar.kunci == null) {
      var lebar = _lebar(l10n.acuanKolomKunci, kepala, skala);
      for (final b in diukur) {
        lebar = math.max(lebar, _lebar(b.key, mono, skala));
      }
      kolom.add(_Kolom(null, (lebar + 2 * _padH).clamp(56.0, 200.0)));
    }

    for (final def in widget.lembar.kolom) {
      var lebarKepala = math.min(
        _lebar(def.label, kepala, skala),
        _lebarLabelMaks,
      );
      if (def.perluKonfirmasi) lebarKepala += 20;
      if (def.satuan != null) {
        lebarKepala = math.max(lebarKepala, _lebar(def.satuan!, satuan, skala));
      }

      var lebarIsi = 0.0;
      for (final b in diukur) {
        final sel = b.value;
        final String isi;
        final TextStyle gaya;
        if (!sel.containsKey(def.kode)) {
          isi = '—';
          gaya = teks;
        } else if (sel[def.kode] == null) {
          isi = l10n.acuanNilaiKosong;
          gaya = teks;
        } else {
          isi = teksNilaiAcuan(sel[def.kode])!;
          gaya = _pakaiMono(def, sel[def.kode]) ? mono : teks;
        }
        lebarIsi = math.max(lebarIsi, _lebar(isi, gaya, skala));
        if (lebarIsi >= _lebarIsiMaks) break;
      }

      final lebar =
          math.max(lebarKepala, math.min(lebarIsi, _lebarIsiMaks)) +
          2 * _padH +
          // Pembulatan subpiksel TextPainter: tanpa ruang ini angka terpanjang
          // bisa turun baris sendiri.
          2;
      kolom.add(_Kolom(def, lebar.clamp(72.0, _lebarIsiMaks + 2 * _padH + 2)));
    }

    _kolom = kolom;
    _kunciUkur = kunci;
    return kolom;
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final kolom = _ukurKolom(context);
    final lebarTotal = kolom.fold<double>(0, (s, k) => s + k.lebar);

    return LayoutBuilder(
      builder: (context, batas) {
        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(lebarTotal, batas.maxWidth),
              height: batas.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kepala di LUAR daftar vertikal = lengket waktu digulir ke
                  // bawah, dan ikut bergeser waktu digulir ke samping.
                  _KepalaTabel(kolom: kolom, lebar: lebarTotal),
                  Divider(height: 1, thickness: 1, color: m.kertasTepi),
                  Expanded(
                    child: SizedBox(
                      width: lebarTotal,
                      child: Scrollbar(
                        controller: _vertikal,
                        child: ListView.builder(
                          controller: _vertikal,
                          itemCount: widget.baris.length,
                          itemBuilder: (context, i) => _BarisTabel(
                            kunci: widget.baris[i].key,
                            sel: widget.baris[i].value,
                            kolom: kolom,
                            onTapSel: widget.onTapSel,
                            terpilih: widget.terpilih,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KepalaTabel extends StatelessWidget {
  const _KepalaTabel({required this.kolom, required this.lebar});

  final List<_Kolom> kolom;
  final double lebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: lebar,
      color: m.kertas2,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final k in kolom)
              SizedBox(
                width: k.lebar,
                child: _selKepala(k.def, theme, m, l10n),
              ),
          ],
        ),
      ),
    );
  }

  Widget _selKepala(
    KolomSkemaAcuan? def,
    ThemeData theme,
    SidikMaterial m,
    AppLocalizations l10n,
  ) {
    final kanan = def != null && _tipeAngka(def.tipe);
    final isi = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: _TabelAcuanState._padH,
        vertical: AppSpacing.sm,
      ),
      alignment: kanan ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: kanan
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  def?.label ?? l10n.acuanKolomKunci,
                  maxLines: 3,
                  textAlign: kanan ? TextAlign.right : TextAlign.left,
                  style: _gayaKepala(theme, m),
                ),
              ),
              if (def?.perluKonfirmasi ?? false) ...[
                const SizedBox(width: AppSpacing.xs),
                _TandaKonfirmasi(m: m, l10n: l10n),
              ],
            ],
          ),
          if (def?.satuan != null) Text(def!.satuan!, style: _gayaSatuan(m)),
        ],
      ),
    );

    final asal = def?.asal;
    if (asal == null) return isi;
    return Tooltip(message: '${l10n.acuanSelAsal}: $asal', child: isi);
  }
}

class _BarisTabel extends StatelessWidget {
  const _BarisTabel({
    required this.kunci,
    required this.sel,
    required this.kolom,
    required this.onTapSel,
    this.terpilih,
  });

  final String kunci;
  final Map<String, Object?> sel;
  final List<_Kolom> kolom;
  final void Function(String kunci, KolomSkemaAcuan kolom) onTapSel;
  final SelTerpilihAcuan? terpilih;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: m.garis)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final k in kolom)
              SizedBox(width: k.lebar, child: _sel(k.def, m)),
          ],
        ),
      ),
    );
  }

  Widget _sel(KolomSkemaAcuan? def, SidikMaterial m) {
    const padding = EdgeInsets.symmetric(
      horizontal: _TabelAcuanState._padH,
      vertical: AppSpacing.sm,
    );

    if (def == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: padding,
        alignment: Alignment.centerLeft,
        child: Text(
          kunci,
          style: SidikTheme.gayaAngka(
            ukuran: 13,
            berat: FontWeight.w400,
            warna: m.tinta2,
          ),
        ),
      );
    }

    final kanan = _tipeAngka(def.tipe);
    final dipilih = terpilih?.kunci == kunci && terpilih?.kolom == def.kode;

    return Material(
      color: dipilih
          ? m.biruTipis
          : def.perluKonfirmasi
          ? m.awasTipis.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onTapSel(kunci, def),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: padding,
          alignment: kanan ? Alignment.centerRight : Alignment.centerLeft,
          child: TeksSelAcuan(
            ada: sel.containsKey(def.kode),
            nilai: sel[def.kode],
            kolom: def,
            rataKanan: kanan,
          ),
        ),
      ),
    );
  }
}
