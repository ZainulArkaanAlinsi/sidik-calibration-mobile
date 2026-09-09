import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_aliran.dart';

/// Lembar **Flowmeter Ultrasonic** di sisi HP — alat ke-27 & ke-28.
///
/// ## Kenapa test ini ada, dan kenapa dia paling perlu dari semua lembar
///
/// Satu titik lembar ini punya **DUA deret berdampingan**: pembacaan UUT dan
/// pembacaan totalizer standar. Deviasinya lahir dari selisih BERPASANGAN
/// keduanya — jadi kalau kotaknya tertukar atau saling tertimpa, yang terbit
/// bukan error melainkan **deviasi NOL di setiap titik**: sertifikat yang
/// mencetak koreksi 0,000 dan terlihat seperti alat yang sangat akurat.
///
/// Dan pada varian Flowrate deret UUT-nya **bersarang**: tiap ulangan berisi
/// tiga durasi (20"/40"/60"), dan simpangan bakunya dihitung atas ketiga durasi
/// ulangan ITU. Diratakan, komponen budget ke-3 keluar jauh lebih besar dan
/// tetap terlihat masuk akal.
///
/// Bentuk seperti itu sudah TIGA kali baru ketahuan waktu payload HP asli diadu
/// ke bentuk lembarnya — TIDS, Timbangan, Micrometer.
void main() {
  LembarKerjaState buatTotalizer() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaFlowmeterTotalizer()),
      clientRequestId: 'uji-flowmeter-totalizer',
    );

    isian.alat = const EquipmentLookup(
      id: 27,
      namaAlat: 'Flow Meter Cairan (Totalizer)',
      serialNumber: 'FM-TOT-DEMO-01',
      kategori: 'aliran',
      status: 'aktif',
      satuan: 'L',
      rangeMax: 9999,
      resolusi: 0.01,
    );

    return isian;
  }

  LembarKerjaState buatFlowrate() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaFlowmeterFlowrate()),
      clientRequestId: 'uji-flowmeter-flowrate',
    );

    isian.alat = const EquipmentLookup(
      id: 28,
      namaAlat: 'Flow Meter Cairan (Flowrate)',
      serialNumber: 'FM-FLW-DEMO-01',
      kategori: 'aliran',
      status: 'aktif',
      satuan: 'Lpm',
      rangeMax: 9999,
      resolusi: 0.001,
    );

    return isian;
  }

  List<TabelHasil> tabelBagian(LembarKerjaState isian, String kode) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == kode).tabel;

  group('bentuk lembarnya sendiri', () {
    test('kedua varian kebaca utuh, dan bukan lembar pH', () {
      for (final isian in [buatTotalizer(), buatFlowrate()]) {
        expect(isian.bentuk.kodeDokumen, 'SIDIK-FM-CAL-0538_Rev.0');
        expect(isian.bentuk.bagian.map((b) => b.kode).toList(), [
          'identitas_alat',
          'pemilik',
          'usage_check',
          'pipa',
          'hasil',
          'penutup',
        ]);

        // LIMA tabel di `hasil` + DUA di `pipa`. Kalau salah satunya hilang,
        // deret yang dibawanya nggak punya kotak sama sekali — dan lembarnya
        // tetap kebuka rapi.
        expect(tabelBagian(isian, 'hasil'), hasLength(5));
        expect(tabelBagian(isian, 'pipa'), hasLength(2));
      }
    });

    test('Flowrate punya tiga kolom durasi, Totalizer satu', () {
      final uutFlowrate = tabelBagian(buatFlowrate(), 'hasil').first;
      final uutTotalizer = tabelBagian(buatTotalizer(), 'hasil').first;

      expect(uutFlowrate.grup, 'flow_uut_pembacaan');
      expect(uutTotalizer.grup, 'flow_uut_pembacaan');

      expect(
        uutFlowrate.kolom.map((k) => k.kode).toList(),
        ['durasi_1', 'durasi_2', 'durasi_3'],
        reason:
            'Kolom durasi hilang = sembilan pembacaan Flowrate meleleh jadi '
            'tiga. Simpangan bakunya berubah dari sebaran antar-DURASI jadi '
            'sebaran antar-ULANGAN, dan komponen budget ke-3 keluar jauh lebih '
            'besar tanpa satu pun error.',
      );

      expect(
        uutTotalizer.kolom.map((k) => k.kode).toList(),
        ['pembacaan'],
        reason:
            'Totalizer nggak punya durasi — masternya belum ikut revisi 20 Mei '
            '2026 yang menambahkan blok itu ke Flowrate.',
      );
    });
  });

  group('kunci baris nggak bentrok antar KETUJUH tabel', () {
    test('ketujuhnya sekunci tapi kotaknya lepas', () {
      final isian = buatFlowrate();
      final semua = [
        ...tabelBagian(isian, 'hasil'),
        ...tabelBagian(isian, 'pipa'),
      ];

      expect(semua, hasLength(7));

      // Bentroknya BUKAN teoretis: ketujuh tabel ber-`tahap` sama, jadi
      // `kunciTabel`-nya jatuh ke nilai yang sama persis.
      for (final t in semua) {
        expect(t.kunciTabel, semua.first.kunciTabel);
      }

      // Yang memisahkannya `offset_kunci` yang BERBEDA-BEDA. Dua tabel yang
      // berbagi satu offset tetap bertabrakan — dan di lembar ini akibatnya
      // yang terburuk dari semua lembar: pembacaan standar tertimpa pembacaan
      // UUT, dan deviasinya jadi NOL di seluruh sesi.
      final offset = semua.map((t) => t.offsetKunci).toList();

      expect(
        offset.toSet(),
        hasLength(semua.length),
        reason:
            'Ada tabel yang berbagi `offset_kunci`: $offset. Kotaknya menyatu, '
            'dan angka yang diketik di satu tabel muncul di tabel lain — tanpa '
            'satu pun error. Kalau yang menyatu UUT & standar, deviasinya NOL '
            'di setiap titik dan sertifikatnya kebaca seperti alat yang sangat '
            'akurat.',
      );
    });
  });

  group('penentu angka', () {
    test('mode, satuan, dan resolusi ditanyakan kalau kosong', () {
      final kosong = buatFlowrate()
          .pilihanPenentuAngkaKosong
          .map((f) => f.kode)
          .toList();

      expect(
        kosong,
        contains('spesifikasi_alat.flowmeter.mode'),
        reason:
            'Mode yang kosong bikin `FlowmeterMentah::blokSesi()` balik null, '
            'dan SELURUH titik pulang "belum dihitung". Mode yang SALAH lebih '
            'buruk lagi: budgetnya 8 komponen padahal harusnya 9 (atau '
            'sebaliknya), angkanya tetap keluar dan tetap terlihat wajar.',
      );
      expect(
        kosong,
        contains('spesifikasi_alat.flowmeter.satuan'),
        reason:
            'Satuan mengalikan SELURUH pembacaan — `m3/h` vs `LPM` beda 16,67x.',
      );
      expect(kosong, contains('spesifikasi_alat.flowmeter.resolusi'));
    });

    test('geometri pipa TIDAK ikut penjaga ini, dan itu perlu dicatat', () {
      final kosong = buatFlowrate()
          .pilihanPenentuAngkaKosong
          .map((f) => f.kode)
          .toList();

      // Diameter & ketebalan pipa MENENTUKAN ANGKA — dari keduanya lahir `u_A`,
      // dan salah satunya kosong bikin DUA komponen budget lenyap sekaligus.
      // Tapi di lembar ini keduanya TABEL (`pipa_diameter`, `pipa_ketebalan`),
      // bukan field, jadi `pilihanPenentuAngkaKosong` nggak melihatnya.
      //
      // Ditulis sebagai FAKTA yang diuji, bukan didiamkan: kodenya memang
      // terdaftar di `_kodePenentuAngka`, tapi selama bentuknya tabel dia nggak
      // pernah menyala. Yang menahan tetap SERVER — dia memblokir titiknya
      // dengan alasan yang kebaca. Kalau suatu saat keduanya dipindah jadi
      // field, test ini yang merah duluan dan penjaganya jadi hidup.
      expect(
        kosong,
        isNot(contains('spesifikasi_alat.flowmeter.diameter_pipa_mm')),
        reason:
            'Geometri pipa sekarang kebaca penjaga penentu angka. Bagus — '
            'cabut ekspektasi ini dan pindahkan jadi `contains`.',
      );
    });
  });

  /// ## CACAT YANG DITEMUKAN GRUP INI — sudah diperbaiki
  ///
  /// Waktu ketiga test di bawah pertama ditulis, `toSubmission()` **nggak
  /// menghasilkan kunci `flow_uut_pembacaan` maupun `flow_std_pembacaan` sama
  /// sekali**. Lembarnya tergambar rapi, teknisi bisa mengisinya sampai penuh,
  /// lalu payloadnya sampai ke server dengan `measurements` **KOSONG** — nol
  /// baris `raw_measurements`, nol hitungan, tanpa error di kedua sisi.
  ///
  /// Sebabnya: kelima tabel `hasil` nggak menyatakan `simpan_ke`, jadi HP
  /// nggak tahu ke mana angkanya harus dikirim dan membuang barisnya sebagai
  /// "kosong". Kejadian KEEMPAT dari pola yang sama — TIDS, Timbangan,
  /// Micrometer, sekarang Flowmeter — dan keempatnya baru ketahuan waktu
  /// payload HP asli diadu ke bentuk lembarnya, persis yang dilakukan grup ini.
  ///
  /// Diperbaiki dari DUA sisi: server menyatakan tujuan tiap tabel
  /// (`FlowmeterProfile`), dan HP menyusun `measurements[]` dari tabel yang
  /// menyebut tujuannya (`LembarKerjaState.tabelDeretBernama`).
  group('payload', () {
    test('deret UUT Flowrate terkirim BERSARANG per ulangan', () {
      final isian = buatFlowrate();
      final uut = tabelBagian(isian, 'hasil').first;
      final baris = isian.barisTabel(uut);
      final titik = isian.titikUntukBaris(baris, 0, uut)!;

      // Tiga ulangan x tiga durasi, angkanya dibuat beda semua supaya
      // pergeseran apa pun kelihatan.
      const nilai = [
        [101.255, 101.276, 101.289],
        [102.654, 102.625, 102.678],
        [101.986, 101.910, 101.945],
      ];

      for (var ulangan = 0; ulangan < 3; ulangan++) {
        for (var durasi = 0; durasi < 3; durasi++) {
          titik.kotak(uut.kunciTabel, 'durasi_${durasi + 1}', ulangan).text =
              nilai[ulangan][durasi].toString();
        }
      }

      final kiriman = isian.toSubmission(draft: true);
      final json = kiriman.measurements.map((m) => m.toJson()).toList();
      final terisi = json.firstWhere(
        (m) => (m['flow_uut_pembacaan'] as List?)?.isNotEmpty ?? false,
      );

      final deret = (terisi['flow_uut_pembacaan'] as List)
          .map((u) => (u as List).cast<num>().map((x) => x.toDouble()).toList())
          .toList();

      expect(
        deret,
        nilai,
        reason:
            'Deret UUT-nya harus BERSARANG (ulangan → durasi). Diratakan jadi '
            'sembilan angka, server menyusunnya ulang sebagai tiga ulangan x '
            'satu durasi — simpangan bakunya berubah dari sebaran antar-DURASI '
            'jadi antar-ULANGAN, dan komponen budget ke-3 keluar jauh lebih '
            'besar. Nggak ada error di kedua sisi.',
      );
    });

    test('pembacaan standar terkirim di deretnya SENDIRI, bukan tercampur UUT', () {
      final isian = buatFlowrate();
      final tabel = tabelBagian(isian, 'hasil');
      final uut = tabel.first;
      final std = tabel.firstWhere((t) => t.grup == 'flow_std_pembacaan');

      final barisUut = isian.barisTabel(uut);
      final barisStd = isian.barisTabel(std);

      for (var u = 0; u < 3; u++) {
        for (var d = 0; d < 3; d++) {
          isian
              .titikUntukBaris(barisUut, 0, uut)!
              .kotak(uut.kunciTabel, 'durasi_${d + 1}', u)
              .text = '300.0';
        }

        isian
            .titikUntukBaris(barisStd, 0, std)!
            .kotak(std.kunciTabel, 'pembacaan', u)
            .text = '31$u.0';
      }

      final kiriman = isian.toSubmission(draft: true);
      final json = kiriman.measurements.map((m) => m.toJson()).toList();
      final terisi = json.firstWhere(
        (m) => (m['flow_std_pembacaan'] as List?)?.isNotEmpty ?? false,
      );

      expect(
        (terisi['flow_std_pembacaan'] as List).cast<num>(),
        [310.0, 311.0, 312.0],
        reason:
            'Pembacaan standar mendarat di deret yang salah. Kalau dia tertimpa '
            'pembacaan UUT, deviasinya NOL di setiap titik — dan sertifikatnya '
            'kebaca seperti alat yang sangat akurat.',
      );

      // Dan UUT-nya TIDAK ikut berubah — dua deret yang berdampingan harus
      // tetap terpisah sampai ke payload.
      expect(
        ((terisi['flow_uut_pembacaan'] as List).first as List).cast<num>(),
        [300.0, 300.0, 300.0],
      );
    });

    test('geometri pipa masuk spesifikasi_alat, bukan jadi titik kalibrasi', () {
      final isian = buatFlowrate();
      final pipa = tabelBagian(isian, 'pipa');
      final diameter = pipa.firstWhere((t) => t.grup == 'pipa_diameter');
      final tebal = pipa.firstWhere((t) => t.grup == 'pipa_ketebalan');

      const nilaiD = [50.81, 50.82, 50.81];
      const nilaiT = [2.32, 2.31, 2.32];

      for (var i = 0; i < 3; i++) {
        isian
            .titikUntukBaris(isian.barisTabel(diameter), 0, diameter)!
            .kotak(diameter.kunciTabel, 'pembacaan', i)
            .text = nilaiD[i].toString();
        isian
            .titikUntukBaris(isian.barisTabel(tebal), 0, tebal)!
            .kotak(tebal.kunciTabel, 'pembacaan', i)
            .text = nilaiT[i].toString();
      }

      final kiriman = isian.toSubmission(draft: true);

      expect(
        kiriman.spesifikasiAlat.containsKey('flowmeter'),
        isTrue,
        reason:
            'Geometri pipa itu tingkat-SESI. Dipaksa jadi `titik_ke`, dia lahir '
            'sebagai titik hantu yang selalu gagal hitung ulang.',
      );
    });
  });
}
