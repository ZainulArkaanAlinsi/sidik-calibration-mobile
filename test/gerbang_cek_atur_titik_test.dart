import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_waktu.dart';

/// Pengatur titik (tambah / hapus / geser titik sesi) SESUDAH foto: gerbang
/// "wajib dicek" harus mengikuti isi sel yang pindah.
///
/// ## Bug yang ditutup
///
/// Di lembar berpasangan kunci baris = POSISI (`kunciBaris`), jadi menghapus
/// titik pertama menggeser isi sel ke kunci lain. `_bangunTitik` memindahkan
/// ISI menurut `petaKunci` tetapi tidak memindahkan `selKamera` dan catatan
/// `cekTabel`: gerbang 3 -> 0, dua sel tersisa tampak "sudah dicek" tanpa aksi
/// (isi awal tertinggal di kunci lama), dan di Timer tandanya lenyap.
void main() {
  final bentuk = <(String, Map<String, dynamic> Function())>[
    ('Thermocouple', contohBentukLembarKerjaThermocouple),
    ('TermometerGelas', contohBentukLembarKerjaTermometerGelas),
    ('Thermohygro', contohBentukLembarKerjaThermohygro),
    ('Timer', contohBentukLembarKerjaTimer),
  ];

  var teksKe = 0;
  String teksUnik() => '${10 + (teksKe++)},5';

  /// Bagian + tabel berpasangan yang titiknya bisa diatur teknisi.
  ({String kode, List<double> nilai})? bagianTitik(LembarKerjaState s) {
    for (final b in s.bentuk.bagian) {
      final tabel = b.tabel.where((t) => t.berpasangan && t.titikBisaDiubah);
      if (tabel.isEmpty) continue;

      return (
        kode: b.kode,
        nilai: [for (final r in s.barisTabel(tabel.first)) r.titikUkur],
      );
    }

    return null;
  }

  /// Isi tiap sel bagian [kodeBagian] lewat alamat posisi, lalu kembalikan
  /// peta isi-sel -> status gerbang (isi unik per sel).
  void isiSemua(LembarKerjaState s, String kodeBagian, {int? maksBaris}) {
    final semua = [for (final b in s.bentuk.bagian) ...b.tabel];
    String idTabel(TabelHasil t) {
      final dasar = t.grup ?? t.tahap;
      final kembar =
          semua.where((o) => (o.grup ?? o.tahap) == dasar).length > 1;

      return kembar ? '${dasar}_${t.tahap}' : dasar;
    }

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

    for (final b in s.bentuk.bagian.where((b) => b.kode == kodeBagian)) {
      for (final t in b.tabel) {
        final semuaBaris = s.barisTabel(t).length;
        final n = maksBaris == null || maksBaris > semuaBaris
            ? semuaBaris
            : maksBaris;

        for (var i = 0; i < n; i++) {
          for (final k in t.kolom) {
            for (final r in t.pengulangan.take(1)) {
              sel.add((
                tabelId: idTabel(t),
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
    }

    s.terapkanHasilFotoAsli(sel);
  }

  /// Teks tiap sel tabel yang berisi, dibaca dari kotaknya (bukan dari gerbang).
  Set<String> isiSel(LembarKerjaState s) => {
    for (final t in s.bentuk.bagian.expand((b) => b.tabel))
      for (var i = 0; i < s.barisTabel(t).length; i++)
        for (final k in t.kolom)
          for (var r = 0; r < t.pengulangan.length; r++)
            if (s.titik[s.kunciBaris(s.barisTabel(t), i, t)] case final st?)
              if ((st.teksKotakJikaAda(t.kunciTabel, k.kode, r) ?? '')
                  .trim()
                  .isNotEmpty)
                st.teksKotakJikaAda(t.kunciTabel, k.kode, r)!,
  };

  Map<String, StatusCekSel> statusPerIsi(LembarKerjaState s) => {
    for (final x in s.daftarSelCek()) x.teks: x.status,
  };

  /// Skenario: fungsi yang menyusun titik baru dari titik sekarang.
  final skenario = <(String, List<double> Function(List<double>))>[
    ('hapus titik pertama', (n) => n.skip(1).toList()),
    (
      'hapus titik tengah',
      (n) => [...n.take(n.length ~/ 2), ...n.skip(n.length ~/ 2 + 1)],
    ),
    ('hapus titik terakhir', (n) => n.take(n.length - 1).toList()),
    ('tambah titik', (n) => [...n, n.reduce((a, b) => a > b ? a : b) + 10]),
    (
      'geser: buang yang pertama, tambah di ujung',
      (n) => [...n.skip(1), n.reduce((a, b) => a > b ? a : b) + 10],
    ),
  ];

  for (final (nama, json) in bentuk) {
    group('$nama: pengatur titik sesudah foto', () {
      LembarKerjaState siap() {
        final s = LembarKerjaState(
          bentuk: LembarKerja.fromJson(json()),
          clientRequestId: 'uji-atur-$nama',
        );
        addTearDown(s.dispose);

        return s;
      }

      for (final (ket, susun) in skenario) {
        test(ket, () {
          final s = siap();
          final atur = bagianTitik(s);
          expect(atur, isNotNull, reason: '$nama punya titik yang bisa diatur');

          isiSemua(s, atur!.kode);
          final awal = statusPerIsi(s);
          expect(awal, isNotEmpty, reason: 'prasyarat: foto mendarat');
          expect(awal.values.toSet(), {StatusCekSel.perluCek});

          // Satu sel sudah dikonfirmasi SEBELUM titik diubah: statusnya harus
          // ikut pindah bersama isinya.
          final dikonfirmasi = s.daftarSelCek().first;
          s.konfirmasiSelCek(dikonfirmasi.kunci);
          final sebelum = statusPerIsi(s);

          s.aturTitik(susun(atur.nilai), bagian: atur.kode);

          final sesudah = statusPerIsi(s);
          final adaIsi = isiSel(s);

          // 1. Tiap sel yang masih berisi dan dulu hasil kamera tetap digerbang,
          //    dan tidak ada yang berubah status tanpa aksi.
          expect(
            sesudah.keys.toSet(),
            adaIsi,
            reason: '$nama/$ket: gerbang = sel kamera yang masih berisi',
          );
          for (final e in sesudah.entries) {
            expect(
              e.value,
              sebelum[e.key],
              reason: '$nama/$ket: status sel "${e.key}" tidak boleh berubah',
            );
          }

          // 2. Hitungan menahan konsisten dengan sel yang tersisa.
          expect(
            s.jumlahPerluCek,
            sesudah.values.where((x) => x == StatusCekSel.perluCek).length,
          );

          // 3. Kunci tidak kembar.
          final kunci = s.daftarSelCek().map((x) => x.kunci).toList();
          expect(kunci.toSet().length, kunci.length);
        });
      }

      for (final (ket, susun) in skenario) {
        test('$ket: ketikan tangan yang ikut bergeser TIDAK ditandai', () {
          final s = siap();
          final atur = bagianTitik(s)!;
          final tabel = s.bentuk.bagian
              .firstWhere((b) => b.kode == atur.kode)
              .tabel
              .firstWhere((t) => t.berpasangan && t.titikBisaDiubah);

          // Foto hanya mengisi dua baris pertama; baris KETIGA diketik tangan —
          // tepat di bawah sel kamera, jadi ia yang bergeser masuk ke kunci bekas
          // sel kamera begitu titik pertama dihapus.
          isiSemua(s, atur.kode, maksBaris: 2);
          final baris = s.barisTabel(tabel);
          final st =
              s.titik[s.kunciBaris(
                baris,
                baris.length < 3 ? baris.length - 1 : 2,
                tabel,
              )]!;
          st.kotak(tabel.kunciTabel, tabel.kolom.first.kode, 0).text = '99,9';
          final foto = statusPerIsi(s).keys.toSet();
          expect(foto, isNotEmpty, reason: 'prasyarat: foto mendarat');
          expect(
            foto,
            isNot(contains('99,9')),
            reason: 'prasyarat: ketikan tangan',
          );

          s.aturTitik(susun(atur.nilai), bagian: atur.kode);

          final sesudah = statusPerIsi(s);
          expect(
            sesudah.keys,
            isNot(contains('99,9')),
            reason:
                '$nama/$ket: ketikan tangan yang bergeser ke kunci bekas '
                'sel kamera tidak boleh digerbang',
          );
          expect(
            sesudah.keys.toSet().difference(foto),
            isEmpty,
            reason: '$nama/$ket: tidak ada sel baru muncul di gerbang',
          );
        });
      }

      test('menghapus semua titik membuang catatannya, tanpa sisa', () {
        final s = siap();
        final atur = bagianTitik(s)!;
        isiSemua(s, atur.kode);
        expect(s.jumlahPerluCek, greaterThan(0));

        s.aturTitik(<double>[atur.nilai.first], bagian: atur.kode);
        s.aturTitik(<double>[atur.nilai.first + 100], bagian: atur.kode);

        // Isi titik lama dibuang: gerbang tidak boleh menyisakan sel hantu.
        expect(s.daftarSelCek().length, isiSel(s).length);
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Thermohygro: DUA bagian (suhu + kelembapan) yang kuncinya saling bergantung.
  //
  // Kunci baris lembar berpasangan = offset blok parameter + posisi, dan offset
  // blok kelembapan = JUMLAH baris suhu. Mengubah titik suhu menggeser kunci
  // SELURUH blok kelembapan. Peta kunci yang hanya memuat tabel bagian yang
  // sedang diatur membuat isian kelembapan mendarat di set point tetangga —
  // 30 %RH di baris 49 %RH — tanpa error (tinjauan putaran 3: 12 dari 20 sel).
  // ---------------------------------------------------------------------------
  group('Thermohygro: dua bagian (suhu + kelembapan) sesudah foto', () {
    const bagianUji = ['hasil_suhu', 'hasil_kelembaban'];

    LembarKerjaState siap() {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaThermohygro()),
        clientRequestId: 'uji-thermohygro-dua-bagian',
      );
      addTearDown(s.dispose);

      return s;
    }

    TabelHasil tabelAtur(LembarKerjaState s, String kode) => s.bentuk.bagian
        .firstWhere((b) => b.kode == kode)
        .tabel
        .firstWhere((t) => t.berpasangan && t.titikBisaDiubah);

    /// Alamat sel menurut NOMINAL barisnya -> isi.
    Map<(String, String?, double, String, int), String> isiPerNominal(
      LembarKerjaState s,
    ) {
      final hasil = <(String, String?, double, String, int), String>{};
      for (final t in s.bentuk.bagian.expand((b) => b.tabel)) {
        final baris = s.barisTabel(t);
        for (var i = 0; i < baris.length; i++) {
          final st = s.titik[s.kunciBaris(baris, i, t)];
          if (st == null) continue;

          for (final k in t.kolom) {
            for (var r = 0; r < t.pengulangan.length; r++) {
              final isi = st.teksKotakJikaAda(t.kunciTabel, k.kode, r);
              if (isi == null || isi.trim().isEmpty) continue;

              hasil[(
                    t.kunciTabel,
                    t.parameter,
                    baris[i].titikUkur,
                    k.kode,
                    r,
                  )] =
                  isi;
            }
          }
        }
      }

      return hasil;
    }

    for (final bagian in bagianUji) {
      for (final (ket, susun) in skenario) {
        test('$bagian: $ket', () {
          final s = siap();

          // Foto mengisi tiga baris pertama di KEDUA bagian.
          for (final kode in bagianUji) {
            isiSemua(s, kode, maksBaris: 3);
          }

          // Satu sel kelembapan (baris KEEMPAT, nominal 70) diketik tangan.
          final tabelRh = tabelAtur(s, 'hasil_kelembaban');
          final barisRh = s.barisTabel(tabelRh);
          s.titik[s.kunciBaris(barisRh, 3, tabelRh)]!
                  .kotak(tabelRh.kunciTabel, tabelRh.kolom.first.kode, 0)
                  .text =
              '99,9';

          // Dua sel dikonfirmasi SEBELUM titik diubah: satu di suhu, satu di
          // kelembapan. Statusnya harus ikut pindah bersama isinya.
          final sebelumIsi = isiPerNominal(s);
          String isiDi(String parameter) => sebelumIsi.entries
              .firstWhere((e) => e.key.$2 == parameter && e.value != '99,9')
              .value;
          for (final p in ['suhu', 'kelembaban']) {
            s.konfirmasiSelCek(
              s.daftarSelCek().firstWhere((x) => x.teks == isiDi(p)).kunci,
            );
          }

          final sebelumStatus = statusPerIsi(s);
          expect(sebelumStatus, isNotEmpty, reason: 'prasyarat: foto mendarat');
          expect(sebelumStatus.values.toSet(), {
            StatusCekSel.perluCek,
            StatusCekSel.sudahDicek,
          });
          expect(sebelumStatus, isNot(contains('99,9')));
          expect(
            {for (final e in sebelumIsi.keys) e.$2},
            {'suhu', 'kelembaban'},
            reason: 'prasyarat: sel terisi di kedua bagian',
          );

          final atur = tabelAtur(s, bagian);
          final nilai = [for (final r in s.barisTabel(atur)) r.titikUkur];
          final baru = susun(nilai);
          final dihapus = nilai.toSet().difference(baru.toSet());

          s.aturTitik(baru, bagian: bagian);

          final sesudahIsi = isiPerNominal(s);
          final sesudahStatus = statusPerIsi(s);

          // 1. ISI mengikuti nominalnya — di bagian yang diatur MAUPUN bagian
          //    lain yang kuncinya ikut bergeser.
          for (final e in sebelumIsi.entries) {
            final kenaHapus =
                e.key.$2 == atur.parameter &&
                dihapus.any((n) => (n - e.key.$3).abs() < 1e-9);

            if (kenaHapus) {
              expect(
                sesudahIsi,
                isNot(contains(e.key)),
                reason: '$bagian/$ket: ${e.key} titiknya dihapus',
              );
            } else {
              expect(
                sesudahIsi[e.key],
                e.value,
                reason: '$bagian/$ket: isi ${e.key} harus tetap di nominalnya',
              );
            }
          }
          expect(
            sesudahIsi.keys.toSet().difference(sebelumIsi.keys.toSet()),
            isEmpty,
            reason: '$bagian/$ket: tidak ada isi baru muncul',
          );

          // 2. GERBANG = sel kamera yang selamat, statusnya tidak berubah, dan
          //    ketikan tangan tidak ikut.
          final selamat = {
            for (final e in sebelumIsi.entries)
              if (sesudahIsi.containsKey(e.key) && e.value != '99,9')
                e.value: sebelumStatus[e.value],
          };
          expect(sesudahStatus, selamat, reason: '$bagian/$ket: gerbang');
          expect(sesudahStatus, isNot(contains('99,9')));

          // 3. Hitungan menahan konsisten, kunci tidak kembar.
          expect(
            s.jumlahPerluCek,
            sesudahStatus.values
                .where((x) => x == StatusCekSel.perluCek)
                .length,
          );
          final kunci = s.daftarSelCek().map((x) => x.kunci).toList();
          expect(kunci.toSet().length, kunci.length);
        });
      }
    }

    test(
      'menghapus titik suhu lalu menambah lagi: sel baru kosong, tanpa hantu',
      () {
        final s = siap();
        for (final kode in bagianUji) {
          isiSemua(s, kode, maksBaris: 3);
        }

        final atur = tabelAtur(s, 'hasil_suhu');
        final nilai = [for (final r in s.barisTabel(atur)) r.titikUkur];
        final awal = s.daftarSelCek().length;

        s.aturTitik(nilai.skip(1).toList(), bagian: 'hasil_suhu');
        s.aturTitik(nilai, bagian: 'hasil_suhu');

        // Titik suhu pertama (15) kembali, tapi kosong: isinya sudah dibuang.
        final tabelRh = tabelAtur(s, 'hasil_kelembaban');
        final baru = s.titik[s.kunciBaris(s.barisTabel(atur), 0, atur)]!;
        expect(
          baru.teksKotakJikaAda(atur.kunciTabel, atur.kolom.first.kode, 0),
          anyOf(isNull, isEmpty),
        );
        baru.kotak(atur.kunciTabel, atur.kolom.first.kode, 0).text = '99,9';

        expect(
          s.daftarSelCek().map((x) => x.teks),
          isNot(contains('99,9')),
          reason:
              'ketikan tangan di titik yang ditambah lagi bukan hasil kamera',
        );
        // Sel kelembapan tidak kehilangan tandanya.
        final hilang = [
          for (final t
              in s.bentuk.bagian
                  .firstWhere((b) => b.kode == 'hasil_suhu')
                  .tabel
                  .where((t) => t.berpasangan))
            t.kolom.length,
        ].fold<int>(0, (a, b) => a + b);
        expect(
          s.daftarSelCek().length,
          awal - hilang,
          reason:
              'hanya sel titik suhu yang dihapus yang hilang dari gerbang '
              '(${tabelRh.kunciTabel} utuh)',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Lembar TANPA tabel berpasangan: titik yang dihapus lalu ditambah lagi tidak
  // boleh mewarisi catatan gerbang titik lama (hantu).
  // ---------------------------------------------------------------------------
  group('Tits: titik dihapus lalu ditambah lagi, diketik tangan', () {
    LembarKerjaState siapTits() {
      final s = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTits()),
        clientRequestId: 'uji-tits-hantu',
      );
      addTearDown(s.dispose);

      return s;
    }

    void isiTits(LembarKerjaState s) {
      isiSemua(s, s.bentuk.bagian.firstWhere((b) => b.tabel.isNotEmpty).kode);
    }

    TabelHasil tabelPertama(LembarKerjaState s) =>
        s.bentuk.bagian.expand((b) => b.tabel).first;

    TitikState barisPertama(LembarKerjaState s) {
      final t = tabelPertama(s);

      return s.titik[s.kunciBaris(s.barisTabel(t), 0, t)]!;
    }

    for (final ketikan in <(String, String?)>[
      ('nilai lain (99,9)', '99,9'),
      ('nilai SAMA dengan tebakan mesin lama', null),
    ]) {
      test('sel baru diketik ${ketikan.$1} tidak ditandai hasil kamera', () {
        final s = siapTits();
        isiTits(s);
        final t = tabelPertama(s);
        final nominal = s.titikBerlaku;
        final kolom = t.kolom.first.kode;
        final tebakanLama = barisPertama(
          s,
        ).teksKotakJikaAda(t.kunciTabel, kolom, 0)!;
        final awal = s.daftarSelCek().length;
        expect(awal, greaterThan(0));

        s.aturTitik(nominal.skip(1).toList());
        final sesudahHapus = s.daftarSelCek().length;
        expect(sesudahHapus, lessThan(awal));
        expect(
          s.selKamera.every(
            (k) => s.titik.containsKey(double.parse(k.split('|').first)),
          ),
          isTrue,
          reason: 'catatan gerbang titik yang dihapus ikut dibuang',
        );
        // Catatan isi-awal/konfirmasi di salinan lokal juga bersih: kunci
        // titik yang sudah dihapus tidak ikut tersimpan ke draf.
        final catatan = (s.salinanLokal()['cek_bacaan'] as Map)['tabel'];
        expect(
          '$catatan',
          isNot(contains('${nominal.first}|')),
          reason: 'cek_bacaan.tabel tidak menyimpan kunci titik yang dihapus',
        );

        s.aturTitik(nominal);
        expect(
          s.daftarSelCek().length,
          sesudahHapus,
          reason: 'titik yang ditambah lagi mulai kosong, bukan hasil kamera',
        );

        final teks = ketikan.$2 ?? tebakanLama;
        barisPertama(s).kotak(t.kunciTabel, kolom, 0).text = teks;

        expect(
          s.daftarSelCek().map((x) => x.teks),
          isNot(contains(teks)),
          reason: 'ketikan tangan bukan hasil kamera',
        );
        expect(s.daftarSelCek().length, sesudahHapus);
        expect(
          s.jumlahPerluCek,
          s
              .daftarSelCek()
              .where((x) => x.status == StatusCekSel.perluCek)
              .length,
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Tabel dibangun ulang TANPA mempertahankan isian (ganti satuan): isian dan
  // catatan gerbangnya hilang bersama.
  // ---------------------------------------------------------------------------
  group('Refractometer: ganti satuan lalu kembali', () {
    test(
      'catatan gerbang dibuang; ketikan tangan di kunci yang sama bersih',
      () {
        final s = LembarKerjaState(
          bentuk: LembarKerja.fromJson(contohBentukLembarKerjaRefractometer()),
          clientRequestId: 'uji-refrakto-satuan',
        );
        addTearDown(s.dispose);

        isiSemua(s, s.bentuk.bagian.firstWhere((b) => b.tabel.isNotEmpty).kode);
        expect(
          s.daftarSelCek(),
          isNotEmpty,
          reason: 'prasyarat: foto mendarat',
        );
        expect(s.selKamera, isNotEmpty);

        s.satuan = '°Brix';
        expect(s.daftarSelCek(), isEmpty, reason: 'tabel baru kosong');
        expect(s.selKamera, isEmpty, reason: 'identitas gerbang ikut dibuang');

        s.satuan = 'n20D';
        expect(s.daftarSelCek(), isEmpty);
        expect(s.selKamera, isEmpty);

        final t = s.bentuk.bagian.expand((b) => b.tabel).first;
        final st = s.titik[s.kunciBaris(s.barisTabel(t), 0, t)]!;
        st.kotak(t.kunciTabel, t.kolom.first.kode, 0).text = '99,9';

        expect(
          s.daftarSelCek(),
          isEmpty,
          reason: 'ketikan tangan di kunci bekas sel kamera bukan hasil kamera',
        );
        expect(s.jumlahPerluCek, 0);
      },
    );

    /// Bentuk dirakit: kunci baris °Brix ikut memuat 1,39986 yang juga titik
    /// n20D. Satu-satunya contoh lembar dengan `baris_per_satuan` (Refractometer)
    /// titiknya TIDAK beririsan, jadi pemangkasan kunci yatim saja sudah
    /// membersihkan gerbang; irisan inilah yang hanya tertangkap kalau
    /// pembangunan ulang tanpa isian MEMBUANG catatan gerbang secara eksplisit.
    test(
      'kunci baris yang selamat ke satuan lain tidak mewarisi catatan lama',
      () {
        final m = contohBentukLembarKerjaRefractometer();
        for (final b in m['bagian'] as List) {
          for (final t in ((b as Map)['tabel'] as List?) ?? const []) {
            (t as Map<String, dynamic>)['baris_per_satuan'] = <String, dynamic>{
              ...(t['baris_per_satuan'] as Map<String, dynamic>),
              '°Brix': <Map<String, dynamic>>[
                {'titik_ukur': 2.5, 'label': '2,5'},
                {'titik_ukur': 1.39986, 'label': '1,39986'},
              ],
            };
          }
        }

        final s = LembarKerjaState(
          bentuk: LembarKerja.fromJson(m),
          clientRequestId: 'uji-refrakto-irisan',
        );
        addTearDown(s.dispose);

        isiSemua(s, s.bentuk.bagian.firstWhere((b) => b.tabel.isNotEmpty).kode);
        expect(
          s.daftarSelCek(),
          isNotEmpty,
          reason: 'prasyarat: foto mendarat',
        );

        s.satuan = '°Brix';
        expect(
          s.titik.keys,
          contains(1.39986),
          reason: 'prasyarat: kunci selamat',
        );
        expect(
          s.selKamera,
          isEmpty,
          reason: 'isi sel dibuang, catatannya juga',
        );

        final t = s.bentuk.bagian.expand((b) => b.tabel).first;
        final baris = s.barisTabel(t);
        final i = baris.indexWhere((b) => b.titikUkur == 1.39986);
        s.titik[s.kunciBaris(baris, i, t)]!
                .kotak(t.kunciTabel, t.kolom.first.kode, 0)
                .text =
            '99,9';

        expect(
          s.daftarSelCek(),
          isEmpty,
          reason: 'ketikan tangan di kunci yang selamat bukan hasil kamera',
        );
        expect(s.jumlahPerluCek, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // KONTRAK petakanUlang: kunci yang TIDAK disebut peta tetap di tempatnya —
  // aturan yang sama dengan penyalinan isian di `_bangunTitik`.
  //
  // Tidak ada alat nyata yang mencampur tabel berpasangan dan tidak berpasangan
  // (dicek di semua contoh lembar), jadi bentuknya DIRAKIT: Thermocouple
  // (berpasangan, kunci = posisi) + satu bagian tabel Tits (kunci = nominal).
  // Peta aturTitik hanya memuat kunci berpasangan; sel Tits tidak boleh
  // lenyap dari gerbang.
  // ---------------------------------------------------------------------------
  group('bentuk campuran (dirakit): kunci yang tak disebut peta tetap', () {
    Map<String, dynamic> bentukCampuran() {
      final m = contohBentukLembarKerjaThermocouple();
      final tits = contohBentukLembarKerjaTits();
      final bagianTits = Map<String, dynamic>.of(
        (tits['bagian'] as List).firstWhere(
              (b) =>
                  (b as Map)['tabel'] is List &&
                  (b['tabel'] as List).isNotEmpty,
            )
            as Map<String, dynamic>,
      )..['kode'] = 'hasil_nonpasangan';
      m['bagian'] = [...(m['bagian'] as List), bagianTits];

      return m;
    }

    test(
      'sel tabel tak berpasangan tetap digerbang saat titik berpasangan diatur',
      () {
        final s = LembarKerjaState(
          bentuk: LembarKerja.fromJson(bentukCampuran()),
          clientRequestId: 'uji-campuran',
        );
        addTearDown(s.dispose);

        final berpasangan = s.bentuk.bagian
            .expand((b) => b.tabel)
            .where((t) => t.berpasangan)
            .toList();
        final biasa = s.bentuk.bagian
            .expand((b) => b.tabel)
            .where((t) => !t.berpasangan)
            .toList();
        expect(
          berpasangan,
          isNotEmpty,
          reason: 'prasyarat: ada tabel berpasangan',
        );
        expect(biasa, isNotEmpty, reason: 'prasyarat: ada tabel biasa');

        isiSemua(s, 'hasil', maksBaris: 3);
        isiSemua(s, 'hasil_nonpasangan', maksBaris: 3);

        final awal = statusPerIsi(s);
        final teksBiasa = {
          for (final t in biasa)
            for (var i = 0; i < 3; i++)
              for (final k in t.kolom)
                s.titik[s.kunciBaris(s.barisTabel(t), i, t)]!.teksKotakJikaAda(
                  t.kunciTabel,
                  k.kode,
                  0,
                )!,
        };
        expect(teksBiasa, isNotEmpty);
        expect(
          awal.keys.toSet().containsAll(teksBiasa),
          isTrue,
          reason: 'prasyarat: sel tabel biasa digerbang',
        );

        final nilai = [
          for (final r in s.barisTabel(berpasangan.first)) r.titikUkur,
        ];
        s.aturTitik(nilai.skip(1).toList(), bagian: 'hasil');

        final sesudah = statusPerIsi(s);
        for (final teks in teksBiasa) {
          expect(
            sesudah[teks],
            awal[teks],
            reason:
                'sel tabel biasa "$teks" tidak ikut bergeser: tetap digerbang',
          );
        }
      },
    );
  });
}
