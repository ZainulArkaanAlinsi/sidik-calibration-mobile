import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Foto satu tabel yang Repeat-nya TURUN KE BAWAH — bentuk Conductivity
/// (`SIDIK-FM-CAL-0510`).
///
/// Yang ditiru tata letak kertasnya: kolom Repeat di kiri turun ke bawah, dan
/// slot larutan (`84`, `1413 µS`, `5000 µS`, `80000 µS`) berjajar ke kanan —
/// kebalikan dari bentuk pH/spektro yang dijaga `peta_tabel_foto_test.dart`.
///
/// **Kenapa perlu jalur sendiri, bukan `petakan` yang dikasih tulisan lain:**
/// di bentuk ini dua jangkarnya ada di SUMBU yang beda. `petakan` nyari nilai
/// standar turun ke bawah dan kepala Repeat ke samping; di kertas ini persis
/// kebalik. Dijalanin apa adanya, hasilnya nol sel dan seluruh angkanya
/// kebuang — bukan "meleset dikit".
///
/// Tulisan kepala slot yang dicari itu yang TERCETAK (`1413 µS`), sementara
/// titik yang dihitung `1412`: kertas `Rev.5` (Des 2023) masih nominal botol
/// lama, master pindah ke `25 / 1412 / 111` pada April 2024.
void main() {
  TeksTerbaca kata(String teks, double x, double y) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
  );

  // Tata letak tabelnya, dalam piksel citra.
  const xRepeat = 60.0;
  const xSlot = [300.0, 560.0, 820.0, 1080.0];

  /// Kolom suhu ada di kanan kolom pembacaan, di dalam slot yang sama.
  const selaSuhu = 120.0;

  const ySlot = 60.0;
  const yResolusi = 100.0;
  const ySatuan = 150.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  const slot = <SlotFoto>[
    (
      titikUkur: 25.0,
      kepala: ['84'],
      labelField: {'pembacaan': 'µS/cm', 'suhu': '°C'},
    ),
    (
      titikUkur: 1412.0,
      kepala: ['1413 µS', '1.413 mS'],
      labelField: {'pembacaan': 'µS/cm', 'suhu': '°C'},
    ),
    (
      titikUkur: 111.0,
      kepala: ['5000 µS', '5 mS'],
      labelField: {'pembacaan': 'mS/cm', 'suhu': '°C'},
    ),
    // Kotaknya ada di kertas, larutannya belum kedaftar di master.
    (
      titikUkur: null,
      kepala: ['80000 µS', '80 mS'],
      labelField: {'pembacaan': 'mS/cm', 'suhu': '°C'},
    ),
  ];

  /// Pembacaan per slot, urut Repeat 1..5.
  const bacaan = [
    ['25,1', '25,0', '25,2', '25,1', '25,0'],
    ['1412', '1411', '1413', '1412', '1410'],
    ['111', '110', '111', '112', '111'],
  ];

  const suhu = ['22,1', '22,2', '22,3', '22,2', '22,1'];

  const ulang = [1, 2, 3, 4, 5];

  /// Kepala slot di kertas itu sel yang KEGABUNG di atas dua kolomnya, jadi
  /// tulisannya jatuh di tengah bloknya — bukan rata kiri di kolom pembacaan.
  TeksTerbaca kepalaSlot(String teks, int i) =>
      kata(teks, xSlot[i] + selaSuhu / 2 - teks.length * 7, ySlot);

  /// Susun hasil OCR tabel utuh. [rusak] menghapus teks tertentu — dipakai buat
  /// menguji apa yang terjadi waktu jangkarnya nggak kebaca.
  List<TeksTerbaca> tabel({
    Set<String> rusak = const {},
    List<String> Function(int)? kepalaRepeat,
    bool slotMatiTerisi = false,
  }) {
    final buat = kepalaRepeat ?? PetaTabelFoto.kepalaBawaan;

    final hasil = <TeksTerbaca>[
      kata('Repeat', xRepeat, ySatuan),

      // Kepala slot + baris resolusi + label satuan.
      for (var i = 0; i < slot.length; i++) ...[
        if (!rusak.contains(slot[i].kepala.first))
          kepalaSlot(slot[i].kepala.first, i),
        kata('0,1', xSlot[i], yResolusi),
        kata(slot[i].labelField['pembacaan']!, xSlot[i], ySatuan),
        kata('°C', xSlot[i] + selaSuhu, ySatuan),
      ],
    ];

    for (var r = 0; r < ulang.length; r++) {
      final y = yBarisPertama + r * tinggiBaris;
      final kepala = buat(r + 1).first;

      if (!rusak.contains(kepala)) hasil.add(kata(kepala, xRepeat, y));

      for (var i = 0; i < bacaan.length; i++) {
        hasil
          ..add(kata(bacaan[i][r], xSlot[i], y))
          ..add(kata(suhu[r], xSlot[i] + selaSuhu, y));
      }

      if (slotMatiTerisi) {
        hasil.add(kata('79999', xSlot[3], y));
      }
    }

    return hasil;
  }

  Map<String, String> peta(HasilPetaTabel h) => {
    for (final s in h.sel) '${s.titikUkur}|${s.repeatNo}|${s.fieldId}': s.teks,
  };

  test('tiap angka mendarat di slot & Repeat yang benar', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(),
      slot: slot,
      pengulangan: ulang,
    );

    expect(hasil.sel, hasLength(30), reason: '3 slot hidup × 5 Repeat × 2 kolom');
    expect(hasil.angkaTakTerpetakan, 0);

    final p = peta(hasil);

    for (final r in ulang) {
      expect(p['25.0|$r|pembacaan'], bacaan[0][r - 1]);
      expect(p['1412.0|$r|pembacaan'], bacaan[1][r - 1]);
      expect(p['111.0|$r|pembacaan'], bacaan[2][r - 1]);

      // Suhu tiap slot dibaca dari kolomnya sendiri, bukan dibagi rata.
      expect(p['25.0|$r|suhu'], suhu[r - 1]);
      expect(p['1412.0|$r|suhu'], suhu[r - 1]);
      expect(p['111.0|$r|suhu'], suhu[r - 1]);
    }
  });

  /// Baris resolusi (`0,1`) dan nominal botol di kepala slot (`84`) dua-duanya
  /// angka yang sah dan dua-duanya BUKAN pembacaan. Dilewat tanpa ikut
  /// kehitung "nggak keangkut" — kalau ikut, tiap foto yang sempurna pun
  /// kelihatan seperti kehilangan angka.
  test('kepala tabel & baris resolusi nggak dianggap pembacaan', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(),
      slot: slot,
      pengulangan: ulang,
    );

    expect(hasil.angkaTakTerpetakan, 0);
    expect(peta(hasil).values, isNot(contains('0,1')));
    expect(peta(hasil).values, isNot(contains('84')));
  });

  /// Slot yang di kertas ada kotaknya tapi di master belum ada larutannya tetap
  /// DIJANGKAR — supaya angkanya kebuang, bukan ketarik ke slot sebelahnya.
  test('angka di slot mati dibuang, bukan mendarat di tetangganya', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(slotMatiTerisi: true),
      slot: slot,
      pengulangan: ulang,
    );

    expect(hasil.sel, hasLength(30));
    expect(hasil.angkaTakTerpetakan, 5, reason: '5 angka di slot 80000 µS');
    expect(peta(hasil).values, isNot(contains('79999')));
  });

  /// Kertasnya nyetak "ceklis salah satu" — dua tulisan buat botol yang sama.
  /// Yang mana pun yang kebaca OCR, kolomnya tetap ketemu.
  test('slot dua varian ketemu lewat tulisan mana pun', () {
    final terbaca = [
      for (final t in tabel())
        if (t.teks == '1413 µS')
          (teks: '1.413 mS', kotak: t.kotak)
        else
          t,
    ];

    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: terbaca,
      slot: slot,
      pengulangan: ulang,
    );

    expect(peta(hasil)['1412.0|1|pembacaan'], '1412');
  });

  /// Kepala Repeat yang tercetak beda per formulir. Yang dipakai apa yang
  /// dikirim pemanggil, bukan dipatok di dalam mesinnya.
  test('kepala Repeat ikut yang dikirim pemanggil', () {
    List<String> repeatPanjang(int r) => ['Repeat $r'];

    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(kepalaRepeat: repeatPanjang),
      slot: slot,
      pengulangan: ulang,
      kepalaPengulangan: {for (final r in ulang) r: repeatPanjang(r)},
    );

    expect(hasil.sel, hasLength(30));
    expect(peta(hasil)['25.0|2|pembacaan'], '25,0');
  });

  /// Bawaannya nerima DUA bentuk tulisan sekaligus — `Xn` yang dicetak
  /// `ocr:cetak-lembar`, dan `Repeat n` yang dipakai formulir lain. Bentuk
  /// kertas lama lab belum dipastikan, dan nerima dua-duanya nggak nambah
  /// risiko salah taruh: dua tulisan itu cuma ada di kepala kolom.
  test('bawaan nerima `Repeat n` maupun `Xn`', () {
    for (final buat in <List<String> Function(int)>[
      (r) => ['X$r'],
      (r) => ['Repeat $r'],
    ]) {
      final hasil = const PetaTabelFoto().petakanKeBawah(
        terbaca: tabel(kepalaRepeat: buat),
        slot: slot,
        pengulangan: ulang,
      );

      expect(hasil.sel, hasLength(30), reason: 'kepala ${buat(1).first}');
      expect(peta(hasil)['25.0|2|pembacaan'], '25,0');
    }
  });

  /// ML Kit kadang ngerapetin `Repeat 1` jadi `Repeat1`. Kepala kolom yang
  /// gagal cocok gara-gara satu spasi bikin SELURUH kolomnya nggak keisi.
  test('spasi di kepala Repeat diabaikan', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(kepalaRepeat: (r) => ['Repeat$r']),
      slot: slot,
      pengulangan: ulang,
    );

    expect(hasil.sel, hasLength(30));
  });

  /// Tulisan kepala yang nggak kekenal = kolom itu nggak punya jangkar.
  ///
  /// Termasuk **nomor polos**: di kertas yang kepala kolomnya cuma `1`, angka
  /// itu juga bisa pembacaan atau nomor urut, jadi sengaja nggak ikut diterima.
  /// Nol sel lebih baik daripada jangkar yang direbut angka lain.
  test('kepala Repeat yang salah bikin NOL sel, bukan tebakan urutan', () {
    for (final buat in <List<String> Function(int)>[
      (r) => ['Ulangan $r'],
      (r) => ['$r'],
    ]) {
      final hasil = const PetaTabelFoto().petakanKeBawah(
        terbaca: tabel(kepalaRepeat: buat),
        slot: slot,
        pengulangan: ulang,
      );

      expect(hasil.sel, isEmpty, reason: 'kepala ${buat(1).first}');
      expect(hasil.repeatKetemu, isEmpty);
      expect(hasil.angkaTakTerpetakan, greaterThan(0));
    }
  });

  /// Satu baris yang jangkarnya nggak kebaca cuma bikin baris ITU kosong —
  /// baris lain nggak boleh ikut geser buat menutupinya.
  test('satu jangkar Repeat hilang: barisnya kosong, sisanya utuh', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(rusak: const {'X2'}),
      slot: slot,
      pengulangan: ulang,
    );

    final p = peta(hasil);

    expect(hasil.repeatKetemu, [1, 3, 4, 5]);
    expect(p['25.0|1|pembacaan'], '25,1');
    expect(p['25.0|3|pembacaan'], '25,2');
    expect(p.keys.where((k) => k.contains('|2|')), isEmpty);
  });

  /// **Kegagalan paling mahal di bentuk ini**, dan satu-satunya yang nggak
  /// ngasih gejala: label kolom pembacaan (`µS/cm`) nggak kebaca sementara
  /// `°C` kebaca. Yang terdekat dari SETIAP angka jadi `°C`, dan seluruh
  /// pembacaan slot itu mendarat rapi di kolom suhu — kotaknya terisi,
  /// jumlahnya pas, dan baru ketahuan aneh di sertifikat.
  test('label kolom pembacaan hilang: slotnya kosong, bukan masuk kolom suhu', () {
    // Kolom suhu slot itu ikut dikosongin — kalau nggak, pembacaan dan suhu
    // sama-sama jatuh ke `suhu`, bentrok, dan dibuang penjaga sel-kembar. Yang
    // diuji di sini penjaga yang LAIN: satu kolom sendirian, tanpa lawan
    // bentrok, tetap nggak boleh mendarat di kolom yang salah.
    final terbaca = [
      for (final t in tabel())
        if (!(t.teks == 'µS/cm' && t.kotak.left == xSlot[1]) &&
            !(t.kotak.left == xSlot[1] + selaSuhu &&
                t.kotak.top >= yBarisPertama))
          t,
    ];

    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: terbaca,
      slot: slot,
      pengulangan: ulang,
    );

    final p = peta(hasil);

    // Slot `1413 µS` nggak boleh nyumbang satu sel pun — pembacaan MAUPUN suhu.
    expect(p.keys.where((k) => k.startsWith('1412.0|')), isEmpty);
    expect(hasil.angkaTakTerpetakan, 5, reason: '5 pembacaan slot itu dibuang');

    // Slot lain yang labelnya utuh tetap keisi penuh.
    expect(p.keys.where((k) => k.startsWith('25.0|')), hasLength(10));
    expect(p.keys.where((k) => k.startsWith('111.0|')), hasLength(10));
  });

  /// Kepala slot bentuk ini bisa angka polos (`84`), dan angka itu bisa muncul
  /// lagi di badan tabel sebagai pembacaan. Kepala selalu di ATAS pembacaannya,
  /// jadi yang paling atas yang menang — bukan yang kebetulan kebaca duluan.
  test('kepala slot berupa angka nggak direbut angka nyasar di kolom lain', () {
    // `84` nyangkut lagi di badan tabel, di kolom slot PALING KANAN — dan
    // ditaruh paling depan di daftar hasil OCR, posisi yang dulu menang.
    //
    // Kalau yang itu yang jadi jangkar, kolom `84` pindah ~780px ke kanan;
    // jarak antar kolom ikut mengkerut, dan seluruh tabel gagal dipetakan.
    final terbaca = [
      kata('84', xSlot[3], yBarisPertama),
      ...tabel(),
    ];

    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: terbaca,
      slot: slot,
      pengulangan: ulang,
    );

    expect(hasil.sel, hasLength(30));
    expect(peta(hasil)['25.0|1|pembacaan'], '25,1');
    expect(peta(hasil)['111.0|5|suhu'], suhu[4]);

    // Yang nyasar itu sendiri kebuang: slot paling kanan nggak punya titik.
    expect(hasil.angkaTakTerpetakan, 1);
  });

  /// Slot yang kepalanya nggak kebaca sama sekali: kolomnya nggak punya
  /// jangkar, dan angkanya nggak boleh ketarik ke slot sebelahnya.
  test('satu kepala slot hilang: kolomnya kosong, bukan pindah tetangga', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: tabel(rusak: const {'1413 µS'}),
      slot: slot,
      pengulangan: ulang,
    );

    final p = peta(hasil);

    expect(p.keys.where((k) => k.startsWith('1412.0|')), isEmpty);
    expect(p['25.0|1|pembacaan'], '25,1');
    expect(p['111.0|1|pembacaan'], '111');
  });
}
