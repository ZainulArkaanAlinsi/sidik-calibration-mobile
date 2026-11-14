import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_aliran.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_analitik.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_autoclave.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_dimensi.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_enclosure.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_gaya.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_massa.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_panjang.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_piston.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_tekanan.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetric_glassware.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetrik.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_waktu.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Gerbang "wajib dicek" di SEMUA bentuk lembar contoh (48 bentuk).
///
/// ## Kenapa sapuan ini ada
///
/// Versi pertama gerbang mengidentitaskan sel tabel dengan `titikUkur|tahap|
/// kolom|index`. `titikUkur` tidak unik antar baris/tabel (Pressure Gauge naik
/// dan turun, Flowmeter, Anak Timbangan, Thermohygro 50 C / 50 %RH, lembar
/// ber-`offset_kunci`), jadi sel berbeda berbagi satu kunci: catatan yang satu
/// menimpa yang lain, sel kamera hilang dari gerbang, dan Kirim terbuka dengan
/// angka kamera yang tak pernah dicek. Semua tes pertama memakai lembar pH
/// (titik unik) sehingga kunci bertabrakan tidak pernah teruji.
///
/// Untuk TIAP bentuk, test ini mengisi sel dari foto lewat dua jalur (alamat
/// posisi `terapkanHasilFotoAsli`, dan titik ukur `terapkanHasilFotoTabel`),
/// lalu memeriksa:
///  1. tiap sel yang benar-benar terisi terhitung TEPAT SEKALI di gerbang;
///  2. tidak ada kunci kembar;
///  3. tiap sel punya pemantau tanda (widget bisa menggambar tandanya);
///  4. lembar pemeriksa menampilkan tiap sel tepat sekali;
///  5. Kirim (jumlahPerluCek) turun SATU per konfirmasi dan baru 0 sesudah
///     SEMUA dicek.
void main() {
  final bentuk = <(String, Map<String, dynamic> Function())>[
    ('pH', contohBentukLembarKerja),
    ('Conductivity', contohBentukLembarKerjaConductivity),
    ('Turbidi', contohBentukLembarKerjaTurbidi),
    ('Chlorine', contohBentukLembarKerjaChlorine),
    ('Refractometer', contohBentukLembarKerjaRefractometer),
    ('Spectro', contohBentukLembarKerjaSpectro),
    ('Visco', contohBentukLembarKerjaVisco),
    ('Do', contohBentukLembarKerjaDo),
    ('Gas', contohBentukLembarKerjaGas),
    ('Tits', contohBentukLembarKerjaTits),
    ('Timer', contohBentukLembarKerjaTimer),
    ('Centrifuge', contohBentukLembarKerjaCentrifuge),
    ('Tachometer', contohBentukLembarKerjaTachometer),
    ('Thermocouple', contohBentukLembarKerjaThermocouple),
    ('TermometerGelas', contohBentukLembarKerjaTermometerGelas),
    ('Thermohygro', contohBentukLembarKerjaThermohygro),
    ('Tids', contohBentukLembarKerjaTids),
    ('Micrometer', contohBentukLembarKerjaMicrometer),
    ('HeightGauge', contohBentukLembarKerjaHeightGauge),
    ('DialIndicator', contohBentukLembarKerjaDialIndicator),
    ('JangkaSorong', contohBentukLembarKerjaJangkaSorong),
    ('Sieve', contohBentukLembarKerjaSieve),
    ('Timbangan', contohBentukLembarKerjaTimbangan),
    ('AnakTimbangan', contohBentukLembarKerjaAnakTimbangan),
    ('PressureGauge', contohBentukLembarKerjaPressureGauge),
    ('VacuumGauge', contohBentukLembarKerjaVacuumGauge),
    ('DifferentialPressure', contohBentukLembarKerjaDifferentialPressure),
    ('Utm', contohBentukLembarKerjaUtm),
    ('LoadCell', contohBentukLembarKerjaLoadCell),
    ('ProvingRing', contohBentukLembarKerjaProvingRing),
    ('LabuUkur', contohBentukLembarKerjaLabuUkur),
    ('PipetVolume', contohBentukLembarKerjaPipetVolume),
    ('Picnometer', contohBentukLembarKerjaPicnometer),
    ('Buret', contohBentukLembarKerjaBuret),
    ('GelasUkur', contohBentukLembarKerjaGelasUkur),
    ('PipetUkur', contohBentukLembarKerjaPipetUkur),
    ('Hydrometer', contohBentukLembarKerjaHydrometer),
    ('PistonPipette', contohBentukLembarKerjaPistonPipette),
    ('Dispensett', contohBentukLembarKerjaDispensett),
    ('BuretDigital', contohBentukLembarKerjaBuretDigital),
    ('FlowmeterTotalizer', contohBentukLembarKerjaFlowmeterTotalizer),
    ('FlowmeterFlowrate', contohBentukLembarKerjaFlowmeterFlowrate),
    ('Oven', contohBentukLembarKerjaOven),
    ('Furnace', contohBentukLembarKerjaFurnace),
    ('Bath', contohBentukLembarKerjaBath),
    ('Inkubator', contohBentukLembarKerjaInkubator),
    ('Refrigerator', contohBentukLembarKerjaRefrigerator),
    ('Autoklaf', contohBentukLembarKerjaAutoklaf),
  ];

  /// Id tabel di peta formulir asli — kembaran `_idTabelServer` di state.
  String idTabel(TabelHasil t, List<TabelHasil> semua) {
    final dasar = t.grup ?? t.tahap;
    final kembar = semua.where((o) => (o.grup ?? o.tahap) == dasar).length > 1;

    return kembar ? '${dasar}_${t.tahap}' : dasar;
  }

  /// Sel tabel yang BENAR-BENAR berisi, dibaca langsung dari kotaknya lewat
  /// kunci peta — jawaban pembanding yang tidak melewati gerbang sama sekali.
  List<({double peta, String tahap, String kolom, int index})> terisi(
    LembarKerjaState s,
  ) {
    final hasil = <({double peta, String tahap, String kolom, int index})>[];

    for (final t in s.bentuk.bagian.expand((b) => b.tabel)) {
      final baris = s.barisTabel(t);

      for (var i = 0; i < baris.length; i++) {
        final peta = s.kunciBaris(baris, i, t);
        final st = s.titik[peta];
        if (st == null) continue;

        for (final k in t.kolom) {
          for (var r = 0; r < t.pengulangan.length; r++) {
            final isi = st.teksKotakJikaAda(t.kunciTabel, k.kode, r);
            if (isi != null && isi.trim().isNotEmpty) {
              hasil.add((
                peta: peta,
                tahap: t.kunciTabel,
                kolom: k.kode,
                index: r,
              ));
            }
          }
        }
      }
    }

    return hasil;
  }

  var teksKe = 0;
  String teksUnik() => '${10 + (teksKe++)},5';

  /// Isi SEMUA sel lewat alamat posisi (baris ke-i tiap tabel).
  void isiLewatPosisi(LembarKerjaState s) {
    final semua = [for (final b in s.bentuk.bagian) ...b.tabel];
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
      final n = s.barisTabel(t).length;

      for (var i = 0; i < n; i++) {
        for (final k in t.kolom) {
          for (final r in t.pengulangan) {
            sel.add((
              tabelId: idTabel(t, semua),
              tahap: t.tahap,
              barisKe: i + 1,
              repeatNo: r,
              fieldId: k.kode,
              teks: teksUnik(),
              keyakinan: 0.99,
            ));
          }
        }
      }
    }

    s.terapkanHasilFotoAsli(sel);
  }

  /// Isi SEMUA sel lewat titik ukur baris (jalur "Foto tabel ini").
  void isiLewatTitik(LembarKerjaState s) {
    for (final t in s.bentuk.bagian.expand((b) => b.tabel)) {
      final baris = s.barisTabel(t);

      for (var i = 0; i < baris.length; i++) {
        final st = s.titik[s.kunciBaris(baris, i, t)];
        if (st == null) continue;

        for (final k in t.kolom) {
          for (final r in t.pengulangan) {
            final SelTabelFoto sel = (
              titikUkur: st.titikUkur,
              repeatNo: r,
              fieldId: k.kode,
              teks: teksUnik(),
              keyakinan: 0.99,
            );
            s.terapkanHasilFotoTabel([sel], tabel: t);
          }
        }
      }
    }
  }

  /// Gerbang harus cocok dengan kotak yang benar-benar berisi.
  void periksaGerbang(LembarKerjaState s, int jumlahIsi, String ket) {
    final daftar = s.daftarSelCek();

    expect(
      daftar.length,
      jumlahIsi,
      reason: '$ket: tiap sel yang terisi dari foto terhitung tepat sekali',
    );
    expect(
      daftar.map((x) => x.kunci).toSet().length,
      daftar.length,
      reason: '$ket: tidak ada kunci kembar',
    );
    expect(s.jumlahPerluCek, jumlahIsi, reason: '$ket: semua perlu dicek');

    // Lembar pemeriksa: tiap sel muncul tepat sekali, dan Kirim (jumlah yang
    // menahan) turun SATU per konfirmasi, baru nol sesudah semuanya.
    final dilihat = <String>{};
    var sisa = jumlahIsi;
    String? setelah;

    while (true) {
      final sel = s.selCekBerikutnya(setelah: setelah);
      if (sel == null) break;

      expect(
        dilihat.add(sel.kunci),
        isTrue,
        reason: '$ket: ${sel.kunci} dua kali',
      );
      expect(s.jumlahPerluCek, sisa, reason: '$ket: Kirim masih terkunci');
      expect(s.konfirmasiSelCek(sel.kunci), isTrue, reason: '$ket: konfirmasi');

      sisa--;
      setelah = sel.kunci;
      expect(s.jumlahPerluCek, sisa, reason: '$ket: turun satu per konfirmasi');
    }

    expect(
      dilihat.length,
      jumlahIsi,
      reason: '$ket: semua tampil di pemeriksa',
    );
    expect(
      s.jumlahPerluCek,
      0,
      reason: '$ket: terbuka hanya sesudah semua dicek',
    );
  }

  group('semua bentuk tabel: gerbang menghitung tiap sel tepat sekali', () {
    var totalSel = 0;

    for (final (nama, json) in bentuk) {
      for (final (jalur, isi) in <(String, void Function(LembarKerjaState))>[
        ('posisi', isiLewatPosisi),
        ('titik ukur', isiLewatTitik),
      ]) {
        test('$nama via $jalur', () {
          final s = LembarKerjaState(
            bentuk: LembarKerja.fromJson(json()),
            clientRequestId: 'uji-$nama',
          );
          addTearDown(s.dispose);

          isi(s);
          final isiSel = terisi(s);
          totalSel += isiSel.length;

          // Tiap sel yang terisi punya pemantau tanda (kunci peta, bukan titik).
          for (final c in isiSel) {
            expect(
              s.pemantauCekTabel(c.peta, c.tahap, c.kolom, c.index),
              isNotNull,
              reason:
                  '$nama: sel ${c.peta}|${c.tahap}|${c.kolom}|${c.index} tanpa tanda',
            );
          }

          // Hanya jenis tabel yang diisi di sini; matriks/grid dites di bawah.
          final tabelSaja = s.daftarSelCek().where(
            (x) => x.jenis == JenisSelCek.tabel,
          );
          expect(
            tabelSaja.length,
            isiSel.length,
            reason: '$nama: tepat sekali',
          );

          periksaGerbang(s, isiSel.length, nama);
        });
      }
    }

    test('sapuan benar-benar mengisi sel (penjaga penjaga)', () {
      // Test di atas lulus kosong bila foto tak pernah mendarat; pastikan
      // sapuannya memang menyentuh ratusan sel.
      expect(totalSel, greaterThan(500));
    });
  });

  group('kunci lama (titikUkur) tidak bisa kembali', () {
    test('Pressure Gauge: foto tabel 1 lalu tabel 2, tiga sel masing-masing', () {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaPressureGauge()),
        clientRequestId: 'uji-dua-tabel',
      );
      addTearDown(s.dispose);

      final tabel = s.bentuk.bagian.expand((b) => b.tabel).toList();
      expect(tabel.length, greaterThan(1), reason: 'prasyarat: dua tabel');

      var terakhir = 0;
      for (final t in tabel.take(2)) {
        final baris = s.barisTabel(t);
        var masuk = 0;

        for (var i = 0; i < baris.length && masuk < 3; i++) {
          final st = s.titik[s.kunciBaris(baris, i, t)];
          if (st == null) continue;

          final SelTabelFoto sel = (
            titikUkur: st.titikUkur,
            repeatNo: t.pengulangan.first,
            fieldId: t.kolom.first.kode,
            teks: teksUnik(),
            keyakinan: 0.99,
          );
          masuk += s.terapkanHasilFotoTabel([sel], tabel: t);
        }

        expect(masuk, greaterThan(0), reason: 'prasyarat: ${t.judul}');
        // Foto tabel kedua TIDAK boleh mengurangi / mengubah status tabel pertama.
        expect(
          s.jumlahPerluCek,
          terakhir + masuk,
          reason: 'sel tabel lain tidak ikut tertimpa',
        );
        terakhir = s.jumlahPerluCek;
      }

      expect(
        s.daftarSelCek().every((x) => x.status == StatusCekSel.perluCek),
        isTrue,
        reason: 'tidak ada sel yang jadi "sudah dicek" tanpa aksi',
      );
    });

    test('Thermohygro: set point 50 di blok suhu DAN blok kelembapan', () {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaThermohygro()),
        clientRequestId: 'uji-50',
      );
      addTearDown(s.dispose);

      isiLewatPosisi(s);
      final n = terisi(s).length;

      expect(n, greaterThan(0));
      periksaGerbang(s, n, 'Thermohygro');
    });
  });

  // ------------------------------------------------- matriks dan grid

  group('Autoklaf (matriks) dan Enclosure (grid)', () {
    test('semua sel matriks yang diisi foto terhitung sekali dan terkunci', () {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAutoklaf()),
        clientRequestId: 'uji-matriks',
      );
      addTearDown(s.dispose);

      final m = s.bagianMatriks!.matriks!;
      final sel = <SelTabelFoto>[];
      for (var i = 0; i < m.semuaBaris.length; i++) {
        if (m.semuaBaris[i].tipe == 'jam') continue;

        for (final w in m.titikWaktu) {
          sel.add((
            titikUkur: MatriksHasil.kunciBarisFoto(i),
            repeatNo: w,
            fieldId: 'pembacaan',
            teks: teksUnik(),
            keyakinan: 0.99,
          ));
        }
      }

      final n = s.terapkanHasilFotoMatriks(m, sel);
      expect(n, greaterThan(0));
      periksaGerbang(s, n, 'Autoklaf');
    });

    test('semua sel grid yang diisi foto terhitung sekali dan terkunci', () {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaOven()),
        clientRequestId: 'uji-grid',
      );
      addTearDown(s.dispose);

      final g = s.grid!;
      final sp = g.setPoint.first;
      final baris =
          g.bentuk.jumlahSensorSaran +
          (g.bentuk.barisIndikator ? 1 : 0) +
          (g.bentuk.barisSuhuRuang ? 1 : 0);

      final n = sp.terapkanHasilFotoPosisi([
        for (var b = 1; b <= baris; b++)
          for (final r in g.bentuk.pengulangan)
            (barisKe: b, repeatNo: r, teks: teksUnik(), keyakinan: 0.99),
      ]);

      expect(n, greaterThan(0));
      periksaGerbang(s, n, 'Oven (grid)');
    });
  });
}
