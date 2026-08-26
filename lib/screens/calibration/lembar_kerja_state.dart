import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

import '../../core/utils/angka.dart';
import '../../models/calibration_detail.dart'
    show IsianTeknisi, MeasurementResult, RawMeasurement, TahapPembacaan;
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../core/utils/jam_lembar.dart';
import '../../models/lembar_kerja.dart';
import 'grid_sensor_state.dart';
import '../../models/lembar_kerja_submission.dart';
import '../../models/worksheet_scan.dart';
import '../../services/gabung_tabel.dart';
import '../../services/peta_tabel_foto.dart';

/// Angka di lembar kerja diketik teknisi lapangan, yang kadang pakai koma
/// (`22,2`) karena itu yang dipakai di formulir kertasnya. Dua-duanya
/// diterima; yang dikirim ke backend selalu titik.
double? parseAngka(String teks) =>
    double.tryParse(teks.trim().replaceAll(',', '.'));

/// Balikin angka ke bentuk yang enak diketik ulang: `22.5`, bukan `22.500000`
/// — dan bilangan bulat tanpa `.0` yang bikin teknisi ngira ada desimal
/// tersembunyi.
String formatAngka(double nilai) => nilai == nilai.roundToDouble()
    ? nilai.toStringAsFixed(0)
    : '$nilai';

/// Penanda yang nempel di satu sel tabel. Tiga keadaan, dua arti yang beda.
enum TandaSel {
  tidakAda,

  /// Diisi hasil pindai dengan vonis server kuning/merah — **saran** buat
  /// dicek. Nggak ngunci apa pun.
  keyakinanRendah,

  /// Admin minta sel INI dibetulin (kode sel di `revisi_field`) — **perintah**.
  ///
  /// Menang atas [keyakinanRendah] kalau dua-duanya kena sel yang sama: yang
  /// satu tebakan mesin, yang satu keputusan orang yang mau nandatangani
  /// sertifikatnya.
  revisi,
}

/// Satu baris di layar konfirmasi sebelum kirim: larutan standar, berapa kotak
/// yang keisi, dan rata-rata pembacaan After adjustment.
///
/// **Sengaja NGGAK bawa koreksi.** Koreksi = nilai standar − rata-rata, dan
/// nilai standar buat pH itu hasil koreksi kurva suhu yang dihitung server
/// (buffer 7 di 22,2 °C jadi 6,9889072, bukan 7,00). Kalau layar ini nebak
/// sendiri pakai nominal, angkanya beda dari yang nanti kecetak di sertifikat —
/// bikin masalah baru "layar vs PDF beda" persis yang lagi diberesin. Rata-rata
/// doang udah cukup buat tujuannya: teknisi lihat `1,83 → 1,90` dan sadar dia
/// salah ketik.
class RingkasanTitik {
  const RingkasanTitik({
    required this.label,
    required this.satuan,
    required this.terisi,
    required this.total,
    required this.desimal,
    this.rataRata,
  });

  /// Label larutan standar seperti yang tercetak di lembar kerja (`1,83`).
  final String label;
  final String satuan;

  /// Berapa kotak pembacaan After adjustment yang keisi, dari [total].
  final int terisi;
  final int total;

  /// Desimal buat nampilin [rataRata].
  final int desimal;

  /// `null` = baris ini belum diisi sama sekali.
  final double? rataRata;

  bool get kosong => rataRata == null;

  /// Ada kotak yang dilewat — bukan salah, tapi hampir selalu nggak disengaja.
  bool get adaYangKosong => terisi > 0 && terisi < total;
}

/// Isian satu baris tabel hasil: satu larutan standar, dua tahap
/// (before & after adjustment), masing-masing n pengulangan × 2 kolom.
///
/// Controller-nya dibikin sekali di sini dan hidup selama layar kebuka —
/// bukan digenerate ulang tiap `build()`, yang bakal bikin isian keapus tiap
/// kali layar digambar ulang.
class TitikState {
  TitikState({
    required this.titikUkur,
    required this.label,
    required this.jumlahPengulangan,
    required this.satuan,
    this.tipe,
    this.desimal,
    this.standardIdTercetak,
    this.standardNama,
    this.eksklusifDengan,
    this.onKetik,
  }) : standardId = standardIdTercetak,
       _kotak = {};

  /// Dipanggil tiap ANGKA di baris ini berubah.
  ///
  /// Sel angka nggak punya `onChanged` — sengaja: rebuild seluruh formulir tiap
  /// ketukan tombol bikin tabel 87 kotak (Spectrophotometer) tersendat di HP.
  /// Jadi kabarnya lewat listener controller, dan yang dengerin milih sendiri
  /// mau ngapain. Layar cuma pakai buat NJADWALIN pratinjau, tanpa `setState`.
  final VoidCallback? onKetik;

  final double titikUkur;

  /// Jenis isian baris ini kalau BUKAN angka — sejauh ini cuma `jam`, baris
  /// `Time` di lembar Autoklaf. `null` = angka biasa, seperti seluruh baris di
  /// delapan alat lain.
  final String? tipe;
  final String label;
  final int jumlahPengulangan;

  /// Satuan pembacaan yang ikut ke `measurements[].satuan`.
  ///
  /// **Bisa berubah di tengah jalan**, beda dari kolom lain di kelas ini. Satu
  /// refractometer bisa nampilin n20D atau °Brix, dan teknisi milihnya di
  /// formulir ("7. Satuan Refracto") — lihat [LembarKerjaState.satuan]. Alat
  /// lain nggak pernah nyentuh ini: bentuk lembar kerjanya nggak punya kolom
  /// itu, jadi isinya tetap `bentuk.satuan` dari awal sampai kirim.
  String satuan;

  /// Jumlah desimal resolusi titik ini (Turbidimeter 2/1/0). `null` = resolusi
  /// seragam. Dipakai buat mad pembacaan hasil kamera ke resolusi titik.
  final int? desimal;

  /// `titik_ukur` baris yang MENIADAKAN baris ini, atau null.
  ///
  /// Titik tengah Conductivity punya dua bentuk buat botol yang sama —
  /// `1412 µS/cm` & `1,412 mS/cm`. Yang diisi salah satu; kalau dua-duanya
  /// keisi, sistem nerima dua nilai buat satu botol.
  final double? eksklusifDengan;

  /// Ada pembacaan yang diisi tapi kolom suhunya di baris yang sama kosong?
  ///
  /// Nilai acuan larutan Conductivity DIGESER ikut suhu, jadi pembacaan tanpa
  /// suhu bukan sekadar data kurang — di master Excel-nya, kolom suhu kosong
  /// bikin polinomial dievaluasi pada T=0 dan keluar `0,738 mS/cm`: angka yang
  /// kelihatan wajar, bukan error, dan ikut tercetak di sertifikat.
  ///
  /// Dicek per (tahap, nomor repeat) — bukan per baris — supaya Repeat 3 yang
  /// bolong ketahuan walau Repeat 1 & 2 lengkap.
  bool get adaPembacaanTanpaSuhu {
    for (final entry in _kotak.entries) {
      final bagian = entry.key.split('|');
      if (bagian.length != 3 || bagian[1] != 'pembacaan') continue;
      if (entry.value.text.trim().isEmpty) continue;

      // Tabel yang NGGAK punya kolom suhu sama sekali dilewat.
      //
      // Turbidimeter & Chlorine dibaca nominal — lembarnya emang cuma satu
      // kolom. Tanpa penjaga ini tiap pembacaan mereka kebaca "suhunya
      // kosong" dan lembarnya nggak akan pernah bisa dikirim.
      final adaKolomSuhu = _kotak.keys.any(
        (k) => k.startsWith('${bagian[0]}|suhu|'),
      );
      if (!adaKolomSuhu) continue;

      final suhu = _kotak['${bagian[0]}|suhu|${bagian[2]}'];
      if (suhu == null || suhu.text.trim().isEmpty) return true;
    }

    return false;
  }

  /// Ada pembacaan yang meleset SATU ORDE atau lebih dari nominal barisnya.
  ///
  /// Nangkep salah satuan & koma kegeser, dan sengaja diadu ke [titikUkur]
  /// baris ini — bukan ke rentang alat. Dua-duanya udah dalam satuan yang SAMA
  /// PERSIS ([satuan] baris), jadi nggak perlu konversi apa pun, dan aturan
  /// metrologi di backend nggak perlu disalin ke sini buat melenceng belakangan.
  ///
  /// Kasus nyatanya sesi 53 (12 Agt 2026): teknisi milih baris varian
  /// **1,412 mS/cm** lalu ngetik **1413** — angka µS/cm, 1000× lipat. Backend
  /// ngitung Error = 1413 − 1,412 = 1411,588 dan itu nyampe admin sebagai
  /// lembar yang kelihatan sehat. Peringatan `pembacaan_di_luar_rentang` emang
  /// nyala 7×, tapi levelnya cuma peringatan dan orang yang bisa mbenerin —
  /// teknisi yang lagi berdiri di depan alatnya — udah nggak di situ.
  ///
  /// Faktor 10, bukan lebih ketat: alat yang beneran rusak parah masih boleh
  /// dikalibrasi dan hasilnya masih boleh jelek. Yang ditahan itu angka yang
  /// mustahil datang dari alat yang lagi diukur di titik ini.
  bool get adaPembacaanJauhDariTitik {
    // Nominal 0 nggak punya orde — nggak ada yang bisa dibandingin.
    if (titikUkur == 0) return false;

    for (final entry in _kotak.entries) {
      final bagian = entry.key.split('|');
      if (bagian.length != 3 || bagian[1] != 'pembacaan') continue;

      final nilai = parseAngka(entry.value.text);
      if (nilai == null) continue;

      final rasio = nilai.abs() / titikUkur.abs();
      if (rasio >= 10 || rasio <= 0.1) return true;
    }

    return false;
  }


  /// Satu Repeat yang jauh menyimpang dari Repeat LAIN di baris yang sama.
  ///
  /// Beda dari [adaPembacaanJauhDariTitik], dan bedanya menentukan: yang itu
  /// mengadu ke NOMINAL titiknya (nangkep koma kegeser, 1000× lipat), yang ini
  /// mengadu antar-pembacaan (nangkep DIGIT KETUKER).
  ///
  /// Kejadian nyata `CAL/2026/08/0043`: titik 738,5 diketik
  /// `738,63 / 783,52 / 738,52`. `783,52` itu `738,52` dengan digit 3 & 8
  /// tertukar — cuma 6% dari nominalnya, jadi penjaga orde lolos mulus. Tapi
  /// STDEV baris itu meledak, dan buat alat yang U95-nya lahir per KELOMPOK
  /// (Spectrophotometer) satu angka itu menaikkan U95 sembilan titik saudaranya
  /// dari 0,40 nm ke 84,84 nm — 212× CMC lab. Sertifikatnya tetap terbit.
  ///
  /// Ambangnya dari RESOLUSI alat, bukan persen: alat resolusi 0,01 nm yang
  /// tiga bacaannya beda 45 nm itu mustahil, sementara beda 45 di alat
  /// resolusi 1 masih wajar. Faktor 1000 sengaja longgar — yang dicari salah
  /// ketik, bukan alat yang kurang stabil.
  bool get adaRepeatMenyimpang {
    final nilai = <double>[];

    for (final e in _kotak.entries) {
      final bagian = e.key.split('|');
      if (bagian.length != 3 || bagian[1] != 'pembacaan') continue;

      final n = parseAngka(e.value.text);
      if (n != null) nilai.add(n);
    }

    // Butuh minimal tiga: dengan dua angka, nggak ada cara tahu mana yang
    // nyasar — dua-duanya sama-sama "beda dari yang satunya".
    if (nilai.length < 3) return false;

    final urut = [...nilai]..sort();
    final tengah = urut[urut.length ~/ 2];

    // Sebaran yang masih masuk akal buat alat seresolusi ini.
    final batas = (desimal == null ? 0.01 : _langkah(desimal!)) * 1000;

    return nilai.any((n) => (n - tengah).abs() > batas);
  }

  static double _langkah(int desimal) {
    var l = 1.0;
    for (var i = 0; i < desimal; i++) {
      l /= 10;
    }

    return l;
  }

  /// Standar buffer khusus titik ini (buffer 4/7/10 beda-beda).
  ///
  /// Terisi otomatis dari pasangan tercetak di formulir; teknisi cuma nyentang
  /// buat mastiin larutan itu yang beneran dia pakai. Bisa ditimpa manual —
  /// kalau botolnya habis dan dia pakai lot lain, itu tetap harus bisa
  /// dicatat, tapi jadi keputusan sadar, bukan default yang gampang salah.
  int? standardId;

  /// Pasangan tercetak titik ini, dipegang terpisah dari [standardId] yang
  /// bisa berubah. Dipakai layar buat tau centangnya lagi nunjuk larutan yang
  /// tercetak atau udah ditimpa manual. Null = titik ini nggak punya pasangan.
  final int? standardIdTercetak;

  /// Nama standar pasangannya dari formulir, buat label centangnya. Nggak ikut
  /// berubah waktu [standardId] ditimpa manual — yang manual ambil namanya
  /// dari master standar.
  final String? standardNama;

  /// Centangnya lagi nunjuk larutan yang tercetak di formulir?
  bool get standarTercetakDipakai =>
      standardIdTercetak != null && standardId == standardIdTercetak;

  /// Kunci: `tahap|kolom|indexPengulangan`.
  final Map<String, TextEditingController> _kotak;

  TextEditingController kotak(String tahap, String kolom, int index) =>
      _kotak.putIfAbsent('$tahap|$kolom|$index', () {
        final controller = TextEditingController();
        if (onKetik != null) controller.addListener(onKetik!);

        return controller;
      });

  /// Sudah ada isian apa pun di baris ini?
  bool get adaIsian =>
      _kotak.values.any((c) => c.text.trim().isNotEmpty) || standardId != null;

  /// Ada ANGKA yang diketik di baris ini? Beda dari [adaIsian], dan bedanya
  /// penting: [adaIsian] ikut ngitung `standardId`, yang KEISI SEJAK AWAL dari
  /// standar tercetak lembar kerja.
  ///
  /// Dipakai buat ngunci baris pasangan. Kalau pakai [adaIsian], dua varian
  /// satuan langsung saling ngunci begitu lembarnya kebuka — sebelum teknisi
  /// ngetik apa pun — dan nyentang standar malah MEMATIKAN barisnya.
  bool get adaPembacaan =>
      _kotak.values.any((c) => c.text.trim().isNotEmpty);

  /// Salinan isian sel baris ini, buat diselamatkan waktu BENTUK lembar
  /// berubah (mis. teknisi milih alat, dan baris varian satuan menyusut).
  ///
  /// Yang kosong nggak ikut disalin — biar nempelnya nggak nimpa apa pun.
  Map<String, String> salinKotak() => {
    for (final e in _kotak.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text,
  };

  /// Kebalikan [salinKotak]. Kunci yang bentuknya nggak dikenal dilewat, bukan
  /// bikin crash — salinan bisa datang dari bentuk lembar yang beda.
  void tempelKotak(Map<String, String> dari) {
    for (final e in dari.entries) {
      final bagian = e.key.split('|');
      if (bagian.length != 3) continue;
      final index = int.tryParse(bagian[2]);
      if (index == null) continue;
      kotak(bagian[0], bagian[1], index).text = e.value;
    }
  }

  List<double?> _kolom(String tahap, String kolom) => List<double?>.generate(
    jumlahPengulangan,
    // Sel yang belum diisi jadi null, BUKAN dibuang — nomor Repeat-nya nggak
    // boleh geser. Lihat docblock TitikLembarKerja.
    (i) => parseAngka(kotak(tahap, kolom, i).text),
  );

  TitikLembarKerja toSubmission() {
    final titik = TitikLembarKerja(
      titikUkur: titikUkur,
      jumlahPengulangan: jumlahPengulangan,
      standardId: standardId,
      satuan: satuan.isEmpty ? null : satuan,
    );

    void salin(List<double?> dari, List<double?> ke) {
      for (var i = 0; i < ke.length && i < dari.length; i++) {
        ke[i] = dari[i];
      }
    }

    salin(_kolom('sesudah_adjustment', 'pembacaan'), titik.pembacaan);
    salin(_kolom('sesudah_adjustment', 'suhu'), titik.suhu);
    salin(_kolom('sebelum_adjustment', 'pembacaan'), titik.pembacaanSebelum);
    salin(_kolom('sebelum_adjustment', 'suhu'), titik.suhuSebelum);

    return titik;
  }

  void dispose() {
    for (final c in _kotak.values) {
      c.dispose();
    }
  }
}

/// Isian satu baris "Usage Check".
class UsageCheckState {
  UsageCheckState({required this.standardId, this.dipakai = false})
    : keterangan = TextEditingController();

  final int standardId;
  bool dipakai;
  final TextEditingController keterangan;

  bool get adaIsian => dipakai || keterangan.text.trim().isNotEmpty;

  StandarDicek toSubmission() => StandarDicek(
    standardId: standardId,
    dipakai: dipakai,
    keterangan: keterangan.text,
  );

  void dispose() => keterangan.dispose();
}

/// Seluruh isian lembar kerja.
///
/// Sengaja dipisah dari widget-nya: layar cuma nampilin & manggil, penyusunan
/// payload-nya bisa diuji tanpa merender apa pun.
class LembarKerjaState {
  LembarKerjaState({
    required this.bentuk,
    required this.clientRequestId,
    this.profil,
    DateTime? tanggalKalibrasiAwal,
  }) {
    // Tanggal kalibrasi dikasih nilai awal HARI INI, bukan dibiarin kosong.
    // Ini satu-satunya kolom yang backend tolak kalau kosong waktu dikirim ke
    // admin (`required` di luar draft) — dan bikin teknisi kena 422 gara-gara
    // kolom yang jawabannya hampir selalu "hari ini" itu cuma bikin kesel.
    // Masih bisa dikosongin manual kalau dia mau nyimpen draft.
    tanggal['tanggal_kalibrasi'] = tanggalKalibrasiAwal ?? DateTime.now();

    _selaraskanKotakTeks();
    _bangunTitik();
    _selaraskanGrid();
  }

  /// Kolom yang isinya diketik butuh controller — dan `teks` itu satu-satunya
  /// tempat [spesifikasiAlat] & [kalimat] baca isiannya waktu payload disusun.
  bool _pakaiKotakTeks(FieldLembarKerja f) =>
      !f.turunan &&
      (f.tipe == TipeField.teks ||
          f.tipe == TipeField.teksPanjang ||
          f.tipe == TipeField.angka ||
          // `spesifikasi_alat.*` bertipe pilihan (mis. model & spindle
          // Viscometer) digambar `_BarisSpesifikasi`, bukan `_PilihanTetap`
          // — tanpa controller di sini kotaknya kepilih tapi nilainya nggak
          // pernah masuk `spesifikasiAlat` waktu dikirim.
          //
          // Kolom pilihan BIASA yang bawa daftar pilihannya sendiri juga ikut.
          // Autoklaf yang bikin ini perlu: `satuan_tekanan` & `display_tekanan`
          // nentuin arti angka tekanan (Bar vs Psi vs kPa), dan tanpa
          // controller di sini dua-duanya nggak pernah kekirim — angka
          // tekanannya sampai server tanpa satuan.
          //
          // Yang nggak bawa `pilihan` sengaja dilewat: itu kolom yang isinya
          // ditarik master (`thermohygro_standard_id`, `lokasi`,
          // `equipment.satuan`) dan punya jalur simpannya sendiri.
          (f.tipe == TipeField.pilihan &&
              (f.spesifikasiAlat || f.pilihan.isNotEmpty)));

  /// Samain isi `teks` sama bentuk yang lagi kepasang.
  ///
  /// Dipanggil ULANG dari [gantiBentuk], bukan cuma sekali di konstruktor.
  /// Dulu cuma di konstruktor, dan itu bolong: bentuk yang dipasang belakangan
  /// bisa bawa kolom yang bentuk awal nggak punya, dan kolom itu nggak dapat
  /// controller sama sekali. Akibatnya dua-duanya diam:
  /// `TextField(controller: null)` nampung ketikan di dalam dirinya sendiri
  /// terus ilang waktu dikirim (`teks[kode]` null → kolomnya dilewat), dan
  /// `_BarisSpesifikasi` yang butuh `teks[kode]!` buat dropdown malah matiin
  /// layarnya. Diadu ke bentuk pH → Spectrophotometer, ada 6 kolom yang
  /// kelewat — termasuk kelima `spesifikasi_alat.*` yang tercetak di
  /// sertifikat.
  void _selaraskanKotakTeks() {
    final dipakai = <String>{};

    for (final bagian in bentuk.bagian) {
      // Kolom "di luar kertas" ikut, bukan cuma `field`. Kolomnya nggak ada di
      // lembar cetak tapi tetap dikirim — `display_tekanan` di Autoklaf nentuin
      // cara baca manometer (Digital vs Analog 1/2/3), dan tanpa controller di
      // sini kotaknya nggak pernah digambar dan nilainya nggak pernah kekirim.
      for (final f in [...bagian.field, ...bagian.fieldDiLuarKertas]) {
        if (!_pakaiKotakTeks(f)) continue;
        dipakai.add(f.kode);
        teks.putIfAbsent(f.kode, TextEditingController.new);
      }
    }

    // Kolom yang udah nggak ada di bentuk baru dibuang — controller-nya nggak
    // ada yang megang lagi, dan `spesifikasiAlat` baca dari BENTUK, jadi
    // nyisainnya cuma bikin bocor.
    for (final kode in teks.keys.toList()) {
      if (dipakai.contains(kode)) continue;
      teks.remove(kode)!.dispose();
      _terisiDariAlat.remove(kode);
    }
  }

  /// Bikin baris tabel hasil buat [satuan] yang lagi kepilih.
  ///
  /// Dipisah dari konstruktor karena dipanggil lagi tiap satuan berubah:
  /// Refractometer ngirim titik standar yang beda per skala (1,33659/1,39986
  /// n20D vs 2,5/40 °Brix), jadi tabelnya ikut ganti — bukan cuma labelnya.
  /// Kunci `titik` buat satu baris tabel.
  ///
  /// Delapan alat lama: satu baris = satu TITIK UKUR (pH 4/7/10, Turbidimeter
  /// 1/100/1000), dan `titikUkur`-nya unik — jadi dia sendiri yang jadi kunci,
  /// sama persis kayak sebelum fungsi ini ada. Tabel Before & After yang
  /// urutan barisnya sama tetap berbagi satu `TitikState`, yang memang
  /// disengaja: satu titik memuat dua tahap.
  ///
  /// AUTOKLAF beda, dan bedanya bukan detail: kedelapan barisnya
  /// (`Time`, Disk 1-3, Indikator Suhu, Indikator Pressure, Tekanan atm awal,
  /// Suhu Ruang) itu BESARAN YANG BERBEDA, bukan tiga level dari besaran yang
  /// sama. Backend ngirim `titik_ukur: 0` buat kedelapannya karena emang nggak
  /// ada titik ukurnya. Dikunci pakai `titikUkur`, kedelapan baris itu jatuh
  /// ke satu `TitikState` dan saling nimpa — yang keliatan di layar cuma satu
  /// baris keisi, tujuh sisanya kosong tiap kali tabelnya dibangun ulang.
  ///
  /// Jadi: kunci pakai INDEKS baris cuma kalau `titikUkur`-nya ada yang
  /// kembar. Buat tabel yang titiknya unik — semua alat yang sudah ada —
  /// nilainya persis `titikUkur` seperti dulu, jadi nggak ada satu pun
  /// perilaku lama yang bergeser.
  ///
  /// Indeksnya sejajar antar-tabel karena urutan baris Before & After selalu
  /// sama; kalau suatu hari nggak sama lagi, yang pecah tabelnya, bukan diam-
  /// diam salah pasang.
  double kunciBaris(List<BarisTabelHasil> baris, int index) {
    final titikUnik = baris.map((b) => b.titikUkur).toSet().length;

    return titikUnik == baris.length
        ? baris[index].titikUkur
        : index.toDouble();
  }

  /// Titik ukur yang DIATUR TEKNISI, buat lembar yang `titik_bisa_diubah`.
  ///
  /// Kosong = pakai baris bawaan dari backend. Cuma TITS yang mengisinya:
  /// rentang alat pelanggan beda-beda (sesi contohnya −20…1000 sembilan titik
  /// dan 0…1200 delapan titik), jadi baris yang datang dari backend cuma SARAN.
  ///
  /// Disimpan sebagai daftar angka, bukan daftar [BarisTabelHasil]: yang boleh
  /// diubah teknisi cuma nilainya — satuan, resolusi, dan standar acuannya tetap
  /// milik bentuk.
  final List<double> titikKustom = [];

  /// Baris tabel yang BERLAKU sekarang — bawaan backend, atau hasil susunan
  /// teknisi kalau tabelnya boleh diubah.
  ///
  /// Semua yang butuh daftar baris lewat sini, BUKAN `tabel.barisUntuk()`
  /// langsung: kalau ada satu saja yang masih baca bentuk mentah, tabel yang
  /// digambar dan titik yang dikirim jadi beda isi — dan bedanya nggak
  /// memunculkan error di mana pun.
  List<BarisTabelHasil> barisTabel(TabelHasil tabel, [String? satuanCalon]) {
    final bawaan = tabel.barisUntuk(satuanCalon ?? satuan);

    if (!tabel.titikBisaDiubah || titikKustom.isEmpty) return bawaan;

    // Contoh dipakai buat mewarisi satuan/desimal/tipe/standar — yang berubah
    // cuma NILAI titiknya. Kalau bentuknya nggak punya baris sama sekali
    // (nggak pernah kejadian, tapi murah dijaga), baris kustomnya tetap jalan
    // dengan satuan lembar.
    final contoh = bawaan.isEmpty ? null : bawaan.first;

    return [
      for (final nilai in titikKustom)
        contoh == null
            ? BarisTabelHasil(titikUkur: nilai, label: _labelTitik(nilai))
            : contoh.salinDenganTitik(nilai, _labelTitik(nilai)),
    ];
  }

  /// Label baris buat titik yang diketik teknisi — `-20 °C`, `1000 °C`.
  ///
  /// Mengikuti bentuk label bawaan backend (`rtrim` nol di belakang koma) biar
  /// baris tambahan nggak kelihatan beda dari baris saran.
  String _labelTitik(double nilai) {
    final teks = nilai == nilai.roundToDouble()
        ? nilai.toInt().toString()
        : nilai.toString();
    final satuanBaris = bentuk.satuan;

    return satuanBaris.isEmpty ? teks : '$teks $satuanBaris';
  }

  /// Ganti seluruh daftar titik dengan [nilai], lalu bangun ulang tabelnya
  /// dengan isian yang sudah diketik tetap dipertahankan.
  ///
  /// Duplikat dibuang dan urutannya dinaikkan: dua baris bertitik sama bikin
  /// [kunciBaris] jatuh ke mode indeks, dan dari situ dua baris yang keliatan
  /// sama di layar nunjuk ke kotak yang beda-beda.
  void aturTitik(Iterable<double> nilai) {
    final bersih = nilai.toSet().toList()..sort();

    titikKustom
      ..clear()
      ..addAll(bersih);

    _bangunTitik(pertahankanIsian: true);
  }

  /// Titik yang berlaku sekarang, urut — buat layar pengatur titik.
  List<double> get titikBerlaku {
    if (titikKustom.isNotEmpty) return List.unmodifiable(titikKustom);

    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        if (t.titikBisaDiubah) {
          return [for (final b in t.barisUntuk(satuan)) b.titikUkur];
        }
      }
    }

    return const [];
  }

  /// Lembar ini titiknya boleh diatur teknisi?
  bool get titikBisaDiubah => bentuk.bagian.any(
    (bagian) => bagian.tabel.any((t) => t.titikBisaDiubah),
  );

  int _bangunTitik({bool pertahankanIsian = false}) {
    // Isian sel disalin DULU, sebelum yang lama dibuang. Yang disalin cuma
    // angkanya — `TitikState`-nya sendiri dibikin ulang dari bentuk yang baru,
    // karena satuan/desimal/eksklusif-nya bisa berubah dan objek lama bakal
    // bawa metadata basi.
    final lama = pertahankanIsian
        ? {
            for (final e in titik.entries)
              if (e.value.salinKotak().isNotEmpty) e.key: e.value.salinKotak(),
          }
        : const <double, Map<String, String>>{};

    for (final t in titik.values) {
      t.dispose();
    }
    titik.clear();

    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        final baris = barisTabel(t);

        for (var i = 0; i < baris.length; i++) {
          final b = baris[i];

          titik.putIfAbsent(
            kunciBaris(baris, i),
            () => TitikState(
              titikUkur: b.titikUkur,
              tipe: b.tipe,
              label: b.label,
              jumlahPengulangan: t.pengulangan.length,
              // Lembar bersatuan CAMPUR ngambil dari barisnya; sisanya pakai
              // satuan yang lagi KEPILIH — bukan satuan lembar.
              //
              // Bedanya penting: Refractometer nggak campur, tapi satuannya
              // bisa dipindah teknisi (n20D ↔ °Brix). Kalau di sini dipatok ke
              // `bentuk.satuan`, pilihan °Brix-nya kebuang tiap tabel dibangun
              // ulang dan `measurements[].satuan` kekirim n20D.
              satuan: bentuk.satuanCampuran ? (b.satuan ?? satuan) : satuan,
              desimal: b.desimal,
              eksklusifDengan: b.eksklusifDengan,
              // Standar pasangan titik ini udah kepilih dari formulirnya —
              // teknisi tinggal nyentang, nggak milih ulang dari katalog.
              standardIdTercetak: b.standardId,
              standardNama: b.standardNama,
              onKetik: () => onIsianDiketik?.call(),
            ),
          );
        }
      }
    }

    var kebuang = 0;

    for (final e in lama.entries) {
      final tujuan = titik[e.key];

      if (tujuan == null) {
        kebuang++;
        continue;
      }

      tujuan.tempelKotak(e.value);
    }

    // Penanda sel dibangun dari KUNCI baris, dan kuncinya baru saja dibikin
    // ulang. Tanpa disusun ulang di sini, penanda merah dari admin nyangkut di
    // kunci lembar yang sudah nggak ada — persis di kasus yang paling butuh:
    // lembar generik Conductivity nyusut begitu alatnya kepilih, dan `titik_ke`
    // maupun kuncinya geser. Yang keliatan teknisi: lembar revisi tanpa satu
    // pun kotak merah, padahal admin sudah nandain.
    _susunSelRevisi();

    return kebuang;
  }

  /// Ganti bentuk lembar TANPA ngebuang isian yang udah diketik.
  ///
  /// Dipanggil waktu teknisi milih alat: backend ngirim bentuk yang disusutin
  /// ke alat itu. Conductivity generik punya baris `1412 µS/cm` DAN
  /// `1,412 mS/cm`; begitu alatnya kebaca, cuma satu yang tersisa — yang
  /// satuannya cocok sama resolusi alat pelanggan.
  ///
  /// Balikin JUMLAH TITIK yang isinya kebuang karena barisnya udah nggak ada.
  /// Angka itu wajib ditampilin ke teknisi: isian kalibrasi yang ilang
  /// diam-diam lebih bahaya daripada formulir yang bentuknya salah.
  ///
  /// Kotak teksnya ikut diselaraskan ([_selaraskanKotakTeks]): kolom yang cuma
  /// ada di bentuk baru dapat controller-nya di sini, bukan dibiarin yatim.
  ///
  /// Yang TIDAK ikut dipertahankan: pilihan standar per titik. Itu diturunkan
  /// ulang dari bentuk yang baru dan kelihatan di daftar centang, jadi
  /// perubahannya nggak diam-diam.
  int gantiBentuk(LembarKerja baru) {
    bentuk = baru;
    _selaraskanKotakTeks();
    _selaraskanGrid();

    return _bangunTitik(pertahankanIsian: true);
  }

  /// Isian GRID sensor, cuma ada di lembar yang backend-nya mengirim
  /// `grid_sensor` (Enclosure). Null buat sepuluh alat lain.
  GridSensorState? grid;

  /// Samain [grid] sama bentuk yang lagi kepasang.
  ///
  /// Dipanggil dari [gantiBentuk] juga, bukan cuma konstruktor: bentuk awal
  /// datang sebelum teknisi milih alat, jadi lembar Enclosure baru kelihatan
  /// ber-grid di panggilan KEDUA. Kalau cuma di konstruktor, gridnya nggak
  /// pernah lahir dan layarnya kosong.
  ///
  /// Isian yang sudah diketik DIPERTAHANKAN selama bentuknya masih ber-grid —
  /// sama alasannya dengan [_bangunTitik] yang `pertahankanIsian`: teknisi
  /// bisa mengganti alat sesudah mulai mengisi, dan angka lapangan nggak boleh
  /// hilang diam-diam.
  void _selaraskanGrid() {
    final bentukGrid = bentuk.gridSensor;

    if (bentukGrid == null) {
      grid?.dispose();
      grid = null;
      return;
    }

    if (grid == null) {
      grid = GridSensorState(bentuk: bentukGrid);
      return;
    }

    // Bentuk grid berubah (jumlah kolom pengulangan beda) — isian lama nggak
    // bisa dipetakan dengan jujur ke kolom baru, jadi dibangun ulang.
    if (grid!.bentuk.pengulangan.length != bentukGrid.pengulangan.length) {
      grid!.dispose();
      grid = GridSensorState(bentuk: bentukGrid);
    }
  }

  /// Titik ukur yang bakal kebentuk kalau satuannya [calon] — dipakai layar
  /// buat tau apakah ganti satuan bakal ngubah tabelnya sama sekali.
  Set<double> _titikUntuk(String calon) => {
    for (final bagian in bentuk.bagian)
      for (final t in bagian.tabel)
        // Kuncinya wajib dihitung sama kayak [_bangunTitik]; kalau di sini
        // pakai `titikUkur` mentah, perbandingan set-nya bilang tabelnya
        // berubah padahal nggak.
        for (var i = 0; i < barisTabel(t, calon).length; i++)
          kunciBaris(barisTabel(t, calon), i),
  };

  /// Ganti satuan ke [calon] bakal **ngosongin** tabel yang udah diisi?
  ///
  /// `true` cuma kalau dua-duanya kejadian: titik standarnya beda, DAN udah ada
  /// pembacaan yang diketik. Layar wajib nanya dulu sebelum manggil setter
  /// [satuan] — angka yang diketik di lapangan nggak boleh ilang diam-diam,
  /// walau angka n20D emang nggak ada artinya sebagai °Brix.
  bool gantiSatuanMenghapusIsian(String calon) =>
      !setEquals(_titikUntuk(calon), titik.keys.toSet()) &&
      titik.values.any((t) => t.adaIsian);

  /// **Nggak final.** Bentuk lembar bisa diganti di tengah jalan lewat
  /// [gantiBentuk] — begitu teknisi milih alat, backend ngirim bentuk yang
  /// disusutin ke alat itu (Conductivity: 4 baris → 3). State-nya sengaja
  /// DIPERTAHANKAN, bukan dibikin ulang, supaya isian teknisi nggak ilang.
  LembarKerja bentuk;

  /// Kode lembar kerja yang lagi dibuka (`tits`, `inkubator`, `ph_meter`, ...).
  ///
  /// Dibawa di state, bukan diturunkan lewat parameter widget, karena yang
  /// membutuhkannya (`_PilihAlat`) duduk di dalam `_Field` — dan `_Field`
  /// dibangun dari belasan tempat. Menambah satu parameter di sana berarti
  /// menyentuh semuanya, dan satu yang kelupaan bikin picker-nya diam-diam
  /// balik nggak tersaring.
  final String? profil;
  final String clientRequestId;

  /// Dipasang layar buat tau ada ANGKA yang baru diketik di tabel hasil.
  ///
  /// Dibaca lewat listener controller, bukan `onChanged` di tiap sel: yang
  /// dengerin (penjadwal pratinjau) nggak butuh rebuild, dan rebuild tiap
  /// ketukan tombol bikin tabel 87 kotak tersendat di HP.
  ///
  /// Dipegang di sini, bukan di tiap [TitikState], supaya tetap kepasang waktu
  /// tabelnya dibangun ulang ([gantiBentuk] / ganti satuan) — `TitikState`-nya
  /// dibikin baru di situ.
  VoidCallback? onIsianDiketik;

  EquipmentLookup? alat;
  LokasiKalibrasi lokasi = LokasiKalibrasi.lab;
  int? roomId;
  int? standardId;

  /// Satuan yang lagi ditampilin alatnya — dipilih teknisi lewat kolom
  /// `equipment.satuan` ("7. Satuan Refracto"), dan ikut ke tiap
  /// `measurements[].satuan`.
  ///
  /// Cuma Refractometer yang punya kolomnya: satu alat fisik bisa nampilin
  /// **n20D** (indeks bias) atau **°Brix** (kadar sukrosa), dan pilihannya
  /// ngubah semua angka hilirnya — koefisien suhu 0,00045/°C vs 0,07/°C, titik
  /// larutan standar, sampai CMC-nya. Makanya ditanya di depan, bukan ditebak
  /// dari angka yang masuk.
  ///
  /// Bawaannya `bentuk.satuan` dari backend, bukan `alat?.satuan`: yang kedua
  /// bakal ngubah perilaku tiga alat lama yang selama ini selalu ikut bentuk.
  /// Master alat cuma dipakai buat **milihin nilai awal** waktu alatnya
  /// dipilih, dan itu pun lewat [isiDariAlat] yang cuma ngisi yang masih
  /// kosong.
  String get satuan => _satuanPilihan ?? bentuk.satuan;

  set satuan(String nilai) {
    final titikBaru = _titikUntuk(nilai);
    _satuanPilihan = nilai;

    // Titik standarnya beda → tabelnya dibangun ulang. Refractometer di skala
    // °Brix diadu ke larutan 2,5 & 40, bukan 1,33659 & 1,39986 — larutan
    // fisiknya sama, angkanya beda. Pembacaan lama ikut kebuang, dan itu bukan
    // kehilangan data: angka n20D nggak punya arti sebagai °Brix. Layar wajib
    // konfirmasi dulu lewat [gantiSatuanMenghapusIsian].
    if (!setEquals(titikBaru, titik.keys.toSet())) {
      _bangunTitik();
      return;
    }

    // Titiknya sama (alat satu satuan, atau satuan yang nggak ngubah tabel) —
    // isian dipertahankan, cuma label satuannya yang ikut.
    //
    // Dibarengin sekarang juga, bukan pas nyusun payload: ringkasan sebelum
    // kirim baca `TitikState.satuan` langsung, jadi kalau cuma ditimpa waktu
    // submit, teknisi ganti ke °Brix tapi layar konfirmasinya tetap nulis n20D
    // — dan yang dia setujui bukan yang dikirim.
    // Lembar bersatuan CAMPUR nggak ikut: satuannya nempel per baris dari
    // backend, dan nimpa borongan di sini bikin 111 mS/cm kelabel µS/cm.
    if (bentuk.satuanCampuran) return;

    for (final t in titik.values) {
      t.satuan = nilai;
    }
  }

  String? _satuanPilihan;

  /// Baris [titikUkur] lagi TERKUNCI karena pasangannya udah mulai diisi?
  ///
  /// Titik tengah Conductivity dikirim dalam dua bentuk buat botol yang sama
  /// (`1412 µS/cm` & `1,412 mS/cm`). Begitu salah satu diisi, pasangannya
  /// dikunci — bukan disembunyikan, supaya teknisi lihat bahwa itu alternatif
  /// satuan, bukan titik yang hilang.
  ///
  /// Balik kebuka sendiri kalau isian baris aktifnya dikosongin lagi.
  bool titikTerkunci(double titikUkur) {
    final pasangan = titik[titikUkur]?.eksklusifDengan;
    if (pasangan == null) return false;

    // Sengaja `adaPembacaan`, BUKAN `adaIsian`: yang ngunci baris pasangan itu
    // ANGKA yang diketik teknisi, bukan standar tercetak yang emang udah keisi
    // dari lembar kerjanya.
    return titik[pasangan]?.adaPembacaan ?? false;
  }

  /// Baris ini boleh diketik?
  ///
  /// Dua syarat, dan dua-duanya dari lab:
  ///
  ///  1. **Standarnya dicentang.** Centang = "botol ini yang saya pakai". Baris
  ///     yang nggak dicentang tetap KELIHATAN — teknisi perlu tau titik itu ada
  ///     di lembar kerjanya — tapi kotaknya mati.
  ///  2. Pasangan satuannya belum diisi ([titikTerkunci]).
  ///
  /// Baris tanpa pasangan & tanpa standar tercetak (alat yang standarnya nggak
  /// dipilih per titik) tetap kebuka: `standardId` null di situ artinya "lembar
  /// ini emang nggak nanya", bukan "belum dicentang".
  bool titikBisaDiisi(double titikUkur) {
    final state = titik[titikUkur];
    if (state == null) return false;

    if (titikTerkunci(titikUkur)) return false;

    // Cuma dipakai kalau lembarnya emang nyodorin pilihan standar per titik.
    if (state.standardIdTercetak != null && state.standardId == null) {
      return false;
    }

    return true;
  }

  /// Baris yang pembacaannya keisi tapi suhunya kosong — penahan sebelum kirim.
  ///
  /// Kosong = boleh kirim. Lihat [TitikState.adaPembacaanTanpaSuhu] soal kenapa
  /// ini bukan formalitas.
  List<TitikState> get titikSuhuBelumLengkap => bentuk.suhuWajib
      ? titik.values
            .where((t) => !titikTerkunci(t.titikUkur) && t.adaPembacaanTanpaSuhu)
            .toList()
      : const [];

  /// Baris yang pembacaannya meleset satu orde dari nominalnya — penahan
  /// sebelum kirim, sejajar sama penjaga suhu & penjaga isian yatim.
  ///
  /// Lihat [TitikState.adaPembacaanJauhDariTitik] soal kenapa ini ditahan di HP
  /// dan bukan dibiarin jadi peringatan di admin.
  List<TitikState> get titikPembacaanJauh => titik.values
      .where(
        (t) => !titikTerkunci(t.titikUkur) && t.adaPembacaanJauhDariTitik,
      )
      .toList();

  /// Baris yang satu Repeat-nya jauh menyimpang dari Repeat lain SEBARIS.
  ///
  /// Penjaga terpisah dari [titikPembacaanJauh] karena yang ditangkap beda:
  /// yang itu koma kegeser, yang ini digit ketuker. Lihat
  /// [TitikState.adaRepeatMenyimpang] — satu digit yang ketuker pernah bikin
  /// U95 sertifikat 212x CMC lab.
  List<TitikState> get titikRepeatMenyimpang => titik.values
      .where((t) => !titikTerkunci(t.titikUkur) && t.adaRepeatMenyimpang)
      .toList();

  /// Baris yang ANGKANYA keisi tapi standar acuannya belum dicentang.
  ///
  /// Keadaan ini mustahil secara maksud, tapi gampang kejadian: teknisi ngisi
  /// angka lalu lepas centangnya (atau sebaliknya). Hasilnya isian YATIM —
  /// kesimpen tapi nggak bisa dihitung, karena nilai acuan titik itu nggak
  /// ketauan dari botol mana.
  ///
  /// Dulu ini lolos sampai admin, dan baru ketahuan di sana sebagai
  /// `titik_tidak_terhitung` + `titik_kosong` yang MEMBLOKIR penerbitan —
  /// jauh dari lapangan, jauh dari orang yang bisa mbenerin. Sekarang ditahan
  /// di HP, sejajar sama penjaga suhu.
  ///
  /// Titik yang emang nggak dipakai alat pelanggan TIDAK kena: dia nggak
  /// dicentang DAN barisnya kosong, jadi nggak masuk daftar ini.
  List<TitikState> get titikTerisiTanpaStandar => titik.values
      .where(
        (t) =>
            t.adaPembacaan &&
            t.standardIdTercetak != null &&
            t.standardId == null,
      )
      .toList();

  /// Lembar kerja ini punya kolom "7. Satuan Refracto"?
  ///
  /// Yang nentuin **bentuk dari backend**, bukan daftar nama alat di sini —
  /// begitu ada alat kelima yang satuannya bisa dipindah, dia ikut jalan tanpa
  /// nyentuh file ini. Dipakai buat mutusin `equipment_satuan` ikut dikirim
  /// atau nggak; lihat `LembarKerjaSubmission.equipmentSatuan` soal kenapa
  /// ngirimnya terus-terusan itu merusak.
  bool get satuanBisaDipilih => bentuk.bagian
      .expand((b) => b.field)
      .any((f) => f.kode == 'equipment.satuan');

  /// Kolom administratif — cuma kebentuk kalau backend ngirimin bagiannya
  /// (yaitu waktu yang login admin).
  int? calibrationMethodId;
  int? thermohygroStandardId;

  final Map<String, TextEditingController> teks = {};
  final Map<String, DateTime?> tanggal = {};

  /// Sel tabel matriks (besaran × titik waktu), keyed [kunciMatriks].
  ///
  /// Kepisah dari [titik] karena barisnya bukan titik ukur: `Temp. Disk 1` dan
  /// `Indikator Pressure` besaran yang beda, bukan dua level dari besaran yang
  /// sama. Dipaksa masuk [titik], kedelapan barisnya berbagi satu `TitikState`
  /// dan saling nimpa.
  final Map<String, TextEditingController> matriks = {};

  /// Keyed by nilai larutan standar (4.00 / 7.00 / 10.01).
  final Map<double, TitikState> titik = {};

  /// Ada minimal satu sel yang pernah diisi hasil **pindai lembar (OCR
  /// lokal)**, walau sesudah itu dibetulin manual teknisi.
  ///
  /// Dipakai buat `input_method` yang dikirim ke backend. Dulu kolom itu dipatok
  /// `manual` terus, jadi sesi yang tabelnya dibaca mesin kecatat sama persis
  /// kayak yang diketik tangan. Waktu ada angka sertifikat yang kelihatan aneh,
  /// nggak ada satu pun cara buat tahu angka itu datang dari mana — 6 Agt 2026
  /// mesti ngubek log server buat mastiin satu sesi chlorine bukan hasil salah
  /// baca mesin. Backend nerima `manual|ocr|ai_vision`
  /// (`CalibrationRequest`); sesudah jalur AI Vision dicabut, yang mungkin
  /// tinggal `manual` & `ocr`.
  bool adaIsianDariFoto = false;

  /// Sel yang diisi hasil pindai dengan vonis server **kuning atau merah** —
  /// ditandai di layar biar teknisi ngecek angka itu saja, bukan seluruh tabel.
  /// Kuncinya [kunciSel]. Dibersihin kalau selnya diisi ulang dengan vonis
  /// bagus di pindai berikutnya.
  final Set<String> selRendahKeyakinan = {};

  /// Sel yang **admin** minta dibetulin — dibangun dari kode sel di
  /// [revisiField]. Kuncinya [kunciSel], sama persis kayak
  /// [selRendahKeyakinan], jadi tabelnya nggak perlu tau dua bentuk kunci.
  ///
  /// Dua penanda yang beda arti, dan sengaja dipisah:
  /// [selRendahKeyakinan] itu "mesin nggak yakin, tolong dicek";
  /// yang ini "admin bilang yang ini salah". Yang kedua lebih kuat, jadi
  /// warnanya menang di [TandaSel].
  ///
  /// Ini yang bikin revisi berhenti jadi "ulangi tabelnya". Sebelumnya
  /// `revisi_field` cuma bisa nunjuk KOLOM identitas, jadi angka yang salah di
  /// tengah tabel cuma bisa diceritain lewat prosa — dan teknisi yang nggak
  /// nemu kotaknya milih jalan aman: ngosongin tabel, ngetik ulang semuanya,
  /// termasuk angka yang udah bener.
  final Set<String> selRevisi = {};

  /// Slot cetak bersatuan dobel: kunci [kunciSlot] → index varian yang kepilih.
  ///
  /// Kertas Conductivity nyetak `1413 µS` dan `1.413 mS` berdampingan dengan
  /// "ceklis salah satu" — botol yang sama, dua satuan. Pilihannya nentuin
  /// angka yang masuk mendarat di titik `1412` atau `1,412`.
  ///
  /// Ditaruh DI SINI, bukan di state widget tabelnya, karena dua tempat butuh
  /// jawabannya: tabel yang digambar, dan tombol foto tabel yang mesti tahu
  /// kolom itu lagi nunjuk titik yang mana. Bonusnya pilihan teknisi nggak
  /// hilang waktu widgetnya kebangun ulang.
  final Map<String, int> pilihanSlot = {};

  /// Kunci satu slot cetak di dalam satu tabel.
  static String kunciSlot(String tahap, int index) => '$tahap|$index';

  /// Kunci satu sel tabel — sama persis dengan yang dibangun widget tabel biar
  /// penandaan keyakinan-rendah nyambung ke kotak yang benar.
  static String kunciSel(double titikUkur, String tahap, String kolom, int index) =>
      '$titikUkur|$tahap|$kolom|$index';

  /// Titik yang lagi aktif buat satu slot cetak — jawaban yang sama buat tabel
  /// yang digambar dan buat tombol foto tabel.
  ///
  /// Bukan cuma baca [pilihanSlot]: kalau salah satu varian udah keisi (draft
  /// yang dipulihkan, atau hasil pindai), yang keisi itu yang menang — teknisi
  /// nggak boleh lihat kolom kosong padahal angkanya ada di titik sebelah.
  double? titikAktifSlot(String tahap, int index, SlotCetak slot) {
    if (slot.mati) return null;
    if (slot.titikUkur.length == 1) return slot.titikUkur.first;

    for (final t in slot.titikUkur) {
      if (titikTerkunci(t)) continue;
      if (!titikBisaDiisi(t)) continue;

      // Yang pasangannya udah kekunci = yang lagi dipakai. Ini menang atas
      // pilihan manual supaya angka yang udah diketik nggak ketutup.
      if (slot.titikUkur.any(titikTerkunci)) return t;
    }

    final dipilih = pilihanSlot[kunciSlot(tahap, index)] ?? 0;

    return slot.titikUkur[dipilih.clamp(0, slot.titikUkur.length - 1)];
  }

  /// Prefiks kode sel di `revisi_field`. Sama persis dengan `KodeSelRevisi`
  /// di backend — dua sisi mesti sepakat, dan yang nulis kontraknya di sana.
  static const prefiksKodeSel = 'sel:';

  /// Terjemahin kode sel dari [revisiField] jadi kunci [kunciSel].
  ///
  /// Bentuk kodenya: `sel:<tahap>:<titik_ukur>:<kolom>:<pembacaan_ke>`,
  /// mis. `sel:sesudah_adjustment:1412:pembacaan:3`. `pembacaan_ke` 1-based
  /// (sama kayak nomor Repeat yang tercetak di kertas); yang jadi index 0-based
  /// cuma di sini, satu tempat.
  ///
  /// Kode yang bentuknya rusak DIABAIKAN, bukan bikin error. Yang ngirim ini
  /// layar admin, dan versi HP bisa lebih tua dari versi admin yang ngirim —
  /// nolak seluruh lembar gara-gara satu penanda yang nggak kebaca itu jauh
  /// lebih merugikan daripada satu kotak yang nggak kesorot. Catatan prosanya
  /// tetap nyampe apa adanya.
  void _susunSelRevisi() {
    selRevisi.clear();

    for (final kode in revisiField) {
      if (!kode.startsWith(prefiksKodeSel)) continue;

      final bagian = kode.split(':');
      if (bagian.length != 5) continue;

      final tahap = bagian[1];
      final titik = double.tryParse(bagian[2]);
      final kolom = bagian[3];
      final ulang = int.tryParse(bagian[4]);

      if (tahap.isEmpty || kolom.isEmpty || titik == null) continue;
      if (ulang == null || ulang < 1) continue;

      // Titiknya dicocokin ke baris yang BENERAN ada di lembar ini, bukan
      // dipakai apa adanya: `kunciSel` dibangun dari nilai titik milik bentuk
      // lembar, dan angka yang sama bisa beda di digit terakhir sesudah
      // bolak-balik lewat JSON & `decimal(20,8)`. Tanpa ini penandanya nyangkut
      // di kunci yang nggak pernah kegambar.
      final kunci = _kunciTitikTerdekat(titik);
      if (kunci == null) continue;

      selRevisi.add(kunciSel(kunci, tahap, kolom, ulang - 1));
    }
  }

  /// Penanda yang berlaku buat satu sel. Permintaan admin menang atas keraguan
  /// mesin: yang satu perintah, yang satu saran.
  TandaSel tandaSel(double titikUkur, String tahap, String kolom, int index) {
    final kunci = kunciSel(titikUkur, tahap, kolom, index);

    if (selRevisi.contains(kunci)) return TandaSel.revisi;
    if (selRendahKeyakinan.contains(kunci)) return TandaSel.keyakinanRendah;

    return TandaSel.tidakAda;
  }

  /// Kunci penanda buat kolom non-tabel & baris usage check. Prefiks-nya bikin
  /// nggak mungkin bentrok sama [kunciSel] yang diawali angka titik ukur.
  static String kunciField(String kode) => 'field|$kode';
  static String kunciUsage(int standardId) => 'usage|$standardId';

  final Map<int, UsageCheckState> usageCheck = {};

  /// Kode kolom yang diminta admin dibetulin (sesi `perlu_revisi`). Dipakai
  /// layar buat nyorot kolomnya — bukan buat nahan kirim. Teknisi tetap boleh
  /// ngirim tanpa nyentuh semuanya: kadang yang diminta admin ternyata udah
  /// bener dan yang salah hal lain.
  final Set<String> revisiField = {};

  /// Catatan admin waktu ngembaliin lembar ini — alasannya, apa adanya.
  ///
  /// Wajib ada di layar tempat teknisi MEMBETULKAN, bukan cuma di notifikasi
  /// & layar detail sesi. Kolom bergaris merah cuma nunjukin MANA yang salah;
  /// yang bikin teknisi ngerti harus diapain itu alasannya. Tanpa ini dia
  /// mesti mundur ke layar lain sambil ngingat-ngingat, atau ngira-ngira.
  ///
  /// Bisa null: admin boleh nolak dengan catatan tanpa nandain kolom.
  String? catatanRevisi;

  /// Lembar ini dikembalikan admin — entah lewat kolom yang ditandai, catatan,
  /// atau dua-duanya.
  ///
  /// Sengaja BUKAN `revisiField.isNotEmpty`: `revisi_field` boleh null di
  /// backend, jadi penolakan yang cuma bawa catatan bikin bannernya nggak
  /// muncul sama sekali. Teknisi dapat lembar yang kelihatan normal padahal
  /// admin udah ngembaliin — dan alasannya cuma ada di notifikasi yang
  /// gampang kelewat.
  bool get adaRevisi =>
      revisiField.isNotEmpty || (catatanRevisi?.trim().isNotEmpty ?? false);

  UsageCheckState usage(int standardId) => usageCheck.putIfAbsent(
    standardId,
    () => UsageCheckState(standardId: standardId),
  );

  /// Isi ulang formulir dari sesi yang udah ada — lanjut draft, atau perbaiki
  /// lembar kerja yang dikembalikan admin.
  ///
  /// Yang DITIMPA cuma kolom yang masih kosong. Alasannya: layar ini bisa
  /// kebuka duluan (teknisi langsung ngetik) sebelum detail sesinya nyampe dari
  /// jaringan yang lelet. Kalau data lama nimpa apa yang barusan diketik,
  /// koreksi teknisi ilang di depan matanya sendiri — kejadian paling bikin
  /// nggak percaya sama app.
  ///
  /// Pengukurannya sendiri (tabel Before/After) nggak diisi di sini: bentuknya
  /// beda per tahap & pengulangan, dan itu urusan `terapkanPembacaan` yang
  /// dipanggil layar sesudah tabelnya kebentuk.
  void muatDariSesi(IsianTeknisi isi) {
    void isiTeks(String kode, String? nilai) {
      final kotak = teks[kode];
      if (kotak == null || nilai == null || nilai.trim().isEmpty) return;
      if (kotak.text.trim().isNotEmpty) return;
      kotak.text = nilai;
    }

    void isiAngka(String kode, double? nilai) {
      if (nilai != null) isiTeks(kode, formatAngka(nilai));
    }

    isiTeks('alat_model', isi.alatModel);
    isiTeks('alat_serial_number', isi.alatSerialNumber);
    isiTeks('alat_merk', isi.alatMerk);
    isiTeks('pemilik_nama', isi.pemilikNama);
    isiTeks('pemilik_alamat', isi.pemilikAlamat);
    isiTeks('catatan_teknisi', isi.catatanTeknisi);
    isiTeks('lokasi_nama', isi.lokasiNama);

    // Kuncinya dari bentuk lembar kerja, jadi kolom yang udah nggak ada di
    // bentuk baru dilewat begitu aja — bukan bikin controller yatim.
    for (final e in isi.spesifikasiAlat.entries) {
      isiTeks('spesifikasi_alat.${e.key}', e.value);
    }

    isiAngka('suhu_awal', isi.suhuAwal);
    isiAngka('suhu_akhir', isi.suhuAkhir);
    isiAngka('kelembaban_awal', isi.kelembabanAwal);
    isiAngka('kelembaban_akhir', isi.kelembabanAkhir);
    isiAngka('tekanan_awal', isi.tekananAwal);
    isiAngka('tekanan_akhir', isi.tekananAkhir);

    standardId ??= isi.standardId;
    roomId ??= isi.roomId;
    thermohygroStandardId ??= isi.thermohygroStandardId;
    tanggal['tanggal_terima'] ??= isi.tanggalTerima;

    if (isi.lokasi == 'onsite') lokasi = LokasiKalibrasi.onsite;

    revisiField
      ..clear()
      ..addAll(isi.revisiField);
    _susunSelRevisi();
    catatanRevisi = isi.catatanRevisi;

    isi.standarDicek.forEach((standardId, baris) {
      final state = usage(standardId);
      if (state.adaIsian) return;
      state.dipakai = baris.dipakai;
      if (baris.keterangan != null) state.keterangan.text = baris.keterangan!;
    });
  }

  double? angka(String kode) {
    final c = teks[kode];
    return c == null ? null : parseAngka(c.text);
  }

  String? kalimat(String kode) {
    final t = teks[kode]?.text.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Nilai kolom [kode] dalam bentuk API-nya — buat NGEJAWAB syarat tampil
  /// ([SyaratTampil]), bukan buat nyusun payload.
  ///
  /// `lokasi` diladenin sendiri karena dia satu-satunya kolom pilihan yang
  /// nggak disimpen di [teks]: dia punya slot bertipe ([lokasi]) supaya
  /// payload-nya nggak bergantung ejaan teks. Sisanya lewat [teks] apa adanya,
  /// jadi kolom bersyarat berikutnya nggak perlu nambah cabang di sini.
  ///
  /// `null` = kolomnya nggak ketemu atau belum keisi; [SyaratTampil.dipenuhi]
  /// nganggep itu "tampilkan".
  String? nilaiSyarat(String kode) {
    if (kode == 'lokasi') return lokasi.toApi();
    return kalimat(kode);
  }

  /// Kolom ini digambar di layar sekarang?
  ///
  /// SATU-SATUNYA aturan tampil bersyarat di app, dan dia nggak kenal satu pun
  /// nama kolom — lihat [SyaratTampil] soal kenapa yang lama (hardcode
  /// `lokasi_nama`) mesti dicabut.
  bool fieldTampil(FieldLembarKerja f) =>
      f.tampilKalau == null ||
      f.tampilKalau!.dipenuhi(nilaiSyarat(f.tampilKalau!.kode));

  /// Kosongin kolom yang lagi NGGAK tampil.
  ///
  /// Disembunyiin doang nggak cukup, dan itu bukan teori: dropdown `Ruangan`
  /// dulu tetap kekirim waktu teknisi milih Insitu, jadi sertifikat kunjungan
  /// ke pelanggan kecetak nama RUANG LAB — tempat yang alatnya nggak pernah ke
  /// sana. Kolom tersembunyi yang masih nyimpen nilai = nilai yang nggak bisa
  /// dilihat, nggak bisa dibetulin, tapi tetap nyampe ke dokumen.
  ///
  /// Dipanggil dua kali dan dua-duanya perlu: waktu isian berubah (biar teknisi
  /// LIHAT kotaknya kosong kalau syaratnya balik kepenuhan) dan waktu payload
  /// disusun (draft lama yang datanya udah terlanjur kotor nggak pernah
  /// disentuh dropdown-nya sama sekali).
  ///
  /// [alat] sengaja NGGAK ikut dikosongin walau kolomnya bersyarat: seluruh
  /// bentuk lembar disusutin ke alat itu, jadi ngosongin dia berarti ngebuang
  /// tabel beserta isinya — kerusakan yang jauh lebih besar dari kolom nyasar.
  void bersihkanFieldTersembunyi() {
    for (final bagian in bentuk.bagian) {
      // Kolom di luar kertas ikut disapu: dia digambar di panel sendiri, tapi
      // nyimpen nilainya di slot yang sama. Dilewat di sini, kolom bersyarat
      // pertama yang mendarat di sana bakal ngulang bug yang persis sama —
      // kotaknya ilang dari layar, isinya tetap kekirim.
      for (final f in [...bagian.field, ...bagian.fieldDiLuarKertas]) {
        if (fieldTampil(f)) continue;

        teks[f.kode]?.clear();
        if (tanggal.containsKey(f.kode)) tanggal[f.kode] = null;

        switch (f.sumber) {
          case SumberField.masterRuangan:
            roomId = null;
          case SumberField.masterMetode:
            calibrationMethodId = null;
          case SumberField.masterStandar:
          case SumberField.masterThermohygro:
            // Dua kolom standar berbagi satu `sumber`, dan yang bener-bener
            // dipakai dibedain lewat KODE-nya di layar (`_PilihStandar`).
            // Ditiru di sini biar nggak ada yang kekosongin salah slot.
            if (f.kode == 'thermohygro_standard_id') {
              thermohygroStandardId = null;
            } else {
              standardId = null;
            }
          case SumberField.masterAlat:
          case SumberField.manual:
          case SumberField.otomatis:
            break;
        }
      }
    }
  }

  /// Mode kalibrasi yang lagi kepilih (`measure`/`source`), atau null.
  ///
  /// Dibaca widget tabel buat milih judul kolom: dua kolom TITS BERTUKAR sisi
  /// antar mode, dan judul yang salah bikin teknisi ngisi kolom yang keliru
  /// tanpa satu pun error muncul. Getter, bukan field tersimpan — sumbernya
  /// tetap satu (`teks['mode_kalibrasi']`), jadi nggak ada dua salinan yang
  /// bisa nggak sinkron waktu dropdown-nya diubah.
  String? get modeKalibrasi => kalimat('mode_kalibrasi');

  /// Kode field yang nentuin ANGKA, bukan catatan — kalau kosong, hitungannya
  /// nggak jalan sama sekali.
  ///
  /// Sejauh ini cuma dua, dan dua-duanya milik TITS. Backend nandainya
  /// `wajib: false` (lembar setengah jadi tetap boleh dikirim dari lapangan),
  /// tapi tanpa keduanya SELURUH titik pulang di `belum_dihitung`: arah
  /// perhitungan koreksi berbalik antara mode measure & source, dan koreksi
  /// kalibrator beda per tipe sensor — jadi backend menolak nebak.
  ///
  /// Daftar kode, bukan daftar nama alat: yang nentuin lembar ini nanya atau
  /// nggak tetap BENTUK dari backend ([pilihanPenentuAngkaKosong] cuma lihat
  /// field yang beneran ada), jadi sepuluh alat lain nggak kesenggol.
  static const _kodePenentuAngka = {'mode_kalibrasi', 'tipe_sensor'};

  /// Field penentu angka yang ada di lembar ini tapi belum dipilih.
  ///
  /// Kosong = aman, atau lembarnya emang nggak nanya. Dipakai buat NANYA
  /// sebelum kirim, bukan buat nahan: `wajib: false` itu kontrak backend, dan
  /// teknisi yang kelupaan tipe sensornya di lapangan tetap harus bisa nyimpen
  /// apa yang udah dia ukur.
  List<FieldLembarKerja> get pilihanPenentuAngkaKosong => [
    for (final bagian in bentuk.bagian)
      for (final f in bagian.field)
        if (_kodePenentuAngka.contains(f.kode) && kalimat(f.kode) == null) f,
  ];

  /// Ada yang udah diketik sama sekali? Dipakai buat konfirmasi waktu teknisi
  /// nekan back — bukan buat nahan tombol kirim.
  bool get adaIsian =>
      alat != null ||
      roomId != null ||
      standardId != null ||
      teks.values.any((c) => c.text.trim().isNotEmpty) ||
      titik.values.any((t) => t.adaIsian) ||
      usageCheck.values.any((u) => u.adaIsian);

  /// Salinan seluruh isian sel, dikunci per TITIK UKUR (bukan per posisi
  /// baris) — posisinya bisa geser waktu bentuk lembar berubah, nilai titiknya
  /// nggak.
  Map<double, Map<String, String>> salinIsianTitik() => {
    for (final e in titik.entries)
      if (e.value.salinKotak().isNotEmpty) e.key: e.value.salinKotak(),
  };

  /// Isi tabel Before/After dari pembacaan yang udah tersimpan di server —
  /// lanjut draft, atau perbaiki lembar yang dikembalikan admin.
  ///
  /// Ini bagian yang selama ini BOLONG. [muatDariSesi] cuma mulangin kolom
  /// header (model, serial, suhu ruang, catatan); docblock-nya nunjuk ke
  /// "terapkanPembacaan" buat tabel pengukurannya, dan metode itu nggak pernah
  /// ditulis. Akibatnya teknisi yang mbuka draft-nya lagi — atau yang lembarnya
  /// dibalikin admin buat dibetulin — dapat tabel KOSONG, dan mesti ngetik
  /// ulang semua angka dari kertas. Di sesi revisi efeknya lebih parah lagi:
  /// yang dia kirim balik ke admin cuma sisa yang sempat diketik ulang.
  ///
  /// Dicocokin per **titik ukur**, bukan `titik_ke`. Alasannya sama kayak
  /// [salinIsianTitik]: `titik_ke` itu posisi baris, dan posisinya geser tiap
  /// bentuk lembar berubah — baris varian satuan Conductivity nyusut begitu
  /// alatnya kepilih, dan baris yang nggak keisi nggak nyimpen apa-apa di
  /// server sama sekali.
  ///
  /// Sel yang teknisinya SUDAH ngetik nggak ditimpa, sama kayak [muatDariSesi]:
  /// layar ini bisa kebuka duluan sebelum detail sesinya nyampe dari jaringan
  /// lelet, dan angka yang barusan diketik ilang di depan mata itu kerusakan
  /// yang lebih besar daripada satu sel yang nggak kepulihkan.
  ///
  /// Balikin JUMLAH pembacaan yang nggak ketemu barisnya — layar wajib ngasih
  /// tau teknisi kalau ada, karena diam-diam ngilangin angka kalibrasi itu
  /// persis kerusakan yang lagi ditutup di sini.
  int terapkanPembacaan(Iterable<RawMeasurement> mentah) {
    var kebuang = 0;

    // Baris ber-GRID dipisah duluan. Dia nggak punya kolom `pembacaan`/`suhu`
    // buat ditaruhi — angkanya duduk di sel (sensor ke-N, repeat ke-M) di dalam
    // grid termokopel — jadi menjalankannya lewat jalur di bawah bikin tiap
    // baris dianggap kebuang, dan gridnya tetap kosong.
    final bergrid = <RawMeasurement>[];
    final datar = <RawMeasurement>[];

    for (final m in mentah) {
      (m.bagianGrid ? bergrid : datar).add(m);
    }

    if (bergrid.isNotEmpty) kebuang += _terapkanGrid(bergrid);

    for (final m in datar) {
      final tujuan = _titikTerdekat(m.titikUkur);

      if (tujuan == null) {
        kebuang++;
        continue;
      }

      // Centang standar acuannya ikut pulih. Tanpa ini teknisi mesti nyentang
      // ulang tiap buka draft — dan kalau kelewat, sesinya kekirim tanpa nilai
      // acuan, nggak ada titik yang bisa dihitung, dan admin dapat lembar yang
      // keblokir `titik_kosong`.
      tujuan.standardId ??= m.standardId;

      // `pembacaan_ke` dari server itu 1-based; kotaknya 0-based.
      final index = m.pembacaanKe - 1;

      if (index < 0 || index >= tujuan.jumlahPengulangan) {
        kebuang++;
        continue;
      }

      final tahap = m.tahap == TahapPembacaan.sebelumAdjustment
          ? 'sebelum_adjustment'
          : 'sesudah_adjustment';

      final kotakPembacaan = tujuan.kotak(tahap, 'pembacaan', index);

      if (kotakPembacaan.text.trim().isEmpty) {
        kotakPembacaan.text = formatAngka(m.pembacaan);
      }

      final suhu = m.suhu;

      if (suhu != null) {
        final kotakSuhu = tujuan.kotak(tahap, 'suhu', index);
        if (kotakSuhu.text.trim().isEmpty) kotakSuhu.text = formatAngka(suhu);
      }
    }

    return kebuang;
  }

  /// Isi GRID sensor (Enclosure) dari pembacaan yang udah tersimpan di server.
  ///
  /// Sepuluh lembar bertabel datar pulih lewat [terapkanPembacaan] sejak lama:
  /// dicocokin per titik ukur, angkanya masuk ke kolom `pembacaan`/`suhu`.
  /// Lembar Enclosure nggak punya kolom itu. Yang dipulihkan di sini SEL —
  /// (set point, sensor ke-N, repeat ke-M) — dan yang membedakan satu baris
  /// dari yang lain justru `sensor_ke` plus `peran_sensor`.
  ///
  /// Tanpa ini, teknisi yang lembarnya dikembalikan admin dapat grid KOSONG dan
  /// ngetik ulang 9 termokopel x 5 repeat x tiap set point — 180 sel buat sesi
  /// Inkubator 4 set point, termasuk angka yang udah bener. Bahayanya bukan
  /// capeknya: yang kekirim balik ke admin cuma sisa yang sempat diketik ulang,
  /// dan sel yang kelewat nggak ninggalin jejak apa pun.
  ///
  /// **Peran yang nggak dikenal DIBUANG, bukan ditaruh di kotak termokopel.**
  /// Grid Enclosure nggak cuma termokopel — baris Suhu Ruang duduk di tabel
  /// yang sama dengan peran yang beda. Menaruh angka yang perannya nggak
  /// dikenali ke kotak termokopel bikin dia mendarat di sel yang salah:
  /// bentuknya wajar, tempatnya salah, dan nggak ada yang bakal teriak. Lebih
  /// baik dihitung kebuang — angkanya masih ada di server, dan teknisinya
  /// diomongin.
  ///
  /// Balikin JUMLAH baris yang nggak ketemu selnya, ikut dijumlah ke hitungan
  /// [terapkanPembacaan].
  int _terapkanGrid(List<RawMeasurement> mentah) {
    final g = grid;

    // Lembar yang lagi kepasang nggak ber-grid, tapi barisnya ber-peran: nggak
    // ada tempat yang jujur buat naruhnya. Kejadian kalau layarnya kebuka
    // dengan profil yang beda dari sesinya — dan kalau itu kejadian, seluruh
    // lembarnya emang salah, jadi diam bukan pilihan.
    if (g == null) return mentah.length;

    var kebuang = 0;

    // Dikelompokin per SET POINT dulu. Nilainya bolak-balik lewat JSON dan
    // `decimal(20,8)`, jadi dicocokin dengan toleransi yang sama kayak
    // [_titikTerdekat] — bukan `==`.
    final perTitik = <double, List<RawMeasurement>>{};

    for (final m in mentah) {
      final kunci = perTitik.keys.firstWhere(
        (k) => _titikSama(k, m.titikUkur),
        orElse: () => m.titikUkur,
      );
      (perTitik[kunci] ??= []).add(m);
    }

    final urut = perTitik.keys.toList()..sort();

    for (final titikUkur in urut) {
      final baris = perTitik[titikUkur]!
        // Termokopel duluan dan urut nomor, biar baris kosong bawaan layar
        // kepakai berurutan. Nomornya sendiri yang nentuin koreksi & Sensor
        // Acuan — bukan posisinya — tapi grid yang urutannya acak bikin
        // teknisi susah nyocokin sama kertas yang lagi dia pegang.
        ..sort((a, b) {
          final peran = _urutanPeran(a.peranSensor) - _urutanPeran(b.peranSensor);
          if (peran != 0) return peran;
          final no = (a.sensorKe ?? 0) - (b.sensorKe ?? 0);
          return no != 0 ? no : a.pembacaanKe - b.pembacaanKe;
        });

      for (final m in baris) {
        if (!_taruhSelGrid(g, titikUkur, m)) kebuang++;
      }
    }

    // Kotak teksnya udah keisi, tapi `pembacaan`/`nilai` di baliknya belum —
    // dan itu yang dibaca `sensorTerisi`, lencana Sensor Acuan, dan daftar
    // peringatan pra-kirim. Tanpa ini teknisi ngeliat grid penuh angka sambil
    // diomongin "belum ada termokopel yang diisi" sampai dia ngetuk satu sel.
    g.bacaUlang();

    return kebuang;
  }

  /// Termokopel dulu (0), baris deret belakangan (1).
  static int _urutanPeran(String? peran) => peran == 'termokopel' ? 0 : 1;

  /// Set point buat [titikUkur] — yang udah ada, yang masih kosong, atau baru.
  SetPointGridState _setPointUntuk(GridSensorState g, double titikUkur) {
    for (final sp in g.setPoint) {
      final t = sp.titikUkur;
      if (t != null && _titikSama(t, titikUkur)) return sp;
    }

    // Set point kosong bawaan layar dipakai ulang — bukan ditinggal jadi baris
    // hampa di atas hasil pemulihan.
    for (final sp in g.setPoint) {
      if (sp.kosongSemua) {
        sp.titikCtl.text = formatAngka(titikUkur);
        return sp;
      }
    }

    g.tambahSetPoint();
    final sp = g.setPoint.last;
    sp.titikCtl.text = formatAngka(titikUkur);
    return sp;
  }

  /// Taruh satu baris mentah ke selnya. `false` = nggak ketemu tempatnya.
  ///
  /// Set point-nya dibikin BELAKANGAN, cuma kalau barisnya beneran mendarat.
  /// Kalau dibikin di depan, satu baris yang ujungnya kebuang meninggalkan set
  /// point kosong berlabel "30 °C" yang ikut kekirim ke server dan bikin
  /// peringatan "belum ada termokopel yang diisi" — kebisingan yang dilahirkan
  /// pemulihan itu sendiri, di layar yang justru sedang dipakai membetulkan.
  ///
  /// [_setPointUntuk] aman dipanggil berkali-kali: panggilan kedua ketemu set
  /// point yang sama lewat nilai titiknya.
  bool _taruhSelGrid(GridSensorState g, double titikUkur, RawMeasurement m) {
    // `pembacaan_ke` dari server 1-based; kotaknya 0-based.
    final index = m.pembacaanKe - 1;

    // Diadu ke bentuknya, bukan ke panjang kotak satu baris — dua-duanya
    // dibangun dari `bentuk.pengulangan`, jadi angkanya sama persis, dan yang
    // ini kebaca tanpa perlu bikin barisnya dulu.
    if (index < 0 || index >= g.bentuk.pengulangan.length) return false;

    if (m.peranSensor == 'termokopel') {
      final no = m.sensorKe;

      // Termokopel tanpa nomor nggak bisa ditaruh: nomornya yang nentuin
      // koreksi mana yang dipakai, jadi nebak posisinya = nebak koreksinya.
      if (no == null) return false;

      final baris = _barisSensorUntuk(_setPointUntuk(g, titikUkur), no);

      _isiKalauKosong(baris.pembacaanCtl[index], m.pembacaan);

      // Kanal recorder ikut pulih. Tanpa ini sesi Recorder yang dikembalikan
      // bikin teknisi diteriakin "Channel wajib diisi" buat baris yang udah dia
      // isi bener — dan kalau dia ngetik ulang salah, koreksi kanal lain yang
      // kepakai tanpa satu pun error.
      final kanal = m.channel;

      if (kanal != null && baris.channelCtl.text.trim().isEmpty) {
        baris.channelCtl.text = '$kanal';
      }

      return true;
    }

    // Peran yang HP versi ini belum kenal dibuang. Lihat docblock
    // [_terapkanGrid] soal kenapa, bukan ditaruh di kotak terdekat.
    if (m.peranSensor != 'indikator' && m.peranSensor != 'suhu_ruang') {
      return false;
    }

    final sp = _setPointUntuk(g, titikUkur);
    final deret = m.peranSensor == 'indikator' ? sp.indikator : sp.suhuRuang;

    _isiKalauKosong(deret.ctl[index], m.pembacaan);

    return true;
  }

  /// Baris termokopel bernomor [no] — yang udah ada, yang masih kosong, atau
  /// baru.
  ///
  /// Nomornya yang dicari, BUKAN posisi barisnya: sembilan termokopel yang sama
  /// dipindah ke set point berikutnya, dan urutan ngisinya bebas.
  BarisSensorState _barisSensorUntuk(SetPointGridState sp, int no) {
    for (final b in sp.sensor) {
      if (b.no == no) return b;
    }

    for (final b in sp.sensor) {
      if (b.kosongSemua) {
        b.noCtl.text = '$no';
        return b;
      }
    }

    sp.tambahSensor();
    final b = sp.sensor.last;
    b.noCtl.text = '$no';
    return b;
  }

  /// Sel yang teknisinya SUDAH ngetik nggak ditimpa — aturan yang sama dengan
  /// [terapkanPembacaan] dan [muatDariSesi]. Layar ini bisa kebuka duluan
  /// sebelum detail sesinya nyampe dari jaringan lelet, dan angka yang barusan
  /// diketik ilang di depan mata itu kerusakan yang lebih besar daripada satu
  /// sel yang nggak kepulihkan.
  static void _isiKalauKosong(TextEditingController kotak, double nilai) {
    if (kotak.text.trim().isEmpty) kotak.text = formatAngka(nilai);
  }

  /// Cadangan buat sesi yang dikirim SEBELUM `raw_measurements.standard_id`
  /// ada: centang standarnya cuma kerekam di hasil hitung.
  ///
  /// Cuma kena titik yang berhasil dihitung — sesi draft lama yang nggak punya
  /// hasil hitung emang nggak nyimpen pilihan standarnya di mana pun, dan
  /// nggak ada yang bisa mulangin itu.
  void terapkanStandarDariHasil(Iterable<MeasurementResult> hasil) {
    for (final h in hasil) {
      final tujuan = _titikTerdekat(h.titikUkur);
      if (tujuan == null) continue;
      tujuan.standardId ??= h.standardId;
    }
  }

  /// Baris buat satu nilai titik, toleran sama beda pembulatan.
  ///
  /// Kunci [titik] itu `double`, dan angkanya datang dari dua sumber yang
  /// nggak dijamin bit-identik: bentuk lembar dari backend, dan kolom
  /// `decimal(20,8)` yang dibaca ulang dari DB. `111.193568` yang bolak-balik
  /// lewat JSON gampang meleset di digit terakhir, dan `Map` nggak peduli
  /// selisihnya sekecil apa — barisnya dianggap nggak ada, angkanya kebuang.
  TitikState? _titikTerdekat(double titikUkur) {
    final persis = titik[titikUkur];
    if (persis != null) return persis;

    for (final e in titik.entries) {
      if (_titikSama(e.key, titikUkur)) return e.value;
    }

    return null;
  }

  /// Sama kayak [_titikTerdekat], tapi balikin KUNCI-nya.
  ///
  /// Kuncinya nggak selalu sama dengan nilai titiknya: tabel yang titiknya
  /// kembar (matriks Autoklaf — delapan baris besaran dengan `titik_ukur` nol
  /// semua) dikunci pakai INDEKS baris. Penanda sel dibangun dari kunci itu,
  /// jadi yang dicari di sini kuncinya.
  double? _kunciTitikTerdekat(double titikUkur) {
    if (titik.containsKey(titikUkur)) return titikUkur;

    for (final k in titik.keys) {
      if (_titikSama(k, titikUkur)) return k;
    }

    return null;
  }

  /// Dua nilai titik ukur menunjuk baris yang sama?
  ///
  /// Toleransinya RELATIF, bukan absolut: titiknya berkisar dari 1,412 sampai
  /// 12880, jadi satu ambang tetap bakal kelewat longgar di ujung bawah dan
  /// kelewat ketat di ujung atas.
  static bool _titikSama(double a, double b) =>
      (a - b).abs() <= math.max(a.abs(), b.abs()) * 1e-6;

  /// Tempel balik salinan dari [salinIsianTitik] sesudah bentuk lembar diganti.
  ///
  /// Balikin JUMLAH TITIK yang isinya kebuang karena barisnya udah nggak ada di
  /// bentuk yang baru. Angka itu WAJIB dipakai buat ngasih tau teknisi — isian
  /// kalibrasi yang ilang diam-diam jauh lebih bahaya daripada formulir yang
  /// bentuknya salah, karena nggak ada yang tau angkanya pernah ada.
  ///
  /// Kasus nyatanya: lembar generik Conductivity punya baris `1412 µS/cm` DAN
  /// `1,412 mS/cm`; begitu alatnya dipilih, cuma satu yang tersisa.
  int tempelIsianTitik(Map<double, Map<String, String>> dari) {
    var kebuang = 0;

    for (final e in dari.entries) {
      final tujuan = titik[e.key];

      if (tujuan == null) {
        kebuang++;
        continue;
      }

      tujuan.tempelKotak(e.value);
    }

    return kebuang;
  }

  /// Rentang ukur / kapasitas / resolusi yang diketik teknisi, siap kirim.
  ///
  /// Kuncinya diambil dari BENTUK lembar kerja (`spesifikasi_alat.<kunci>`),
  /// bukan didaftar di sini: alat berikutnya bisa punya baris yang beda, dan
  /// daftar kedua di HP itu tempat paling gampang dua sisi jadi nggak sama.
  ///
  /// Yang kosong nggak ikut — biar `PUT` draft bertahap nggak ngosongin yang
  /// udah keisi sebelumnya.
  Map<String, String> get spesifikasiAlat => {
    for (final bagian in bentuk.bagian)
      for (final f in bagian.field)
        if (f.spesifikasiAlat && (teks[f.kode]?.text.trim().isNotEmpty ?? false))
          f.kunciSpesifikasi: teks[f.kode]!.text.trim(),
  };

  /// Susun payload. **Nggak ada validasi di sini** — apa pun kondisinya, isian
  /// yang ada dikirim apa adanya. Yang nahan sertifikat terbit itu pemeriksaan
  /// admin, bukan formulirnya.
  LembarKerjaSubmission toSubmission({required bool draft}) {
    // Kolom yang syarat tampilnya nggak kepenuhan dikosongin DI SINI juga,
    // bukan cuma waktu dropdown-nya diubah: draft yang dipulihkan bisa bawa
    // `room_id` dari sebelum aturan ini ada, dan teknisi yang cuma ngelanjutin
    // ngisi nggak pernah nyentuh dropdown lokasinya. Lihat
    // [bersihkanFieldTersembunyi] soal sertifikat Insitu yang kecetak nama
    // ruang lab.
    bersihkanFieldTersembunyi();

    // Urutan LEMBAR, bukan urutan angka.
    //
    // `titik` dibangun ngikut baris di `bentuk`, jadi urutan aslinya udah
    // bener; dulu di sini diurut ulang naik berdasarkan `titikUkur` dan itu
    // yang ngerusak. Backend ngasih `titik_ke` dari posisi array ini, dan
    // sertifikat nyetak barisnya per `titik_ke` — jadi urutannya mendarat
    // langsung di dokumen.
    //
    // Buat lembar yang satuannya CAMPUR, urutan angka bukan urutan lembar:
    //
    //  - varian µS/cm → 25 < 111 < 1412, titik tengah kelempar ke baris 3
    //  - varian mS/cm → 1,412 < 25 < 111, titik tengah naik ke baris 1
    //
    // Master lab-nya sendiri urut `25 µS/cm → 1412 µS/cm → 111 mS/cm`. Sesi 51
    // yang angkanya udah cocok sama master tetap kesimpen `[25, 111.193568,
    // 1412]` gara-gara ini.
    //
    // Baris yang sama sekali belum disentuh tetap ikut dikirim: backend nyimpen
    // titiknya mentah (nggak dihitung) dan itu yang bikin lembar kerja setengah
    // jadi tetap kebaca utuh sama admin — kolom mana yang kosong kelihatan,
    // bukan ilang dari tabel.
    final measurements = titik.values.map((t) => t.toSubmission()).toList();

    // Lembar ber-GRID nggak punya `titik` sama sekali — bentuknya nggak
    // mengirim `tabel`, jadi `measurements` di atas selalu kosong. Set point-nya
    // disusun dari isian grid, dan yang benar-benar kosong dibuang di sana.
    grid?.bacaUlang();
    final measurementsGrid = grid?.payload(
      satuan: bentuk.satuanSuhu,
      // Kolom Channel cuma diisi kalau kalibratornya berkanal. Kalau merk-nya
      // belum ketahuan (standar belum dipilih), kanal yang terlanjur diketik
      // tetap dikirim — backend yang menolaknya kalau memang nggak relevan,
      // dan itu lebih jujur daripada layar diam-diam membuang angka yang
      // sudah diketik teknisi.
      pakaiChannel: true,
    );


    return LembarKerjaSubmission(
      equipmentId: alat!.id,
      clientRequestId: clientRequestId,
      simpanSebagaiDraft: draft,
      standardId: standardId,
      roomId: roomId,
      lokasi: lokasi,
      lokasiNama: kalimat('lokasi_nama'),
      tanggalKalibrasi: tanggal['tanggal_kalibrasi'],
      tanggalTerima: tanggal['tanggal_terima'],
      suhuAwal: angka('suhu_awal'),
      suhuAkhir: angka('suhu_akhir'),
      kelembabanAwal: angka('kelembaban_awal'),
      kelembabanAkhir: angka('kelembaban_akhir'),
      // Cuma Gas Detector yang lembarnya punya dua kolom ini; alat lain nggak
      // punya kotaknya, `angka()` balikin null, dan kuncinya nggak kekirim.
      // Buat Gas Detector dua angka ini nentuin komponen suhu & tekanan di
      // budget-nya — kalau kelewat, U95-nya keluar terlalu kecil tanpa satu
      // pun error.
      tekananAwal: angka('tekanan_awal'),
      tekananAkhir: angka('tekanan_akhir'),
      // Dua-duanya nentuin ANGKA, bukan catatan: mode nentuin arah
      // perhitungan koreksi (kolom Standard & UUT bertukar sisi), tipe sensor
      // nentuin tabel koreksi kalibrator mana yang dibaca. Kalau kelewat,
      // backend nolak ngitung seluruh titiknya — bukan ngeluarin angka yang
      // salah diam-diam.
      //
      // `mode_kalibrasi` cuma dipunyai TITS. `tipe_sensor` dipunyai TITS DAN
      // Enclosure — dikirim dari sini buat dua-duanya, jadi lembar Enclosure
      // nggak perlu jalur simpan sendiri. Lembar yang nggak punya kolomnya
      // ngirim null, dan backend memang nerima itu.
      modeKalibrasi: kalimat('mode_kalibrasi'),
      tipeSensor: kalimat('tipe_sensor'),
      catatanTeknisi: kalimat('catatan_teknisi'),
      thermohygroStandardId: thermohygroStandardId,
      alatModel: kalimat('alat_model'),
      alatSerialNumber: kalimat('alat_serial_number'),
      alatMerk: kalimat('alat_merk'),
      pemilikNama: kalimat('pemilik_nama'),
      pemilikAlamat: kalimat('pemilik_alamat'),
      equipmentSatuan: satuanBisaDipilih ? satuan : null,
      spesifikasiAlat: spesifikasiAlat,
      standarDicek: usageCheck.values
          .where((u) => u.adaIsian)
          .map((u) => u.toSubmission())
          .toList(),
      measurements: measurements,
      measurementsGrid: measurementsGrid,
      inputMethod: adaIsianDariFoto ? MetodeInput.ocr : MetodeInput.manual,
    );
  }

  /// Ringkasan buat layar konfirmasi sebelum kirim — satu baris per larutan
  /// standar, urutannya sama kayak tabelnya.
  ///
  /// Yang dirata-rata cuma tahap **After adjustment**: itu yang jadi Unit Under
  /// Test di sertifikat. As-found (Before) sengaja nggak ikut biar angka yang
  /// dilihat teknisi di sini sama dengan yang nanti kecetak.
  List<RingkasanTitik> ringkasanKirim() => [
    for (final t in titikUrut)
      () {
        final isi = [
          for (var i = 0; i < t.jumlahPengulangan; i++)
            parseAngka(t.kotak('sesudah_adjustment', 'pembacaan', i).text),
        ].whereType<double>().toList();

        return RingkasanTitik(
          label: t.label,
          satuan: t.satuan,
          terisi: isi.length,
          total: t.jumlahPengulangan,
          // Alat yang resolusinya beda per titik (Turbidimeter) ngirim
          // `desimal` sendiri per baris; yang nggak ngirim itu alat resolusi
          // seragam, dan yang bener dipakai resolusi alatnya.
          //
          // Dulu di sini angkanya dipatok 2, waktu tiga alat pertama
          // resolusinya 0,01 semua. Refractometer resolusinya 0,0001, dan
          // pematokan itu bikin `1,3362` tampil `1,34` — teknisi mbandingin ke
          // kertas, ketemu angka yang beda, padahal isiannya bener.
          desimal: t.desimal ?? desimalDariResolusi(alat?.resolusi) ?? 2,
          rataRata: isi.isEmpty
              ? null
              : isi.reduce((a, b) => a + b) / isi.length,
        );
      }(),
  ];

  /// Titik diurut naik (4 / 7 / 10,01) — urutan yang sama dipakai parser OCR
  /// waktu misahin kolom, dan urutan yang dikirim ke backend.
  List<TitikState> get titikUrut =>
      titik.values.toList()..sort((a, b) => a.titikUkur.compareTo(b.titikUkur));

  /// Titik milik SATU tabel, urut nilai — bukan seluruh titik lembar.
  ///
  /// Bedanya baru kelihatan di alat yang punya lebih dari satu tabel dengan
  /// titik yang beda-beda. Spectrophotometer punya TIGA (Holmium 10 titik nm,
  /// Didynium 9 titik nm, %T 5 titik): [titikUrut] ngasih 24 titik campur dua
  /// satuan, jadi foto satu tabel dikasih tahu "harap 24 kolom" dan angkanya
  /// diadu ke nilai standar milik tabel lain.
  ///
  /// Alat satu-tabel lewat sini juga dan hasilnya sama persis kayak dulu.
  List<TitikState> titikTabel(TabelHasil tabel) {
    final punyaTabel = {
      for (final b in barisTabel(tabel)) b.titikUkur,
    };

    return [
      for (final t in titikUrut)
        if (punyaTabel.contains(t.titikUkur)) t,
    ];
  }

  /// Berapa sel yang bisa diisi satu tabel — buat pesan "x dari y sel".
  /// Dua kolom per pengulangan: pH & °C.
  int get selPerTabel =>
      titikUrut.fold(0, (jumlah, t) => jumlah + t.jumlahPengulangan * 2);

  /// Versi [selPerTabel] yang ngitung SATU tabel — dipakai pesan "x dari y sel"
  /// sesudah foto, biar angkanya nggak ngitung tabel yang nggak difoto.
  int selPerTabelIni(TabelHasil tabel) => titikTabel(tabel).fold(
    0,
    (jumlah, t) => jumlah + t.jumlahPengulangan * tabel.kolom.length,
  );

  /// Tuang angka hasil pindai yang UDAH lewat layar review ke kotak isian.
  /// Balikin jumlah sel yang beneran keisi.
  ///
  /// Yang masuk ke sini bukan bacaan mentah OCR: [sel] isinya angka yang
  /// teknisi setujui di `PindaiReviewScreen`, sesudah dia mbandingin tiap sel
  /// kuning & merah sama potongan citranya. Hasil pindai itu USULAN — yang
  /// bikin dia jadi data cuma persetujuan orang.
  ///
  /// **Selnya dicari lewat titik ukur + tahap + nomor Repeat, bukan urutan
  /// array.** Aturannya sama kayak kunci sel di sisi server: begitu ada satu
  /// tahap yang ngandelin urutan, angka bisa mendarat di baris sebelah tanpa
  /// satu pun error muncul. Sel yang titik ukurnya nggak ada di lembar ini
  /// DIBUANG, bukan dipaksa masuk ke baris terdekat.
  int terapkanHasilPindai(List<SelDipakaiPindai> sel) {
    var terisi = 0;

    for (final s in sel) {
      final state = _titikTerdekat(s.titikUkur);
      if (state == null) continue;

      // `repeat_no` di server 1-based, index kotak di sini 0-based.
      final index = s.repeatNo - 1;
      if (index < 0 || index >= state.jumlahPengulangan) continue;

      terisi += _isiSel(state, s.tahap, s.fieldId, index, s.nilai, s.perluDicek);
    }

    if (terisi > 0) adaIsianDariFoto = true;

    return terisi;
  }
  /// Tuang hasil FOTO SATU TABEL ke kotak isian tabel itu.
  ///
  /// Bedanya dari [terapkanHasilPindai]: yang ini nggak lewat server. Fotonya
  /// dibaca di HP, dipetakan `PetaTabelFoto` lewat jangkar yang tercetak di
  /// tabelnya sendiri, dan hasilnya langsung masuk kotak — **semuanya ditandai
  /// perlu dicek**, tanpa kecuali.
  ///
  /// Nggak ada vonis hijau di jalur ini, dan itu disengaja: tanpa server nggak
  /// ada yang mengadu angkanya ke rentang titik, resolusi alat, atau sebaran
  /// antar-Repeat. Yang tersisa cuma mata teknisi, jadi tiap sel yang keisi
  /// dari foto ditandai — bukan sebagian.
  ///
  /// Sel yang sudah ada isinya nggak pernah ditimpa, sama seperti jalur lain.
  int terapkanHasilFotoTabel(
    List<SelTabelFoto> sel, {
    required String tahap,
  }) {
    var terisi = 0;

    for (final s in sel) {
      final state = _titikTerdekat(s.titikUkur);
      if (state == null) continue;

      final index = s.repeatNo - 1;
      if (index < 0 || index >= state.jumlahPengulangan) continue;

      // Teksnya dibaca jadi angka DI SINI, bukan di pemetanya: yang di sana
      // cuma menjawab "tempatnya di mana", dan mencampur dua urusan itu bikin
      // aturan angka tersebar di dua tempat.
      final nilai = parseAngka(s.teks);
      if (nilai == null) continue;

      terisi += _isiSel(state, tahap, s.fieldId, index, nilai, true);
    }

    if (terisi > 0) adaIsianDariFoto = true;

    return terisi;
  }

  void _tandai(String kunci, bool perluDicek) {
    if (perluDicek) {
      selRendahKeyakinan.add(kunci);
    } else {
      selRendahKeyakinan.remove(kunci);
    }
  }

  int _isiSel(
    TitikState state,
    String tahap,
    String kolom,
    int index,
    double? nilai,
    bool perluDicek,
  ) {
    final kotak = state.kotak(tahap, kolom, index);
    // Pembacaan dipad ke resolusi titiknya (4,60), suhu nggak.
    //
    // Titik yang nggak ngirim `desimal` sendiri (alat resolusi seragam) ikut
    // resolusi ALATNYA — aturan yang sama kayak di `ringkasanKirim`. Tanpa ini
    // Refractometer jatuh ke jalur tanpa desimal, dan pembacaannya kepotong.
    final desimal = kolom == 'pembacaan'
        ? state.desimal ?? desimalDariResolusi(alat?.resolusi)
        : null;
    final baru = GabungTabel.nilaiBaru(kotak.text, nilai, desimal: desimal);
    if (baru == null) return 0;

    kotak.text = baru;

    // Sel yang vonis servernya kuning/merah ditandai; kalau pindai ulang
    // mengisinya dengan vonis bagus, tandanya dilepas.
    _tandai(kunciSel(state.titikUkur, tahap, kolom, index), perluDicek);

    return 1;
  }

  /// Isi kolom yang ditandai `sumber: otomatis` di formulir. Kode-nya bertitik
  /// (`equipment.merk`), jadi nggak pernah jadi kunci payload — murni tampilan.
  /// Alat dipilih → identitas alat & pemilik keisi sendiri dari master.
  ///
  /// Kompromi yang disengaja antara dua kebutuhan yang kelihatan bertabrakan:
  ///
  /// - Data master **udah ada** waktu pelanggannya didaftarin, jadi nyuruh
  ///   teknisi ngetik ulang nama PT & alamatnya di lapangan itu kerja dobel
  ///   yang bikin salah ketik.
  /// - Tapi yang sah di dokumen kalibrasi tetap yang **dibaca teknisi dari
  ///   badan alat & surat jalan** — master diisi admin dan sering beda sama
  ///   unit fisik yang beneran datang.
  ///
  /// Jadi: keisi otomatis, TAPI tetap bisa diedit. Teknisi mulai dari data
  /// yang benar dan cuma nyentuh yang beda — bukan ngetik dari nol, bukan juga
  /// kekunci sama data master yang mungkin basi.
  ///
  /// Yang ditulis ulang cuma kolom yang **kosong** atau yang isinya masih persis
  /// seperti yang kita isi sendiri dari alat sebelumnya. Kolom yang teknisi
  /// ketik sendiri nggak pernah disentuh.
  ///
  /// Dulu aturannya cuma "isi yang kosong", dan itu bocor waktu teknisi GANTI
  /// alat: kolom yang keisi otomatis dari alat pertama ikut bertahan di lembar
  /// alat kedua. Kejadian nyatanya di HP 7 Agt 2026 — pilih Jangka Sorong,
  /// ganti ke Refractometer Atago, hasilnya Type/Model & Merk ikut alat baru
  /// (dua kolom itu kosong di Jangka Sorong) tapi Serial Number nyisa
  /// `MT-500-196-30` punya si jangka sorong. Satu blok identitas berisi dua
  /// alat berbeda, di dokumen yang justru gunanya nyatet alat mana yang
  /// dikalibrasi — dan nggak ada satu pun yang error.
  ///
  /// Nilai kosong dari alat baru **mengosongkan** kolomnya, bukan dilewat.
  /// Alat yang serial-nya belum kecatat di master mesti nampilin kotak kosong
  /// supaya teknisi ngisi dari badan alat; nyisain serial alat sebelumnya itu
  /// persis kegagalan yang bikin catatan ini ditulis.
  void isiDariAlat() {
    void isi(String kode, String? nilai) {
      final kotak = teks[kode];
      if (kotak == null) return;

      // Teknisi udah nyentuh kolom ini → berhenti, apa pun kata master.
      final sekarang = kotak.text.trim();
      if (sekarang.isNotEmpty && sekarang != _terisiDariAlat[kode]) return;

      final baru = nilai?.trim() ?? '';
      kotak.text = baru;

      if (baru.isEmpty) {
        _terisiDariAlat.remove(kode);
      } else {
        _terisiDariAlat[kode] = baru;
      }
    }

    isi('alat_model', alat?.model);
    isi('alat_serial_number', alat?.serialNumber);
    isi('alat_merk', alat?.merk);
    isi('pemilik_nama', alat?.pelangganNama);
    isi('pemilik_alamat', alat?.pelangganAlamat);

    _pilihkanSatuanDariAlat();
  }

  /// Nilai terakhir yang **kita** tulis ke tiap kolom dari master alat.
  ///
  /// Ini yang bikin [isiDariAlat] bisa mbedain "keisi otomatis dari alat
  /// sebelumnya" (boleh diperbarui) dari "diketik teknisi" (haram disentuh) —
  /// dua hal yang di `TextEditingController` kelihatan sama persis.
  final Map<String, String> _terisiDariAlat = {};

  /// Setel "7. Satuan Refracto" ke satuan yang kecatat di master alat.
  ///
  /// Alat yang didaftarin sebagai °Brix mesti kebuka sebagai °Brix, bukan
  /// balik ke bawaan formulir (n20D) dan nunggu teknisi sadar sendiri —
  /// pilihannya ngubah koefisien suhu, jadi yang kelewat nggak bikin error,
  /// cuma bikin sertifikatnya meleset.
  ///
  /// Aturannya sama persis kayak kolom teks di [isiDariAlat], dan karena alasan
  /// yang sama: pilihan yang **teknisi** buat sendiri haram disentuh, tapi yang
  /// **kita** setel sendiri waktu alat sebelumnya dipilih boleh diperbarui.
  ///
  /// Tanpa pembedaan itu, ganti dari alat n20D ke alat yang kecatat °Brix bakal
  /// ninggalin "n20D" di layar — dan satuan itu yang nentuin koefisien
  /// normalisasi suhu di backend (0,00045/°C vs 0,07/°C, beda 155 kali).
  void _pilihkanSatuanDariAlat() {
    // Pernah disetel, dan yang nyetel bukan kita → itu pilihan teknisi.
    if (_satuanPilihan != null && _satuanPilihan != _satuanDariAlat) return;

    final dariMaster = alat?.satuan.trim();
    if (dariMaster == null || dariMaster.isEmpty) return;

    for (final f in bentuk.bagian.expand((b) => b.field)) {
      if (f.kode != 'equipment.satuan') continue;

      for (final p in f.pilihan) {
        if (_satuanSama(p.nilai, dariMaster)) {
          satuan = p.nilai;
          _satuanDariAlat = p.nilai;
          return;
        }
      }
      return;
    }
  }

  /// Satuan terakhir yang **kita** setel dari master alat — pasangannya
  /// [_terisiDariAlat], buat kolom yang bukan kotak teks.
  String? _satuanDariAlat;

  /// Dua tulisan satuan ini menunjuk hal yang sama?
  ///
  /// Klausa `brix`-nya **nyontek `RefractometerProfile::satuan()` di backend**,
  /// yang nganggep ejaan apa pun yang mengandung "brix" sebagai °Brix. Bukan
  /// kerapian: labnya nulis `oBrix` di Excel, `°Brix` di lampiran akreditasi,
  /// jadi master alat bisa nyimpen salah satunya. Tanpa klausa ini yang `oBrix`
  /// nggak kecocok ke pilihan mana pun dan diam-diam jatuh ke n20D.
  static bool _satuanSama(String a, String b) {
    final x = a.toLowerCase().trim();
    final y = b.toLowerCase().trim();

    return x == y || (x.contains('brix') && y.contains('brix'));
  }

  String nilaiTurunan(
    String kode, {
    String? namaTeknisi,
    String? namaReviewer,
    String? kodeTeknisi,
  }) {
    return switch (kode) {
      'equipment.nama_alat' => alat?.namaAlat ?? '',
      'equipment.range_resolusi' => alat?.rangeResolusi ?? '',
      'equipment.model' => alat?.model ?? '',
      'equipment.serial_number' => alat?.serialNumber ?? '',
      'equipment.merk' => alat?.merk ?? '',
      'customer.nama' => alat?.pelangganNama ?? '',
      'customer.alamat' => alat?.pelangganAlamat ?? '',
      'teknisi.nama' => namaTeknisi ?? '',
      // "Technician ID" — inisial dari akun yang lagi login, dikirim backend.
      // Teknisi cuma lihat: yang kecetak di sertifikat diambil dari sesi, jadi
      // ngasih kotak isian di sini cuma bikin dua sumber yang bisa beda.
      'teknisi.kode' => kodeTeknisi ?? '',
      // "Checked by" sengaja kosong sampai admin nyetujuin — biar nggak ada
      // yang bisa ngaku-ngaku udah diperiksa.
      'reviewer.nama' => namaReviewer ?? '',
      'dimensi.volume' => _volumeEnclosure(),
      _ => '',
    };
  }

  /// Volume enclosure — DIHITUNG dari kotak dimensi, bukan diketik.
  ///
  /// Rumusnya persis masternya, dalam METER, tanpa satu pun faktor konversi:
  ///
  ///     balok    = P × L × T
  ///     silinder = π · r² · t
  ///
  /// ## Tiga hal yang sengaja BEDA dari master
  ///
  /// **1. Kosong tetap kosong.** Di master penjaganya bocor: rumusnya
  /// `IF(AND(r=0,t=0), P*L*T, "-")` dan kebalikannya, jadi waktu SEMUA kotak
  /// kosong dua-duanya kondisinya benar dan hasilnya `0`, bukan `"-"`. Di master
  /// Recorder itu beneran kejadian — blok dimensinya kosong total tapi volumenya
  /// terbaca `0 m³`. "Nol meter kubik" dan "belum diisi" itu dua hal beda, dan
  /// yang satu nggak boleh menyamar jadi yang lain.
  ///
  /// **2. Dua bentuk keisi barengan = nggak nampilin apa-apa.** Master milih
  /// diam-diam lewat urutan guard-nya. Di sini isian yang saling bertentangan
  /// nggak dijawab dengan salah satunya — teknisi yang ngisi P/L/T DAN jari-jari
  /// lagi bilang dua hal yang beda, dan nebak maksudnya bikin angka yang keluar
  /// nggak bisa ditelusuri balik ke yang dia ketik.
  ///
  /// **3. π-nya 3,14, bukan `math.pi`.** Ini niru masternya apa adanya — di sana
  /// π sel input biasa berisi 3,14, bukan fungsi `PI()`. Selisihnya ~0,05% di
  /// volume. Dipakai angka lab, bukan angka yang "lebih benar", supaya hasilnya
  /// sama dengan yang mereka hitung sendiri di kertas.
  ///
  /// Angkanya sendiri nggak masuk perhitungan ketidakpastian dan nggak kecetak
  /// di sertifikat — sudah ditelusuri dua arah di dua master, sel volumenya nol
  /// konsumen. Jadi ini murni catatan lembar kerja.
  String _volumeEnclosure() {
    double? angka(String kode) {
      final teksnya = teks[kode]?.text.trim().replaceAll(',', '.');
      if (teksnya == null || teksnya.isEmpty) return null;
      final n = double.tryParse(teksnya);

      return (n == null || n <= 0) ? null : n;
    }

    final p = angka('dimensi_panjang');
    final l = angka('dimensi_lebar');
    final t = angka('dimensi_tinggi');
    final r = angka('dimensi_jari_jari');
    final ts = angka('dimensi_tinggi_silinder');

    final balok = (p != null && l != null && t != null) ? p * l * t : null;
    final silinder = (r != null && ts != null) ? 3.14 * r * r * ts : null;

    // Dua-duanya keisi = isian saling bertentangan. Lihat catatan 2 di atas.
    if (balok != null && silinder != null) return '';

    final volume = balok ?? silinder;
    if (volume == null) return '';

    // Dipotong 4 desimal lalu nol di belakang dibuang: 0,125 tetap `0,125`,
    // bukan `0,1250`. Koma, bukan titik — ini yang dibaca teknisi, dan seluruh
    // lembar lain juga pakai koma.
    final dipotong = volume
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return dipotong.replaceAll('.', ',');
  }

  /// Kunci satu sel matriks: jalur data barisnya + nomor titik waktu.
  ///
  /// Jalur data (`suhu.disk.0`) yang dipakai, bukan index baris — supaya
  /// urutan baris di layar nggak memikul arti. Baris kegeser cuma bikin
  /// tampilannya beda urutan, bukan bikin angkanya pindah besaran.
  static String kunciMatriks(String kodeData, int titikWaktu) =>
      '$kodeData#$titikWaktu';

  TextEditingController kotakMatriks(String kodeData, int titikWaktu) =>
      matriks.putIfAbsent(
        kunciMatriks(kodeData, titikWaktu),
        () => TextEditingController()
          ..addListener(() => onIsianDiketik?.call()),
      );

/// Rakit blok data ukur untuk lembar bertabel matriks (Autoklaf).
  ///
  /// Angkanya ditulis ke jalur yang DITENTUKAN BACKEND (`BarisMatriks.kodeData`
  /// — `suhu.disk.0`, `tekanan.indikator_pressure`), bukan ke jalur yang
  /// dihafal layar. Bedanya kelihatan waktu formulirnya direvisi: baris yang
  /// pindah urutan di kertas cuma mengubah tampilannya, nggak mengubah besaran
  /// mana yang dikirim ke mana.
  ///
  /// Blok `suhu` dan `tekanan` cuma ikut kalau ADA ISINYA. Blok kosong yang
  /// tetap dikirim bikin backend menghitung rata-rata dari daftar null.
  ///
  /// `tekanan.uut_setting` sengaja NGGAK dikirim: di kertas angka itu ada di
  /// baris Indikator Pressure, dan backend yang mutusin — kalau kelima
  /// kolomnya sama, itu yang kepakai; kalau beda, kirimannya ditolak dengan
  /// pesan jelas. Merata-rata di layar bikin angka yang nggak pernah ditulis
  /// siapa pun ikut ke sertifikat.
  Map<String, dynamic> payloadMatriks(MatriksHasil m, TabelSatuBaris? tambahan) {
    final hasil = <String, dynamic>{};

    void tulis(String jalur, List<dynamic> nilai) {
      if (nilai.every((v) => v == null)) return;

      final bagian = jalur.split('.');
      dynamic wadah = hasil;

      for (var i = 0; i < bagian.length - 1; i++) {
        final kunci = bagian[i];
        final berikutnyaIndex = int.tryParse(bagian[i + 1]) != null;

        wadah = (wadah as Map<String, dynamic>).putIfAbsent(
          kunci,
          () => berikutnyaIndex ? <String, dynamic>{} : <String, dynamic>{},
        );
      }

      (wadah as Map<String, dynamic>)[bagian.last] = nilai;
    }

    for (final b in m.semuaBaris) {
      if (b.kodeData.isEmpty) continue;

      tulis(b.kodeData, [
        for (final t in m.titikWaktu)
          _nilaiSelMatriks(b, LembarKerjaState.kunciMatriks(b.kodeData, t)),
      ]);
    }

    if (tambahan != null && tambahan.kodeData.isNotEmpty) {
      tulis(tambahan.kodeData, [
        for (final t in tambahan.pengulangan)
          parseAngka(
            matriks[LembarKerjaState.kunciMatriks(tambahan.kodeData, t)]?.text ??
                '',
          ),
      ]);
    }

    // Dua kolom pressure yang jalur payload-nya beda dari kode kolomnya. Ditulis
    // terang di sini, bukan disembunyiin di pemetaan umum: cuma ini yang nggak
    // bisa diturunkan dari `kode_data`, dan sisanya jangan ikut-ikutan.
    const jalurField = {
      'satuan_tekanan': 'tekanan.satuan',
      'display_tekanan': 'tekanan.display',
    };

    for (final e in jalurField.entries) {
      final nilai = teks[e.key]?.text.trim();
      if (nilai == null || nilai.isEmpty) continue;
      if (!hasil.containsKey('tekanan')) continue;
      (hasil['tekanan'] as Map<String, dynamic>)[e.value.split('.').last] =
          nilai;
    }

    // `suhu.disk` di API itu daftar-di-dalam-daftar (`suhu.disk.*.*`), jadi
    // wadah bernomor yang kebentuk dari jalur `suhu.disk.0` diratakan jadi
    // List sesuai urutan nomornya.
    _ratakanWadahBernomor(hasil);

    final setPoint = parseAngka(teks['set_point']?.text ?? '');
    if (setPoint != null) hasil['set_point'] = setPoint;

    return hasil;
  }

  /// Baris `Time` dirapikan jadi `HH:MM:SS`; sisanya jadi angka.
  ///
  /// Dulu jamnya dikirim APA ADANYA, dan itu jalan buntu yang diam: backend
  /// nuntut `date_format:H:i,H:i:s`, jadi `8:30` ditolak dengan `The waktu.0
  /// field must match the format H:i` — nama kolom yang nggak ada di kertas
  /// kerja teknisi.
  ///
  /// Sekarang kotaknya sendiri udah nyisipin titik dua sambil diketik
  /// ([FormatJamLembar]), jadi normalisasi di sini perannya jaring pengaman
  /// buat draft yang terlanjur kesimpen sebelum formatter itu ada.
  ///
  /// Yang nggak bisa dirapikan dikirim apa adanya, BUKAN dibuang diam-diam:
  /// jam ngawur yang hilang sendiri bikin teknisi ngira isiannya kesimpen.
  /// Biar backend yang nolak — dan [jamMatriksNgawur] yang nahan duluan di
  /// layar dengan pesan yang nyebut kolomnya.
  dynamic _nilaiSelMatriks(BarisMatriks b, String kunci) {
    final teksSel = matriks[kunci]?.text.trim() ?? '';
    if (teksSel.isEmpty) return null;
    if (!b.jam) return parseAngka(teksSel);

    return normalisasiJam(teksSel) ?? teksSel;
  }

  /// Titik waktu ke-berapa saja yang keisi tapi bentuknya nggak kebaca.
  ///
  /// Dipakai buat nahan di layar sebelum ngirim, dengan pesan yang nyebut
  /// kolomnya — bukan `waktu.0` punya server.
  List<int> jamMatriksNgawur() {
    final bagian = bagianMatriks;
    final m = bagian?.matriks;
    if (m == null) return const [];

    final ngawur = <int>[];

    for (final b in m.semuaBaris.where((b) => b.jam)) {
      for (final t in m.titikWaktu) {
        final teksSel =
            matriks[LembarKerjaState.kunciMatriks(b.kodeData, t)]?.text.trim() ??
            '';
        if (teksSel.isEmpty) continue;
        if (normalisasiJam(teksSel) == null) ngawur.add(t);
      }
    }

    return ngawur;
  }

  void _ratakanWadahBernomor(Map<String, dynamic> wadah) {
    for (final kunci in wadah.keys.toList()) {
      final isi = wadah[kunci];
      if (isi is! Map<String, dynamic>) continue;

      final nomor = isi.keys.map(int.tryParse).toList();

      if (nomor.isNotEmpty && nomor.every((n) => n != null)) {
        final urut = [...isi.keys]..sort(
          (a, b) => int.parse(a).compareTo(int.parse(b)),
        );
        wadah[kunci] = [for (final k in urut) isi[k]];
      } else {
        _ratakanWadahBernomor(isi);
      }
    }
  }

/// Bagian yang punya tabel matriks. Null buat sembilan alat lain.
  BagianLembarKerja? get bagianMatriks {
    for (final b in bentuk.bagian) {
      if (b.matriks != null) return b;
    }
    return null;
  }

  /// Ada minimal satu sel matriks yang keisi — syarat minta pratinjau.
  ///
  /// Kepisah dari [titik] karena teknisi ngetik ke [matriks], bukan ke sana.
  /// Dipakai `titik` sebagai syarat, pratinjaunya nggak pernah kepanggil dan
  /// panel hasilnya diam terus tanpa satu pun tanda kenapa.
  bool get adaIsianMatriks =>
      matriks.values.any((c) => c.text.trim().isNotEmpty);

  /// Payload simpan lembar bermatriks: data ukur + identitas sesi.
  ///
  /// Bentuknya ngikut `POST /calibrations/autoclave` — alat, tanggal, dan
  /// kondisi lingkungan di level atas, bukan dibungkus `measurements[]`.
  /// Alat & tanggal kalibrasi wajib buat kirim; sisanya opsional, karena kolom
  /// yang belum keisi di lapangan nggak boleh nahan kiriman.
  Map<String, dynamic> payloadSimpanMatriks(
    BagianLembarKerja bagian, {
    required bool draft,
  }) {
    final tanggalKalibrasi = tanggal['tanggal_kalibrasi'];
    final tanggalTerima = tanggal['tanggal_terima'];

    return {
      ...payloadMatriks(bagian.matriks!, bagian.tabelTambahan),
      'equipment_id': alat?.id,
      'client_request_id': clientRequestId,
      // Draft ditandai lewat `status`, dan itu yang melonggarkan kolom wajib
      // di server. Tanpa kunci ini, draft setengah jadi ditolak 422 karena
      // `set_point` & tanggal kalibrasi belum keisi.
      if (draft) 'status': 'draft',
      if (tanggalKalibrasi != null)
        'tanggal_kalibrasi': tanggalKalibrasi.toIso8601String().substring(0, 10),
      if (tanggalTerima != null)
        'tanggal_terima': tanggalTerima.toIso8601String().substring(0, 10),
      'lokasi': lokasi.name,
      if (thermohygroStandardId != null)
        'thermohygro_standard_id': thermohygroStandardId,
      if (angka('suhu_awal') != null) 'suhu_awal': angka('suhu_awal'),
      if (angka('suhu_akhir') != null) 'suhu_akhir': angka('suhu_akhir'),
      if (angka('kelembaban_awal') != null)
        'kelembaban_awal': angka('kelembaban_awal'),
      if (angka('kelembaban_akhir') != null)
        'kelembaban_akhir': angka('kelembaban_akhir'),
      if (kalimat('pemilik_nama') != null)
        'pemilik_nama': kalimat('pemilik_nama'),
      if (kalimat('pemilik_alamat') != null)
        'pemilik_alamat': kalimat('pemilik_alamat'),
      if (kalimat('alat_merk') != null) 'alat_merk': kalimat('alat_merk'),
      if (kalimat('alat_model') != null) 'alat_model': kalimat('alat_model'),
      if (kalimat('alat_serial_number') != null)
        'alat_serial_number': kalimat('alat_serial_number'),
      if (kalimat('catatan_teknisi') != null)
        'catatan_teknisi': kalimat('catatan_teknisi'),
    };
  }

  void dispose() {
    for (final c in teks.values) {
      c.dispose();
    }
    for (final c in matriks.values) {
      c.dispose();
    }
    for (final t in titik.values) {
      t.dispose();
    }
    for (final u in usageCheck.values) {
      u.dispose();
    }
    grid?.dispose();
  }
}
