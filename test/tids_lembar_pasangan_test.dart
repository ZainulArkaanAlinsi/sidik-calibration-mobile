import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// TIDS — Temperatur Indikator dengan Sensor — sesudah pindah ke jalur
/// PASANGAN (28 Agt 2026, bareng dua workbook master TIDS dari lab).
///
/// Bentuknya dibaca dari BERKAS SUNGGUHAN
/// (`test/fixtures/lembar-kerja-tids.json`), hasil `bentukLembarKerja()` di
/// server — bukan mock yang diketik ulang di sini. Alasannya sama dengan
/// `suhu_pasangan_lembar_kerja_test.dart`, dan buat lembar ini alasannya sudah
/// TERBUKTI mahal: sampai 27 Agt 2026 `MockLembarKerjaService` nggak punya
/// bentuk TIDS sama sekali dan diam-diam jatuh ke bentuk pH, jadi satu bug
/// bentuk TIDS lolos sampai lapangan tanpa satu pun test merah.
///
/// Empat hal yang dijaga, dan keempatnya gagal dengan cara yang DIAM:
///
///  1. **Deret standar nggak punya tempat simpan.** Sampai perubahan ini
///     `simpan_ke` tabel Pembacaan Standard `null` — 35 kotak yang diisi
///     teknisi di lapangan nggak pernah nyampe server, dan yang hilang justru
///     sisi KIRI kolom `Correction`.
///  2. **Lima kolom itu lima ULANGAN, bukan lima UUT.** Label cetaknya tetap
///     `UUT1`…`UUT5` (itu yang tertulis di kertas & jadi jangkar OCR), jadi
///     yang membedakan cuma `sumbu_uut.keputusan_skema`.
///  3. **Set point KOSONG.** Kertas TIDS nggak nyetak satu angka pun di kolom
///     Setpoint — tujuh baris kosong yang diisi teknisi. Baris ber-`titik_ukur`
///     null gampang bikin kunci baris tabrakan, dan tabrakan itu bikin tujuh
///     baris jadi satu tanpa error.
///  4. **Mode mock memajang lembar yang salah.** `MockLembarKerjaService`
///     sekarang punya bentuk TIDS-nya sendiri.
void main() {
  LembarKerja bentukDariFixture() => LembarKerja.fromJson(
    jsonDecode(File('test/fixtures/lembar-kerja-tids.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  List<TabelHasil> tabelDari(LembarKerja b) => [
    for (final bagian in b.bagian) ...bagian.tabel,
  ];

  group('bentuk dari server kebaca', () {
    test('TIDS lembar pasangan, dua tabel berperan standar & uut', () {
      final b = bentukDariFixture();
      final tabel = tabelDari(b);

      expect(b.berpasangan, isTrue, reason: 'Penjaga nomor 1.');
      expect(tabel, hasLength(2));
      expect(tabel.every((t) => t.berpasangan), isTrue);
      expect(tabel.where((t) => t.deretStandar), hasLength(1));
      expect(tabel.where((t) => t.deretUut), hasLength(1));

      // Kunci penyimpanan tiap tabel WAJIB unik. TIDS nggak mengirim `grup`,
      // jadi `kunciTabel` jatuh ke `peran` — dan itu tetap unik. Yang
      // dibedakan `tahap`-nya (`pembacaan_standard` / `pembacaan_uut`) cuma
      // dipakai di sisi server, buat kunci sel berkas geometri OCR yang
      // kertasnya sudah tercetak.
      final kunci = tabel.map((t) => t.kunciTabel).toList();
      expect(kunci, ['standar', 'uut']);
      expect(kunci.toSet(), hasLength(2));
      expect(tabel.map((t) => t.tahap), ['pembacaan_standard', 'pembacaan_uut']);
      expect(tabel.every((t) => t.grup == null), isTrue);

      for (final t in tabel) {
        expect(t.pengulangan, [1, 2, 3, 4, 5], reason: t.judul);
        expect(t.parameter, isNull, reason: 'TIDS bukan lembar dua-besaran.');
      }
    });

    test('deret standar akhirnya punya tempat simpan', () {
      final tabel = tabelDari(bentukDariFixture());

      expect(
        tabel.firstWhere((t) => t.deretStandar).simpanKe,
        'measurements[].standar',
        reason: 'Penjaga nomor 1: `null` di sini artinya 35 kotak yang diisi '
            'teknisi nggak pernah nyampe server, dan `Correction` terbit '
            'diadu ke nol.',
      );
      expect(
        tabel.firstWhere((t) => t.deretUut).simpanKe,
        'measurements[].uut',
      );
      expect(tabel.every((t) => t.tanpaTempatSimpan), isFalse);
    });

    test('kepala kolomnya tulisan yang TERCETAK, dan unik per tabel', () {
      final tabel = tabelDari(bentukDariFixture());
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final uut = tabel.firstWhere((t) => t.deretUut);

      // Jangkar sumbu mendatar jalur foto. TIDS nggak nyetak `Xn` maupun nomor
      // polos, jadi label ini satu-satunya yang dipunya.
      expect(standar.pengulanganArah.values, [
        '0" (UUT1)',
        '20" (UUT2)',
        '40" (UUT3)',
        '60" (UUT4)',
        '80" (UUT5)',
      ]);
      expect(uut.pengulanganArah.values, [
        '10" (UUT1)',
        '30" (UUT2)',
        '50" (UUT3)',
        '70" (UUT4)',
        '90" (UUT5)',
      ]);

      for (final t in [standar, uut]) {
        final label = t.pengulanganArah.values.toList();
        expect(label.toSet(), hasLength(label.length), reason: t.judul);
      }
    });

    test('kolom No. Termokopel cuma nempel di tabel STANDAR', () {
      final tabel = tabelDari(bentukDariFixture());

      final kolom = tabel.firstWhere((t) => t.deretStandar).kolomBaris;

      expect(
        kolom.map((f) => f.kode),
        ['no_probe'],
        reason: 'Nomornya nentuin kolom tabel koreksi — salah nomor bukan '
            'salah catatan, tapi salah koreksi.',
      );
      expect(tabel.firstWhere((t) => t.deretUut).kolomBaris, isEmpty);

      // Daftar pilihannya WAJIB berisi. `_BarisNoProbe` menggambar kolom ini
      // sebagai dropdown yang disaring `grup == tipe_sensor`; dikirim kosong,
      // dropdown-nya lahir tanpa satu pun pilihan dan lembarnya nggak bisa
      // diisi sama sekali — tanpa satu pun error.
      final pilihan = kolom.single.pilihan;
      expect(pilihan, isNotEmpty);
      expect(
        pilihan.map((p) => p.grup).toSet(),
        {'RTD', 'Type K', 'Type N'},
        reason: 'Penyaringnya `grup` yang dikirim server — aturan "Type N '
            'mulai dari 3" sengaja NGGAK ditulis ulang di HP.',
      );

      // Penomorannya beda per tipe, dan itu dari kertasnya sendiri.
      List<String> nomor(String tipe) =>
          [for (final p in pilihan) if (p.grup == tipe) p.nilai];

      expect(nomor('RTD'), ['17']);
      expect(nomor('Type K'), hasLength(16));
      expect(nomor('Type N').first, '3');
      expect(nomor('Type N'), hasLength(10));
    });
  });

  group('kunci baris', () {
    test('tujuh set point KOSONG tetap jadi tujuh baris', () {
      final b = bentukDariFixture();
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      // Penjaga nomor 3. Kertasnya nyetak tujuh baris kosong; dikunci ke NILAI
      // set point (yang semuanya null), ketujuhnya jadi satu baris.
      expect(
        state.titik, hasLength(7),
        reason: 'Tujuh baris Setpoint kosong nggak boleh saling menelan.',
      );
    });

    test('deret standar & UUT berbagi kunci yang SAMA', () {
      final b = bentukDariFixture();
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final uut = tabel.firstWhere((t) => t.deretUut);

      for (var i = 0; i < state.barisTabel(standar).length; i++) {
        expect(
          state.kunciBaris(state.barisTabel(standar), i, standar),
          state.kunciBaris(state.barisTabel(uut), i, uut),
          reason: 'Dua deret itu SET POINT YANG SAMA, dibaca bergantian tiap '
              '10 detik — kalau kuncinya beda, `Correction` diadu ke titik '
              'yang salah.',
        );
      }
    });
  });

  group('payload', () {
    test('dua deret sampai utuh, sesuai sesi master 071-CAL-325', () {
      final b = bentukDariFixture();
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final baris = state.barisTabel(standar);

      // Titik ke-2 sesi master: set point 60 °C, No. Termokopel 2.
      final kunci = state.kunciBaris(baris, 1, standar);
      final titik = state.titik[kunci]!;

      // Set point diketik teknisi — kertas TIDS nyetak kolom Setpoint KOSONG.
      // Ini penjaga nomor 3: `titikUkur` baris ini cuma nomor barisnya (2),
      // dan yang harus terkirim angka yang diketik (60).
      titik.titikCtl.text = '60';
      const deretStandar = ['60.1', '60.1', '60.1', '60.2', '60.2'];
      const deretUut = ['60.3', '60.34', '60.45', '60.47', '60.41'];

      for (var i = 0; i < 5; i++) {
        titik.kotak('standar', 'pembacaan', i).text = deretStandar[i];
        titik.kotak('uut', 'pembacaan', i).text = deretUut[i];
      }
      titik.noProbeCtl.text = '2';

      final payload = titik.toSubmissionPasangan();

      expect(
        payload['titik_ukur'],
        60.0,
        reason: 'Yang terkirim WAJIB set point yang diketik, bukan nomor '
            'baris. Terkirim `2`, sertifikatnya mengklaim titik yang salah '
            'tanpa satu pun error di jalurnya.',
      );
      expect(payload['no_probe'], 2);
      expect(payload['standar'], [60.1, 60.1, 60.1, 60.2, 60.2]);
      expect(payload['uut'], [60.3, 60.34, 60.45, 60.47, 60.41]);

      // Jalur DATAR nggak boleh ikut kekirim: server memindahkan `pembacaan`
      // ke deret `uut` kalau pasangannya kosong, jadi mengirim dua-duanya
      // berarti satu deret nimpa deret lainnya.
      expect(payload.containsKey('pembacaan'), isFalse);
    });

    test('baris yang belum disentuh nggak ikut dikirim', () {
      final b = bentukDariFixture();
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      expect(
        state.titik.values.every((t) => t.pasanganKosong),
        isTrue,
        reason: 'Lembar baru dibuka: belum ada satu sel pun terisi.',
      );
    });
  });

  group('mode mock', () {
    test('bentuk mock SAMA PERSIS dengan fixture dari server', () {
      // Mock yang diketik ulang cuma membuktikan layar sepakat dengan dirinya
      // sendiri. Dua-duanya lahir dari respons `bentukLembarKerja()` yang sama,
      // jadi begitu server menggeser satu kunci, yang merah duluan test ini —
      // bukan lembar yang salah di tangan teknisi.
      expect(
        contohBentukLembarKerjaTids(),
        jsonDecode(
          File('test/fixtures/lembar-kerja-tids.json').readAsStringSync(),
        ),
      );
    });

    test('profil `tids` dapat bentuk TIDS, bukan jatuh ke pH', () async {
      final b = await MockLembarKerjaService().ambilBentuk('token', profil: 'tids');

      expect(b.kodeDokumen, 'SIDIK-FM-CAL-0506_Rev.4');
      expect(b.berpasangan, isTrue);
      expect(
        tabelDari(b).map((t) => t.tahap),
        ['pembacaan_standard', 'pembacaan_uut'],
        reason: 'Sebelum 28 Agt 2026 mode mock memajang lembar pH buat TIDS — '
            'nggak ada error, cuma lembar yang salah.',
      );
    });
  });
}
