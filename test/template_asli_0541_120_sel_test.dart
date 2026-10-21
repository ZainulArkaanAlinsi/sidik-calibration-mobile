import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/aturan_formulir_asli.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show setelKolomPengulanganMock;

/// Formulir asli 0541 (Anak Timbangan) Rev.0 dengan TIGA pengulangan per
/// peran: 10 blok × Standard/UUT/UUT/Standard × X1–X3 = 120 sel. Sejak
/// 20 Okt 2026 server menyajikan bentuk ini untuk template kertas asli tanpa
/// `jumlah_pengulangan` (jp=1 tetap 40 sel). Yang dijaga di sini: tidak ada
/// angka 2/40/80 tersembunyi di parse, aturan nalar, alamat lembar, maupun
/// payload per peran — dan sel kosong tetap kosong (tidak jadi 0).
void main() {
  const peran = ['at_s1', 'at_t1', 'at_t2', 'at_s2'];
  const tahap = 'sesudah_adjustment';
  const resolusi = 0.00001;

  Map<String, dynamic> template120() => {
    'data': {
      'template_id': 'anak_timbangan',
      'kertas': 'asli',
      'versi': 1,
      'kode_dokumen': 'SIDIK-FM-CAL-0541',
      'revisi': '0',
      'judul': 'Calibration Work Sheet - Anak Timbangan',
      'jumlah_pengulangan': 3,
      'tabel': [
        for (final p in peran)
          {'tabel_id': p, 'tahap': tahap, 'grup': p, 'judul': p},
      ],
      'geometri': {
        'ukuran_referensi': {'w': 595, 'h': 842},
      },
      'sel': {
        for (final p in peran)
          for (var blok = 1; blok <= 10; blok++)
            for (var r = 1; r <= 3; r++)
              '$p|$blok|$r|pembacaan': {
                'kunci': '$p|$blok|$r|pembacaan',
                'tabel_id': p,
                'tahap': tahap,
                'grup': p,
                'baris_ke': blok,
                'repeat_no': r,
                'field_id': 'pembacaan',
                'aturan': {
                  'tipe': 'desimal',
                  'resolusi': resolusi,
                  'desimal': 5,
                },
                'kotak': {'x': 0.1, 'y': 0.1, 'w': 0.05, 'h': 0.02},
              },
      },
      'isian': <dynamic>[],
      'centang': <dynamic>[],
      'siap_pindai': true,
    },
  };

  LembarKerjaState lembar({required int pengulangan}) =>
      LembarKerjaState(
          bentuk: LembarKerja.fromJson(
            pengulangan == 1
                ? contohBentukLembarKerjaAnakTimbangan()
                : setelKolomPengulanganMock(
                    contohBentukLembarKerjaAnakTimbangan(),
                    pengulangan,
                  ),
          ),
          clientRequestId: 'uji-0541-120',
        )
        ..alat = const EquipmentLookup(
          id: 36,
          namaAlat: 'Anak Timbangan',
          serialNumber: 'DEMO-AT-001',
          kategori: 'massa',
          status: 'aktif',
          satuan: 'g',
          rangeMax: 500,
          resolusi: 0.00001,
        );

  test('parse: 120 sel, 30 per peran, Repeat 1..3 tiap blok', () {
    final t = WorksheetTemplate.fromJson(template120());

    expect(t.selAsli, hasLength(120));
    for (final p in peran) {
      final milik = t.selAsli.where((s) => s.tabelId == p).toList();
      expect(milik, hasLength(30), reason: p);
      for (var blok = 1; blok <= 10; blok++) {
        expect(
          milik.where((s) => s.barisKe == blok).map((s) => s.repeatNo).toSet(),
          {1, 2, 3},
          reason: '$p blok $blok',
        );
      }
    }
    expect(t.selAsli.first.aturan?.resolusi, resolusi);
  });

  test('lembar 3 pengulangan menyediakan kotak untuk ke-120 sel', () {
    final t = WorksheetTemplate.fromJson(template120());
    final isian = lembar(pengulangan: 3);

    final mendarat = t.selAsli.where(
      (s) => isian.alamatFotoAsliAda(
        s.tabelId,
        s.barisKe,
        s.repeatNo,
        tahap: s.tahap,
      ),
    );
    expect(mendarat, hasLength(120));
  });

  test('lembar bawaan (1 pengulangan) hanya menampung X1 = 40 sel', () {
    // Perilaku yang ada (bukan perubahan di sini): X2/X3 tidak punya kotak di
    // lembar 1 pengulangan, jadi tidak ikut review. Teknisi memilih 3
    // pengulangan di lembar supaya ketiganya mendarat.
    final t = WorksheetTemplate.fromJson(template120());
    final isian = lembar(pengulangan: 1);

    final mendarat = t.selAsli.where(
      (s) => isian.alamatFotoAsliAda(
        s.tabelId,
        s.barisKe,
        s.repeatNo,
        tahap: s.tahap,
      ),
    );
    expect(mendarat, hasLength(40));
    expect(mendarat.every((s) => s.repeatNo == 1), isTrue);
  });

  test(
    'aturan 0541 atas 120 sel: X3 kosong total diabaikan, sebagian merah',
    () {
      final t = WorksheetTemplate.fromJson(template120());

      String teks(SelTemplateAsli s) {
        // Blok 2: kolom X3 kosong total di keempat peran → tidak dipakai.
        if (s.barisKe == 2 && s.repeatNo == 3) return '';
        // Blok 3: kolom X2 putus (S1 kosong) → S1 X2 MERAH.
        if (s.barisKe == 3 && s.repeatNo == 2 && s.tabelId == 'at_s1') {
          return '';
        }
        return s.tabelId.startsWith('at_s') ? '49.99992' : '50.00012';
      }

      final putusan = AturanFormulirAsli.periksa([
        for (final s in t.selAsli)
          (
            kunci: s.kunci,
            tabelId: s.tabelId,
            barisKe: s.barisKe,
            repeatNo: s.repeatNo,
            teks: teks(s),
            gagalDibaca: false,
            resolusi: s.aturan?.resolusi,
            desimal: s.aturan?.desimal,
            teksNominal: '50',
          ),
      ]);

      expect(putusan.keys, ['at_s1|3|2|pembacaan']);
      expect(putusan['at_s1|3|2|pembacaan']!.vonis, VonisAturan.merah);
      expect(putusan['at_s1|3|2|pembacaan']!.alasan, {
        AlasanAturan.blokTidakLengkap,
      });

      // Merah = kosong & wajib diketik, bukan nol karangan.
      final usulan = AturanFormulirAsli.terapkan(
        VonisAturan.merah,
        teks: '',
        keyakinan: 0.9,
      );
      expect(usulan.teks, '');
    },
  );

  test('payload per peran membawa 3 pembacaan; kosong tetap null, bukan 0', () {
    final t = WorksheetTemplate.fromJson(template120());
    final isian = lembar(pengulangan: 3);

    // Nominal blok diketik teknisi (tidak dibaca dari foto).
    final hasil = isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil');
    final s1 = hasil.tabel.first;
    for (var i = 0; i < 10; i++) {
      isian.titikUntukBaris(isian.barisTabel(s1), i, s1)!.titikCtl.text = '50';
    }

    final disetujui = [
      for (final s in t.selAsli)
        // Blok 10 X3 peran T2 kosong di kertas → tidak ikut (bukan '0').
        if (!(s.barisKe == 10 && s.repeatNo == 3 && s.tabelId == 'at_t2'))
          (
            tabelId: s.tabelId,
            tahap: s.tahap,
            barisKe: s.barisKe,
            repeatNo: s.repeatNo,
            fieldId: s.fieldId,
            teks: '50.0000${s.repeatNo}',
            keyakinan: 0.95,
          ),
    ];

    expect(isian.terapkanHasilFotoAsli(disetujui), 119);

    final kirim = isian
        .toSubmission(draft: true)
        .measurements
        .map((m) => m.toJson())
        .where((m) => m.containsKey('at_s1'))
        .toList();

    expect(kirim, hasLength(10));
    for (final m in kirim) {
      for (final p in peran) {
        expect(m[p], hasLength(3), reason: '$p titik ${m['titik_ukur']}');
      }
    }
    expect(kirim.first['at_s1'], [50.00001, 50.00002, 50.00003]);
    expect(kirim.last['at_t2'], [50.00001, 50.00002, null]);
  });
}
