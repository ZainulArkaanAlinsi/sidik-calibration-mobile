import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/titik_sesi.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Salinan lokal (draf di HP) dipulihkan ketika set titik ukur sesi di SERVER
/// sudah berubah sejak salinan ditulis: gerbang "wajib dicek" harus mengikuti
/// ISI sel yang berpindah baris, bukan kunci lamanya.
///
/// ## Bug yang ditutup
///
/// Timer = lembar berpasangan: kunci baris = POSISI. Server membuang nominal 60
/// (baris pertama) -> `pulihkanSalinanLokal` memindahkan ISI sel lewat
/// `petaKunciDraf`, tetapi catatan gerbang (`cek_bacaan`) dipulihkan apa adanya
/// di kunci lama. Hasilnya: sel yang bergeser tampak "sudah dicek" tanpa aksi
/// teknisi (isi awal tebakan mesin tertinggal di kunci lama), dan tanda sel
/// kamera di baris terakhir menggantung di sel kosong.
/// Alamat sel menurut NOMINAL barisnya (bukan posisi).
typedef Alamat = (String tabel, double nominal, String kolom, int ulang);

void main() {
  const nominalTimer = [60, 300, 600, 900, 1800, 2400, 3600, 120, 180, 240];

  Map<String, dynamic> batasTimer() => {
    'didukung': true,
    'alasan': null,
    'tabel': [
      {
        'kode': 'utama',
        'judul': 'Set point',
        'min': 1,
        'maks': 10,
        'boleh_tambah': true,
        'boleh_nonaktif': true,
        'alasan_tambah': null,
        'alasan_nonaktif': null,
        'nominal': 'saran',
        'bawaan': nominalTimer,
        'fase': ['sesudah'],
        'satuan': 's',
        'pengulangan': {'min': 2, 'maks': 10, 'bawaan': 3},
      },
    ],
  };

  List<Map<String, dynamic>> bawaanTimer() => [
    for (var i = 0; i < nominalTimer.length; i++)
      {
        'id': 'profil-utama-${i + 1}',
        'tabel': 'utama',
        'nominal': nominalTimer[i],
        'satuan': 's',
        'fase': ['sesudah'],
        'aktif': true,
        'asal': 'profil',
        'alasan': null,
        'justifikasi_cmc': null,
        'tambahan': false,
      },
  ];

  Map<String, dynamic> bentukTimer() {
    final m =
        jsonDecode(
              File(
                'test/fixtures/lembar-kerja-timer_stopwatch.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    m['batas_titik'] = batasTimer();
    m['titik_sesi_bawaan'] = bawaanTimer();

    return m;
  }

  const alat = EquipmentLookup(
    id: 7,
    namaAlat: 'Stopwatch Uji',
    serialNumber: 'SW-1',
    kategori: 'waktu',
    status: 'aktif',
    satuan: 's',
    rangeMax: 3600,
  );

  LembarKerjaState isianTimer() {
    final i = LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentukTimer()),
      clientRequestId: 'uji-pulih-titik-sesi',
    )..alat = alat;
    addTearDown(i.dispose);

    return i;
  }

  MetaTitikSesi meta(int revisi, {List<int> hilang = const []}) =>
      MetaTitikSesi.dariJson({
        'batas': batasTimer(),
        'set': {
          'revisi': revisi,
          'titik': [
            for (final p in bawaanTimer())
              if (!hilang.contains(p['nominal'])) p,
          ],
        },
        'di_luar_cmc': <String>[],
      })!;

  /// Isi tiap sel tabel yang berisi: alamat berbasis NOMINAL (bukan posisi) ->
  /// (isi, status gerbang). Status dicari lewat isi sel, yang unik per sel.
  Map<Alamat, ({String isi, StatusCekSel status})> petaSel(LembarKerjaState s) {
    final status = {for (final x in s.daftarSelCek()) x.teks: x.status};
    final hasil = <Alamat, ({String isi, StatusCekSel status})>{};

    for (final t in s.bentuk.bagian.expand((b) => b.tabel)) {
      final baris = s.barisTabel(t);
      for (var i = 0; i < baris.length; i++) {
        final st = s.titik[s.kunciBaris(baris, i, t)];
        if (st == null) continue;

        for (final k in t.kolom) {
          for (var r = 0; r < t.pengulangan.length; r++) {
            final isi = st.teksKotakJikaAda(t.kunciTabel, k.kode, r);
            if (isi == null || isi.trim().isEmpty) continue;

            hasil[(t.kunciTabel, baris[i].titikUkur, k.kode, r)] = (
              isi: isi,
              status: status[isi] ?? StatusCekSel.tanpaTanda,
            );
          }
        }
      }
    }

    return hasil;
  }

  /// Foto mengisi empat baris pertama tiap tabel; teks unik per sel.
  int isiDariFoto(LembarKerjaState s) {
    final semua = [for (final b in s.bentuk.bagian) ...b.tabel];
    String idTabel(TabelHasil t) {
      final dasar = t.grup ?? t.tahap;
      final kembar =
          semua.where((o) => (o.grup ?? o.tahap) == dasar).length > 1;

      return kembar ? '${dasar}_${t.tahap}' : dasar;
    }

    var n = 0;
    final sel =
        <
          ({
            String tabelId,
            String? tahap,
            int barisKe,
            int repeatNo,
            String fieldId,
            String teks,
            double? keyakinan,
          })
        >[];
    for (final t in semua) {
      for (var i = 0; i < 4; i++) {
        sel.add((
          tabelId: idTabel(t),
          tahap: t.tahap,
          barisKe: i + 1,
          repeatNo: t.pengulangan.first,
          fieldId: t.kolom.first.kode,
          teks: '${1 + n++}',
          keyakinan: 0.99,
        ));
      }
    }

    return s.terapkanHasilFotoAsli(sel);
  }

  Map<String, dynamic> salinanDari(LembarKerjaState s) =>
      jsonDecode(jsonEncode(s.salinanLokal())) as Map<String, dynamic>;

  group('Timer: pulihkan salinan lokal, server membuang titik pertama', () {
    test('status & isi sel mengikuti NOMINAL, sel nominal 60 hilang', () {
      final lama = isianTimer()..muatTitikSesi(meta(2));
      final masuk = isiDariFoto(lama);
      expect(masuk, greaterThan(0), reason: 'prasyarat: foto mendarat');

      // Satu sel DIKONFIRMASI teknisi sebelum salinan ditulis (nominal 300,
      // yang masih ada sesudah server membuang 60).
      final sebelumKonfirmasi = petaSel(lama);
      final tigaRatus = sebelumKonfirmasi.entries
          .firstWhere((e) => e.key.$2 == 300)
          .value
          .isi;
      lama.konfirmasiSelCek(
        lama.daftarSelCek().firstWhere((x) => x.teks == tigaRatus).kunci,
      );

      final sebelum = petaSel(lama);
      expect(
        sebelum.values.map((x) => x.status).toSet(),
        {StatusCekSel.perluCek, StatusCekSel.sudahDicek},
        reason: 'prasyarat: ada sel yang dikonfirmasi dan sel yang belum',
      );
      expect(sebelum.keys.any((a) => a.$2 == 60), isTrue);

      final baru = isianTimer()..muatTitikSesi(meta(5, hilang: [60]));
      baru.pulihkanSalinanLokal(salinanDari(lama));
      final sesudah = petaSel(baru);

      expect(baru.titikBerlaku, isNot(contains(60.0)));

      // Sel nominal 60 hilang bersama barisnya.
      expect(
        sesudah.keys.where((a) => a.$2 == 60),
        isEmpty,
        reason: 'baris nominal 60 sudah dibuang server',
      );

      // Sel lain: isi sama, status sama — bergeser menurut nominal.
      for (final e in sebelum.entries.where((e) => e.key.$2 != 60)) {
        final x = sesudah[e.key];
        expect(x, isNotNull, reason: '${e.key} harus ikut pindah');
        expect(x!.isi, e.value.isi, reason: '${e.key}: isi');
        expect(
          x.status,
          e.value.status,
          reason:
              '${e.key}: status tidak boleh berubah tanpa aksi teknisi '
              '(isi awal tebakan mesin harus ikut pindah)',
        );
      }

      // Tidak ada sel berisi yang lolos tanpa tanda, tidak ada tanda hantu.
      expect(
        sesudah.values.where((x) => x.status == StatusCekSel.tanpaTanda),
        isEmpty,
        reason: 'semua sel yang berisi tadinya hasil kamera',
      );
      expect(
        baru.daftarSelCek().length,
        sesudah.length,
        reason: 'gerbang = sel kamera yang masih berisi',
      );
      expect(
        baru.jumlahPerluCek,
        sesudah.values.where((x) => x.status == StatusCekSel.perluCek).length,
      );
      final kunci = baru.daftarSelCek().map((x) => x.kunci).toList();
      expect(kunci.toSet().length, kunci.length);
    });

    test('ketikan tangan di sel yang bergeser tidak ikut digerbang', () {
      final lama = isianTimer()..muatTitikSesi(meta(2));
      isiDariFoto(lama);

      // Baris KELIMA (nominal 1800) diketik tangan; foto hanya sampai baris 4.
      final tabel = lama.bentuk.bagian.expand((b) => b.tabel).first;
      final baris = lama.barisTabel(tabel);
      lama.titik[lama.kunciBaris(baris, 4, tabel)]!
              .kotak(tabel.kunciTabel, tabel.kolom.first.kode, 0)
              .text =
          '99,9';
      final sebelum = petaSel(lama);
      expect(
        sebelum.entries.where((e) => e.value.isi == '99,9').single.value.status,
        StatusCekSel.tanpaTanda,
        reason: 'prasyarat: ketikan tangan tidak digerbang',
      );

      final baru = isianTimer()..muatTitikSesi(meta(5, hilang: [60]));
      baru.pulihkanSalinanLokal(salinanDari(lama));
      final sesudah = petaSel(baru);

      final tangan = sesudah.entries.where((e) => e.value.isi == '99,9');
      expect(tangan, hasLength(1));
      expect(tangan.single.key.$2, 1800, reason: 'ikut nominalnya');
      expect(tangan.single.value.status, StatusCekSel.tanpaTanda);
      expect(baru.daftarSelCek().map((x) => x.teks), isNot(contains('99,9')));
    });
  });
}
