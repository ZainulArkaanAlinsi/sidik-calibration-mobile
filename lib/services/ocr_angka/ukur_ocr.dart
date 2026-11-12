import 'aturan_format_sel.dart';

/// Satu baris `labels.csv` (format rig `sidik-ocr-eval`): kolom wajib
/// `file,teks`; opsional `desimal`, `bertanda` (0/1).
class LabelUkur {
  const LabelUkur({
    required this.file,
    required this.teks,
    this.desimal,
    this.bertanda,
  });

  final String file;

  /// Nilai sebenarnya; kosong = sel memang kosong.
  final String teks;
  final int? desimal;
  final bool? bertanda;

  bool get berisi => teks.isNotEmpty;

  /// Aturan format untuk gerbang. `desimal` dari kolom, atau disimpulkan dari
  /// label bila sel berisi (sama dengan rig). Sel kosong tanpa kolom `desimal`
  /// memakai [desimalSelKosong]/[bertandaSelKosong] — SATU asumsi untuk semua
  /// sel kosong; isi kolom `desimal` per baris untuk pengukuran yang jujur.
  AturanFormatSel? aturan({
    int desimalSelKosong = 2,
    bool bertandaSelKosong = false,
  }) {
    var d = desimal;
    if (d == null || d < 0) {
      if (berisi) {
        final bagian = teks.replaceAll(',', '.').split('.');
        d = bagian.length > 1 ? bagian[1].length : 0;
      } else {
        d = desimalSelKosong;
      }
    }
    if (d > AturanFormatSel.desimalMaks) return null;

    return AturanFormatSel(
      desimal: d,
      // Kolom `bertanda` kosong: sel berisi boleh negatif (default rig), sel
      // kosong mengikuti asumsi.
      bolehNegatif: bertanda ?? (berisi || bertandaSelKosong),
    );
  }
}

/// Baca `labels.csv`. Mengerti kutip ganda (`"0,54"`), BOM, dan CRLF.
/// Baris tanpa kolom `file` diabaikan; kolom `file` dan `teks` WAJIB ada.
List<LabelUkur> bacaLabelsCsv(String isi) {
  final baris = _parseCsv(isi.startsWith('﻿') ? isi.substring(1) : isi);
  if (baris.isEmpty) return const [];

  final kepala = baris.first.map((k) => k.trim().toLowerCase()).toList();
  final iFile = kepala.indexOf('file');
  final iTeks = kepala.indexOf('teks');
  if (iFile < 0 || iTeks < 0) {
    throw const FormatException('labels.csv wajib punya kolom file dan teks');
  }
  final iDes = kepala.indexOf('desimal');
  final iTanda = kepala.indexOf('bertanda');

  String? sel(List<String> r, int i) =>
      i >= 0 && i < r.length ? r[i].trim() : null;

  return [
    for (final r in baris.skip(1))
      if ((sel(r, iFile) ?? '').isNotEmpty)
        LabelUkur(
          file: sel(r, iFile)!,
          teks: sel(r, iTeks) ?? '',
          desimal: int.tryParse(sel(r, iDes) ?? ''),
          bertanda: switch (sel(r, iTanda)) {
            '1' || 'true' => true,
            '0' || 'false' => false,
            _ => null,
          },
        ),
  ];
}

/// Hasil satu crop.
class HasilUkurSel {
  const HasilUkurSel({
    required this.label,
    required this.teks,
    required this.keyakinan,
    required this.dijawab,
    required this.status,
    required this.milidetik,
  });

  final LabelUkur label;

  /// Bacaan mentah mesin (sebelum diputuskan), apa adanya.
  final String teks;

  /// Skor mesin (`jalur`); `null` bila mesinnya tidak memberi skor (ML Kit).
  final double? keyakinan;

  /// Mesin MENJAWAB (jadi usulan). ML Kit: teks tidak kosong. Mesin angka:
  /// lolos ambang + gerbang format.
  final bool dijawab;

  /// Teks status (mis. `usulanKeyakinanTinggi`, `perluCek`, `kosong`, `galat`).
  final String status;
  final double milidetik;
}

/// Angka ringkas satu pengukuran — kolom sama dengan tabel di laporan rig
/// (`10-uji-mesin-angka.md`) supaya bisa dibandingkan; SEMUA tergantung pada
/// data yang diukur (sintetis atau foto nyata).
class RingkasanUkur {
  const RingkasanUkur({
    required this.jumlah,
    required this.berisi,
    required this.kosong,
    required this.dijawabBerisi,
    required this.benarDijawab,
    required this.benarSemuaBerisi,
    required this.isiPalsu,
    required this.latensiMedian,
    required this.latensiP95,
  });

  final int jumlah;
  final int berisi;
  final int kosong;
  final int dijawabBerisi;
  final int benarDijawab;
  final int benarSemuaBerisi;

  /// Sel kosong yang tetap dijawab.
  final int isiPalsu;
  final double latensiMedian;
  final double latensiP95;

  /// Porsi sel berisi yang dijawab.
  double? get cakupan => berisi == 0 ? null : dijawabBerisi / berisi;

  /// Benar di antara yang dijawab.
  double? get akurasiTerjawab =>
      dijawabBerisi == 0 ? null : benarDijawab / dijawabBerisi;

  /// Benar di antara SEMUA sel berisi (tanpa abstain).
  double? get exact => berisi == 0 ? null : benarSemuaBerisi / berisi;

  double? get isiPalsuPersen => kosong == 0 ? null : isiPalsu / kosong;
}

/// Nilai sama setelah koma dan titik dianggap sama (yang disimpan app adalah
/// angkanya) — definisi `exact` di rig.
bool samaNilai(String a, String b) =>
    a.replaceAll(',', '.') == b.replaceAll(',', '.');

RingkasanUkur ringkasUkur(List<HasilUkurSel> hasil) {
  final berisi = hasil.where((h) => h.label.berisi).toList();
  final kosong = hasil.where((h) => !h.label.berisi).toList();
  final dijawab = berisi.where((h) => h.dijawab).toList();
  final ms = hasil.map((h) => h.milidetik).toList()..sort();

  double persentil(double q) {
    if (ms.isEmpty) return 0;
    final pos = q * (ms.length - 1);
    final b = pos.floor();
    final a = pos.ceil();

    return ms[b] + (ms[a] - ms[b]) * (pos - b);
  }

  return RingkasanUkur(
    jumlah: hasil.length,
    berisi: berisi.length,
    kosong: kosong.length,
    dijawabBerisi: dijawab.length,
    benarDijawab: dijawab.where((h) => samaNilai(h.teks, h.label.teks)).length,
    benarSemuaBerisi: berisi
        .where((h) => samaNilai(h.teks, h.label.teks))
        .length,
    isiPalsu: kosong.where((h) => h.dijawab).length,
    latensiMedian: persentil(0.5),
    latensiP95: persentil(0.95),
  );
}

/// `hasil.csv`: tiga kolom pertama `file,teks,keyakinan` SAMA dengan CSV ML Kit
/// yang dibaca `muat_foto_nyata.py --mlkit` (keyakinan kosong bila tak ada
/// skor); kolom tambahan `status,ms` diabaikan skrip itu.
String hasilCsv(List<HasilUkurSel> hasil) {
  final b = StringBuffer('file,teks,keyakinan,status,ms\n');
  for (final h in hasil) {
    b
      ..write(_sel(h.label.file))
      ..write(',')
      ..write(_sel(h.teks))
      ..write(',')
      ..write(h.keyakinan == null ? '' : h.keyakinan!.toStringAsFixed(6))
      ..write(',')
      ..write(_sel(h.status))
      ..write(',')
      ..write(h.milidetik.toStringAsFixed(1))
      ..write('\n');
  }

  return b.toString();
}

String _sel(String v) =>
    v.contains(RegExp(r'[",\n\r]')) ? '"${v.replaceAll('"', '""')}"' : v;

/// Parser CSV kecil (RFC 4180): kutip ganda, `""` di dalam kutip, CRLF/LF.
List<List<String>> _parseCsv(String isi) {
  final baris = <List<String>>[];
  var sel = StringBuffer();
  var row = <String>[];
  var dalamKutip = false;

  void akhiriSel() {
    row.add(sel.toString());
    sel = StringBuffer();
  }

  void akhiriBaris() {
    akhiriSel();
    if (row.length > 1 || row.first.isNotEmpty) baris.add(row);
    row = <String>[];
  }

  for (var i = 0; i < isi.length; i++) {
    final c = isi[i];
    if (dalamKutip) {
      if (c == '"') {
        if (i + 1 < isi.length && isi[i + 1] == '"') {
          sel.write('"');
          i++;
        } else {
          dalamKutip = false;
        }
      } else {
        sel.write(c);
      }
    } else if (c == '"') {
      dalamKutip = true;
    } else if (c == ',') {
      akhiriSel();
    } else if (c == '\n') {
      akhiriBaris();
    } else if (c != '\r') {
      sel.write(c);
    }
  }
  if (sel.isNotEmpty || row.isNotEmpty) akhiriBaris();

  return baris;
}

/// Nilai terkecil untuk ringkasan teks: persen satu desimal atau "—".
String persenAtauStrip(double? v) =>
    v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
