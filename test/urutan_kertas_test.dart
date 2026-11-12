import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/urutan_kertas.dart';

void main() {
  SelTemplateAsli sel(
    String kunci,
    String tabel, {
    double? x,
    double? y,
    double h = 0.02,
  }) => SelTemplateAsli(
    kunci: kunci,
    tabelId: tabel,
    barisKe: 0,
    repeatNo: 0,
    fieldId: 'f',
    kotak: x == null ? null : KotakSel(x: x, y: y!, w: 0.08, h: h),
  );

  List<String> urut(List<SelTemplateAsli> s, List<String> tabel) {
    final p = urutanKertas(s, tabel);
    final kunci = p.keys.toList()..sort((a, b) => p[a]!.compareTo(p[b]!));

    return kunci;
  }

  test('baris demi baris dari atas, di dalam baris dari kiri', () {
    final s = [
      sel('b2k2', 't', x: 0.50, y: 0.30),
      sel('b1k1', 't', x: 0.20, y: 0.20),
      sel('b2k1', 't', x: 0.20, y: 0.30),
      sel('b1k2', 't', x: 0.50, y: 0.20),
    ];

    expect(urut(s, ['t']), ['b1k1', 'b1k2', 'b2k1', 'b2k2']);
  });

  test('sedikit goyang vertikal di satu baris tidak memecah baris', () {
    final s = [
      sel('a2', 't', x: 0.50, y: 0.2005),
      sel('a1', 't', x: 0.20, y: 0.2000),
      sel('a3', 't', x: 0.80, y: 0.1995),
      sel('b1', 't', x: 0.20, y: 0.2300),
    ];

    expect(urut(s, ['t']), ['a1', 'a2', 'a3', 'b1']);
  });

  test('urutan tabel mengikuti templat, bukan letak', () {
    final s = [
      sel('akhir', 'tabel_b', x: 0.1, y: 0.1),
      sel('awal', 'tabel_a', x: 0.1, y: 0.9),
    ];

    expect(urut(s, ['tabel_a', 'tabel_b']), ['awal', 'akhir']);
  });

  test(
    'tabel yang tidak disebut urutan tabel ikut di belakang; sel tanpa kotak terakhir',
    () {
      final s = [
        sel('liar', 'lain', x: 0.1, y: 0.1),
        sel('tanpa', 't'),
        sel('a', 't', x: 0.1, y: 0.5),
      ];

      expect(urut(s, ['t']), ['a', 'tanpa', 'liar']);
    },
  );

  test('semua sel dapat peringkat unik', () {
    final s = [
      for (var i = 0; i < 30; i++)
        sel('s$i', 't', x: (i % 5) * 0.15, y: (i ~/ 5) * 0.05),
    ];
    final p = urutanKertas(s, ['t']);

    expect(p.values.toSet().length, 30);
    expect(p['s0'], 0);
    expect(p['s29'], 29);
  });
}
