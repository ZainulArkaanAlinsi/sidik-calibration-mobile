import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_waktu.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Lembar kelompok **Waktu dan Frekuensi** (alat ke-22..24) di HP.
///
/// Ketiganya bentuk baru buat aplikasi, dan satu di antaranya — Timer/Stopwatch
/// — bentuk yang belum pernah ada sama sekali: satu ulangan ditulis di EMPAT
/// kotak (`J | M | S | 0.001S`), bukan satu.
///
/// Angka acuannya disalin dari `docs/perintah-frontend-waktu-frekuensi.md` §9,
/// yang sendirinya disalin dari sel workbook master lab. Jadi kalau nilai di
/// sini bergeser, yang bergerak bukan cuma layar — kontraknya ikut.
void main() {
  LembarKerja bentuk(String kode) => LembarKerja.fromJson(
    jsonDecode(File('test/fixtures/lembar-kerja-$kode.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  List<TabelHasil> tabelDari(LembarKerja b) => [
    for (final bagian in b.bagian) ...bagian.tabel,
  ];

  group('bentuk dari server kebaca', () {
    test('Timer lembar PASANGAN, dan kedua tabelnya berkunci sel BEDA', () {
      final b = bentuk('timer_stopwatch');
      final tabel = tabelDari(b);

      expect(
        b.berpasangan,
        isTrue,
        reason:
            'Tanpa `peran`, `LembarKerja.berpasangan` false dan payload-nya '
            'jatuh ke bentuk datar `pembacaan` — seluruh isian lembar ini '
            'berangkat sebagai titik tanpa satu pun deret.',
      );

      expect(tabel, hasLength(2));
      expect(tabel.where((t) => t.deretStandar), hasLength(1));
      expect(tabel.where((t) => t.deretUut), hasLength(1));

      // Kunci sel WAJIB beda. Keduanya `tahap: sesudah_adjustment`, jadi yang
      // memisahkan cuma `grup`. Kalau kembar, teknisi mengetik di tabel bawah
      // dan angkanya muncul di tabel atas — tanpa satu pun error.
      final kunci = tabel.map((t) => t.kunciTabel).toList();
      expect(
        kunci.toSet(),
        hasLength(2),
        reason: 'Kedua tabel Timer berbagi kunci sel: $kunci',
      );
      expect(kunci, ['waktu_standar', 'waktu_uut']);
    });

    test('tiap ulangan Timer punya EMPAT kotak, urut J M S ms', () {
      for (final t in tabelDari(bentuk('timer_stopwatch'))) {
        expect(
          [for (final k in t.kolom) k.kode],
          ['jam', 'menit', 'detik', 'milidetik'],
          reason:
              'Urutan kotak menentukan apa yang diketik teknisi di mana. '
              'Satu kolom kegeser bikin menit terbaca sebagai jam — waktunya '
              'meleset enam puluh kali, dan angkanya tetap kelihatan wajar.',
        );
        expect(t.pengulangan, [1, 2, 3]);
      }
    });

    test('dua alat rpm tabel datar biasa, satu kolom lima ulangan', () {
      for (final kode in ['centrifuge', 'tachometer']) {
        final b = bentuk(kode);
        final tabel = tabelDari(b);

        expect(b.berpasangan, isFalse, reason: '$kode bukan lembar pasangan');
        expect(tabel, hasLength(1), reason: kode);
        expect([for (final k in tabel.first.kolom) k.kode], ['pembacaan']);
        expect(tabel.first.pengulangan, [1, 2, 3, 4, 5], reason: kode);
      }
    });

    test('ketiganya titik bisa diubah teknisi', () {
      for (final kode in ['timer_stopwatch', 'centrifuge', 'tachometer']) {
        for (final t in tabelDari(bentuk(kode))) {
          expect(
            t.titikBisaDiubah,
            isTrue,
            reason:
                '$kode: set point ditentukan alat pelanggan, jadi baris '
                'dari server cuma SARAN.',
          );
        }
      }
    });
  });

  group('payload Timer', () {
    /// Satu titik penuh, angkanya persis contoh §5 dokumen serah-terima.
    test('empat kotak jadi objek J/M/S/ms, bukan angka datar', () {
      final b = bentuk('timer_stopwatch');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final uut = tabel.firstWhere((t) => t.deretUut);

      final baris = state.barisTabel(standar);
      final titik = state.titik[state.kunciBaris(baris, 0, standar)]!;

      // Set point 1 menit = 60 detik — titik pertama sesi master 015-CAL-424.
      expect(titik.titikUkur, 60.0);

      const ms = {
        'waktu_standar': [123, 211, 45],
        'waktu_uut': [131, 219, 61],
      };

      for (final t in [standar, uut]) {
        for (var r = 0; r < 3; r++) {
          titik.kotak(t.kunciTabel, 'jam', r).text = '0';
          titik.kotak(t.kunciTabel, 'menit', r).text = '1';
          titik.kotak(t.kunciTabel, 'detik', r).text = '0';
          titik.kotak(t.kunciTabel, 'milidetik', r).text =
              '${ms[t.kunciTabel]![r]}';
        }
      }

      final deret = state.deretPasangan(titik.parameter)!;
      final payload = titik.toSubmissionPasangan(deret);

      expect(payload['titik_ukur'], 60.0);

      expect(payload['standar'], [
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 123.0},
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 211.0},
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 45.0},
      ]);

      expect(payload['uut'], [
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 131.0},
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 219.0},
        {'jam': 0.0, 'menit': 1.0, 'detik': 0.0, 'milidetik': 61.0},
      ]);
    });

    /// Ulangan yang keempat kotaknya kosong dikirim `null`, BUKAN objek kosong.
    ///
    /// Dua alasannya sama-sama mengikat. Posisinya harus tetap — kalau ulangan
    /// 2 dibuang, ulangan 3 naik jadi 2 dan seluruh nomornya geser. Dan aturan
    /// `PenunjukanWaktu` di server MENOLAK objek yang keempat kotaknya kosong,
    /// jadi objek kosong bikin lembar setengah jadi kena 422 di ulangan yang
    /// memang sengaja dilewati.
    test('ulangan kosong jadi null di posisinya, bukan objek kosong', () {
      final b = bentuk('timer_stopwatch');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final standar = tabelDari(b).firstWhere((t) => t.deretStandar);
      final titik =
          state.titik[state.kunciBaris(state.barisTabel(standar), 0, standar)]!;

      // Ulangan 2 sengaja dilewati seluruhnya.
      for (final r in [0, 2]) {
        titik.kotak(standar.kunciTabel, 'menit', r).text = '1';
        titik.kotak(standar.kunciTabel, 'milidetik', r).text = '${100 + r}';
      }

      final payload = titik.toSubmissionPasangan(
        state.deretPasangan(titik.parameter)!,
      );

      expect(payload['standar'], [
        {'menit': 1.0, 'milidetik': 100.0},
        null,
        {'menit': 1.0, 'milidetik': 102.0},
      ]);
    });

    test('kotak yang sebagian diisi tetap terkirim apa adanya', () {
      final b = bentuk('timer_stopwatch');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final standar = tabelDari(b).firstWhere((t) => t.deretStandar);
      final titik =
          state.titik[state.kunciBaris(state.barisTabel(standar), 0, standar)]!;

      // Cuma milidetik yang diketik — J/M/S dibiarkan kosong. Server yang
      // memperlakukan kotak kosong sebagai nol di `WaktuMentah::keMilidetik`,
      // dan itu SAH: nol jam nol menit nol detik memang nol.
      titik.kotak(standar.kunciTabel, 'milidetik', 0).text = '60123';

      final payload = titik.toSubmissionPasangan(
        state.deretPasangan(titik.parameter)!,
      );

      expect((payload['standar'] as List).first, {'milidetik': 60123.0});
    });
  });

  group('payload dua alat rpm', () {
    test('deret datar biasa, lima pembacaan per set point', () {
      for (final kode in ['centrifuge', 'tachometer']) {
        final b = bentuk(kode);
        final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
        final tabel = tabelDari(b).first;
        final baris = state.barisTabel(tabel);
        final titik = state.titik[state.kunciBaris(baris, 0, tabel)]!;

        // Titik 1 sesi master: set point 60 rpm, pembacaan standar
        // 59,9 60,0 60,0 60,0 60,0 — §9 dokumen serah-terima.
        expect(titik.titikUkur, 60.0, reason: kode);

        const bacaan = ['59.9', '60.0', '60.0', '60.0', '60.0'];
        for (var i = 0; i < 5; i++) {
          titik.kotak(tabel.kunciTabel, 'pembacaan', i).text = bacaan[i];
        }

        final payload = titik.toSubmission(
          kunciUtama: state.kunciTabelPembacaan,
        );

        expect(payload.titikUkur, 60.0, reason: kode);
        expect(
          payload.pembacaan,
          [59.9, 60.0, 60.0, 60.0, 60.0],
          reason:
              '$kode: kolom pembacaan itu bacaan TACHOMETER STANDAR, dan '
              'set point-nya penunjukan alat pelanggan. Ketuker, koreksinya '
              'berbalik tanda di sertifikat.',
        );
      }
    });
  });

  group('mode mock', () {
    test('bentuk mock SAMA PERSIS dengan fixture dari server', () {
      final peta = {
        'timer_stopwatch': contohBentukLembarKerjaTimer(),
        'centrifuge': contohBentukLembarKerjaCentrifuge(),
        'tachometer': contohBentukLembarKerjaTachometer(),
      };

      peta.forEach((kode, mock) {
        final dariServer =
            jsonDecode(
                  File(
                    'test/fixtures/lembar-kerja-$kode.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;

        expect(
          jsonDecode(jsonEncode(mock)),
          dariServer,
          reason:
              'Bentuk mock $kode menyimpang dari respons server. Mode mock '
              'yang bentuknya basi bikin test hijau di atas lembar yang nggak '
              'pernah dipakai siapa pun.',
        );
      });
    });

    test('ketiga profil dapat lembarnya sendiri, bukan jatuh ke pH', () async {
      final service = MockLembarKerjaService();

      for (final entri in {
        'timer_stopwatch': 'Stopwatch / Timer',
        'centrifuge': 'Centrifuge',
        'tachometer': 'Infrared Tachometer',
      }.entries) {
        final bentuk = await service.ambilBentuk('token', profil: entri.key);

        expect(
          bentuk.judul,
          contains(entri.value),
          reason:
              'Profil `${entri.key}` jatuh ke cabang bawaan dan mode mock '
              'memajang lembar pH — nggak ada error, cuma lembar yang salah.',
        );
      }
    });
  });
}
