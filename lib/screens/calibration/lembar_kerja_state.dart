import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

import '../../core/utils/angka.dart';
import '../../models/calibration_detail.dart'
    show
        IsianTeknisi,
        MeasurementResult,
        RawMeasurement,
        StatusStandar,
        TahapPembacaan;
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

/// Pecah isi kotak [TipeField.daftarAngka] jadi daftar angka.
///
/// Pemisah utamanya `+` — itu yang ditulis teknisi karena itu yang dia lakukan
/// (menumpuk keping anak timbangan: `20+20+10`). Titik-koma dan spasi ikut
/// diterima; kertas masternya sendiri menulisnya campur, dan menolak salah
/// satunya cuma bikin isian yang benar hilang di lapangan.
///
/// **Koma BUKAN pemisah** di sini, dan itu bukan kelalaian: koma itu koma
/// desimal ([parseAngka] menerimanya), jadi `20,5+10` wajib jadi `[20.5, 10]`.
/// Dibaca sebagai pemisah, dia jadi `[20, 5, 10]` — tiga keping bukan dua,
/// jumlah nominalnya melar 14,5 jadi 35, dan slot Mass-nya geser semua. Nggak
/// ada satu pun error di jalur itu; yang salah cuma seluruh titiknya.
///
/// Potongan yang nggak kebaca sebagai angka dibuang, bukan bikin seluruh
/// kotaknya gagal.
List<double> pecahDaftarAngka(String isi) => [
  for (final bagian in isi.split(RegExp(r'[+;\s]+')))
    if (parseAngka(bagian) case final double n) n,
];

/// Balikin angka ke bentuk yang enak diketik ulang: `22.5`, bukan `22.500000`
/// — dan bilangan bulat tanpa `.0` yang bikin teknisi ngira ada desimal
/// tersembunyi.
String formatAngka(double nilai) =>
    nilai == nilai.roundToDouble() ? nilai.toStringAsFixed(0) : '$nilai';

/// Kuning "diisi kamera — PERIKSA".
///
/// SATU tempat buat tiga penggambar: sel tabel ([TandaSel.keyakinanRendah]),
/// kotak grid Enclosure, dan sel matriks Autoklaf. Sengaja dipusatkan: warnanya
/// itu satu-satunya yang membedakan angka yang diketik orang dari angka yang
/// ditebak mesin, dan tiga nada kuning yang mirip-tapi-beda mengajari mata
/// teknisi bahwa bedanya nggak berarti apa-apa.
///
/// Sempat disalin bertiga sebagai literal, lengkap dengan tiga komentar yang
/// sama-sama mewanti "warnanya wajib persis sama" — persis risiko yang mereka
/// peringatkan.
const kuningPerluDicek = Color(0xFFB8860B);

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
    this.parameter,
    this.titikDitentukan = true,
    int? noProbeAwal,
  }) : standardId = standardIdTercetak,
       noProbeCtl = TextEditingController(text: noProbeAwal?.toString() ?? ''),
       titikCtl = TextEditingController(),
       _kotak = {};

  /// Dipanggil tiap ANGKA di baris ini berubah.
  ///
  /// Sel angka nggak punya `onChanged` — sengaja: rebuild seluruh formulir tiap
  /// ketukan tombol bikin tabel 87 kotak (Spectrophotometer) tersendat di HP.
  /// Jadi kabarnya lewat listener controller, dan yang dengerin milih sendiri
  /// mau ngapain. Layar cuma pakai buat NJADWALIN pratinjau, tanpa `setState`.
  final VoidCallback? onKetik;

  final double titikUkur;

  /// [titikUkur] beneran set point, bukan cuma penanda posisi baris.
  ///
  /// `false` cuma di lembar TIDS: kertasnya mencetak tujuh baris `Setpoint`
  /// KOSONG, dan angkanya ditulis teknisi di lapangan. Lihat
  /// [BarisTabelHasil.titikDitentukan].
  final bool titikDitentukan;

  /// Kotak `Setpoint` baris ini — cuma dipakai waktu [titikDitentukan] `false`.
  final TextEditingController titikCtl;

  /// Set point yang BERLAKU buat baris ini. `null` = belum diisi teknisi.
  ///
  /// **Ini yang dikirim, bukan [titikUkur].** Buat sembilan belas lembar lain
  /// keduanya sama; buat TIDS, [titikUkur] cuma nomor barisnya, dan
  /// mengirimnya apa adanya menerbitkan set point "1 °C … 7 °C" — angka yang
  /// nggak pernah diketik siapa pun dan nggak ditolak apa pun.
  double? get titikUkurEfektif =>
      titikDitentukan ? titikUkur : parseAngka(titikCtl.text);

  /// Baris ini boleh ikut dikirim.
  ///
  /// Baris bawaan SELALU boleh — termasuk yang sama sekali belum disentuh:
  /// backend menyimpan titiknya mentah, dan itu yang bikin lembar setengah jadi
  /// tetap kebaca utuh sama admin. Yang ditahan cuma baris yang set point-nya
  /// memang belum ada, karena baris begitu nggak punya identitas buat dihitung.
  bool get siapKirim => titikUkurEfektif != null;

  /// Besaran yang diukur baris ini: `suhu` / `kelembaban`.
  ///
  /// Cuma Thermohygrometer yang punya — satu lembar, dua besaran. Ikut ke
  /// `measurements[].parameter`, dan ikut jadi pembeda waktu memulihkan sesi:
  /// set point `50` ada di DUA tabel lembar itu (50 °C dan 50 %RH), jadi angka
  /// saja nggak cukup buat tahu baris mana yang dimaksud.
  final String? parameter;

  /// No. Termokopel probe standar yang dicelup di set point ini.
  ///
  /// Cuma Thermocouple. Penomorannya BEDA per tipe sensor dan itu dari
  /// kertasnya sendiri: Type K 1–16, Type N MULAI DARI 3 (TCN3…TCN12), RTD
  /// selalu 17. Nomor yang nggak menunjuk probe mana pun bikin backend menahan
  /// titiknya — bukan mengoreksinya nol.
  final TextEditingController noProbeCtl;

  int? get noProbe => int.tryParse(noProbeCtl.text.trim());

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
    // [titikUkurEfektif], BUKAN [titikUkur]. Bedanya cuma kelihatan di lembar
    // TIDS, dan di sana yang kedua nomor barisnya (1..7) — bukan set point.
    //
    // Dibandingkan ke nomor baris, teknisi yang mengetik set point 121,5 lalu
    // membaca 121,5 kena rasio 121,5 dan barisnya DITOLAK sebelum kirim.
    // Penjaga yang menahan angka sah persis kebalikan dari gunanya: yang dia
    // latih bukan ketelitian, tapi kebiasaan menekan lanjut tanpa membaca.
    final acuan = titikUkurEfektif;

    // Belum diisi = belum ada yang bisa dibandingkan. Barisnya juga nggak ikut
    // dikirim (lihat [siapKirim]), jadi nggak ada yang perlu ditahan.
    if (acuan == null || acuan == 0) return false;

    for (final entry in _kotak.entries) {
      final bagian = entry.key.split('|');
      if (bagian.length != 3 || bagian[1] != 'pembacaan') continue;

      final nilai = parseAngka(entry.value.text);
      if (nilai == null) continue;

      final rasio = nilai.abs() / acuan.abs();
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
  ///
  /// [titikCtl] ikut dihitung: di lembar TIDS kotak `Setpoint` itu isian
  /// teknisi, bukan bagian bentuk lembar. Nggak ikut, teknisi yang baru
  /// mengetik ketujuh set point-nya lalu menekan back **kehilangan semuanya
  /// tanpa satu pun konfirmasi** — layar mengira lembarnya masih perawan.
  bool get adaIsian =>
      _kotak.values.any((c) => c.text.trim().isNotEmpty) ||
      titikCtl.text.trim().isNotEmpty ||
      standardId != null;

  /// Ada ANGKA yang diketik di baris ini? Beda dari [adaIsian], dan bedanya
  /// penting: [adaIsian] ikut ngitung `standardId`, yang KEISI SEJAK AWAL dari
  /// standar tercetak lembar kerja.
  ///
  /// Dipakai buat ngunci baris pasangan. Kalau pakai [adaIsian], dua varian
  /// satuan langsung saling ngunci begitu lembarnya kebuka — sebelum teknisi
  /// ngetik apa pun — dan nyentang standar malah MEMATIKAN barisnya.
  bool get adaPembacaan => _kotak.values.any((c) => c.text.trim().isNotEmpty);

  /// Salinan isian sel baris ini, buat diselamatkan waktu BENTUK lembar
  /// berubah (mis. teknisi milih alat, dan baris varian satuan menyusut).
  ///
  /// Yang kosong nggak ikut disalin — biar nempelnya nggak nimpa apa pun.
  /// Isian yang perlu selamat waktu tabelnya dibangun ulang.
  ///
  /// Kotak `Setpoint` ikut lewat kunci bersandi (`titik||0`) — bentuk yang sama
  /// dengan sel biasa supaya [tempelKotak] nggak butuh cabang kedua. Tanpa dia,
  /// set point yang barusan diketik teknisi hilang tiap bentuknya disegarkan.
  Map<String, String> salinKotak() => {
    for (final e in _kotak.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text,
    if (!titikDitentukan && titikCtl.text.trim().isNotEmpty)
      kunciSetpoint: titikCtl.text,
  };

  /// Kunci sandi kotak `Setpoint` di dalam [salinKotak].
  static const kunciSetpoint = 'titik||0';

  /// Kebalikan [salinKotak]. Kunci yang bentuknya nggak dikenal dilewat, bukan
  /// bikin crash — salinan bisa datang dari bentuk lembar yang beda.
  void tempelKotak(Map<String, String> dari) {
    for (final e in dari.entries) {
      if (e.key == kunciSetpoint) {
        titikCtl.text = e.value;

        continue;
      }

      final bagian = e.key.split('|');
      if (bagian.length != 3) continue;
      final index = int.tryParse(bagian[2]);
      if (index == null) continue;
      kotak(bagian[0], bagian[1], index).text = e.value;
    }
  }

  /// Controller satu kotak tambahan baris ini.
  ///
  /// Nebeng [kotak] supaya ikut dapat semua yang sudah ada di sana sekaligus:
  /// listener pengetikan, pemulihan draft (`tahap|kolom|index`), dan
  /// pembuangan controller waktu layarnya ditutup. Awalan `kolombaris:`
  /// menjaganya nggak pernah bentrok dengan kode kolom tabel beneran.
  TextEditingController kotakBarisCtl(String tahap, String kode) =>
      kotak(tahap, 'kolombaris:$kode', 0);

  List<double?> _kolom(String tahap, String kolom) => List<double?>.generate(
    jumlahPengulangan,
    // Sel yang belum diisi jadi null, BUKAN dibuang — nomor Repeat-nya nggak
    // boleh geser. Lihat docblock TitikLembarKerja.
    (i) => parseAngka(kotak(tahap, kolom, i).text),
  );

  /// [kunciUtama] itu kunci sel tabel yang isinya jadi
  /// `measurements[].pembacaan` — lihat [LembarKerjaState.kunciTabelPembacaan].
  ///
  /// Dulu `sesudah_adjustment` MATI di sini. Sembilan belas lembar tabelnya
  /// memang bertahap `sesudah_adjustment`, jadi nggak ada yang kelihatan salah
  /// selama bertahun-tahun. Lembar TIDS tabelnya `pembacaan_uut`, dan
  /// akibatnya sunyi total: payloadnya terkirim dengan set point yang benar
  /// dan `pembacaan` NULL SEMUA — tiga puluh lima angka yang beneran diambil
  /// teknisi di lapangan nggak pernah nyampe server, di lembar yang penuh di
  /// layar dan tombol kirimnya jalan mulus.
  TitikLembarKerja toSubmission({
    String kunciUtama = 'sesudah_adjustment',
    List<FieldLembarKerja> kotakBaris = const [],
  }) {
    final titik = TitikLembarKerja(
      // `titikUkurEfektif`, bukan `titikUkur` — lihat docblock getternya.
      titikUkur: titikUkurEfektif ?? titikUkur,
      jumlahPengulangan: jumlahPengulangan,
      standardId: standardId,
      satuan: satuan.isEmpty ? null : satuan,
    );

    for (final f in kotakBaris) {
      final isi = kotakBarisCtl(kunciUtama, f.kode).text.trim();
      if (isi.isEmpty) continue;

      titik.kolomBaris[f.kode] = f.tipe == TipeField.daftarAngka
          ? pecahDaftarAngka(isi)
          : isi;
    }

    void salin(List<double?> dari, List<double?> ke) {
      for (var i = 0; i < ke.length && i < dari.length; i++) {
        ke[i] = dari[i];
      }
    }

    salin(_kolom(kunciUtama, 'pembacaan'), titik.pembacaan);
    salin(_kolom(kunciUtama, 'suhu'), titik.suhu);
    salin(_kolom('sebelum_adjustment', 'pembacaan'), titik.pembacaanSebelum);
    salin(_kolom('sebelum_adjustment', 'suhu'), titik.suhuSebelum);

    return titik;
  }

  /// Payload satu titik lembar PASANGAN — dua deret, bukan satu.
  ///
  /// Bentuknya `Map` biasa, bukan [TitikLembarKerja], karena kunci `standar` &
  /// `uut` nggak ada di sana dan menambahkannya berarti tujuh belas alat lain
  /// ikut mengirim dua kunci kosong tiap titik. Lewat jalur yang sama dengan
  /// grid Enclosure (`measurementsGrid`).
  ///
  /// Sel kosong tetap `null` DI POSISINYA, sama seperti [toSubmission]: kalau
  /// Repeat 2 kosong lalu dibuang, Repeat 3 naik jadi Repeat 2 dan seluruh
  /// nomor pengulangan geser.
  ///
  /// ## Kunci selnya DATANG DARI BENTUK, nggak boleh dipatok
  ///
  /// Dulu method ini membaca `_kolom('standar', …)` & `_kolom('uut', …)` —
  /// dua string mati. Itu benar cuma karena kebetulan: Thermocouple dan
  /// Termometer Gelas memang ber-`grup` `standar`/`uut`, jadi
  /// [TabelHasil.kunciTabel] mereka sama persis dengan string yang dipatok.
  ///
  /// **Thermohygrometer tidak.** Lembarnya empat tabel — `suhu_standar`,
  /// `suhu_uut`, `kelembaban_standar`, `kelembaban_uut` — karena satu lembar
  /// memuat DUA parameter, dan tanpa `grup` yang berbeda keempatnya bakal
  /// berebut satu kunci sel. Akibatnya seratus sel yang diketik teknisi dibaca
  /// dari kunci yang tidak pernah ada:
  ///
  ///     sel diisi 100  →  payload berisi 0, KOSONG 100
  ///
  /// Dan karena [pasanganKosong] membaca kunci yang sama, tiap titiknya
  /// dianggap belum disentuh lalu **dibuang** dari `measurements` — jadi yang
  /// berangkat ke server bukan sekadar deret null, tapi lembar tanpa satu pun
  /// titik. Nol error di kedua sisi; lembarnya penuh di layar dan tombol
  /// kirimnya jalan mulus. Persis kelas kegagalan yang sudah dicatat dua kali
  /// di berkas ini.
  ///
  /// Jadi [deret] wajib dipasok pemanggil, dari bentuk lembarnya sendiri.
  Map<String, dynamic> toSubmissionPasangan(DeretPasangan deret) => {
    // `titikUkurEfektif`, bukan `titikUkur` — sama seperti [toSubmission].
    //
    // Buat tiga lembar pasangan pertama (Thermocouple, Gelas, Thermohygro)
    // keduanya SELALU sama: set point-nya tercetak di kertas, jadi `titikUkur`
    // memang set point. Lembar TIDS nggak: kertasnya nyetak tujuh baris
    // Setpoint KOSONG, dan `titikUkur` di situ cuma nomor barisnya (1..7).
    // Dibiarkan mentah, tiap sesi TIDS terkirim dengan set point 1, 2, 3…
    // — angkanya lengkap, kolom `Correction` terbit, dan yang salah cuma
    // titik yang diklaim sertifikat. Nggak ada satu pun error di jalur itu.
    'titik_ukur': titikUkurEfektif ?? titikUkur,
    if (satuan.isNotEmpty) 'satuan': satuan,
    if (standardId != null) 'standard_id': standardId,
    if (parameter != null) 'parameter': parameter,
    if (noProbe != null) 'no_probe': noProbe,
    'standar': _deret(deret, deret.kunciStandar),
    'uut': _deret(deret, deret.kunciUut),
  };

  /// Satu deret pembacaan, bentuknya ikut JUMLAH KOLOM tabelnya.
  ///
  ///  - **Satu kolom** (ketiga alat suhu): daftar angka apa adanya —
  ///    `[100.1, 100.2, null]`. Bentuk yang sudah dipakai sejak alat ke-18.
  ///  - **Banyak kolom** (Timer/Stopwatch): daftar OBJEK berkunci kode kolom —
  ///    `[{jam: 0, menit: 1, detik: 0, milidetik: 123}, …]`, karena satu
  ///    penunjukan stopwatch ditulis di empat kotak dan keempatnya satu angka.
  ///
  /// Ulangan yang keempat kotaknya kosong dikirim `null`, BUKAN objek kosong.
  /// Dua alasannya sama-sama mengikat: posisinya harus tetap (lihat docblock di
  /// atas), dan aturan `PenunjukanWaktu` di server MENOLAK objek yang keempat
  /// kotaknya kosong — objek kosong bikin lembar setengah jadi kena 422 di
  /// ulangan yang memang sengaja dilewati.
  List<dynamic> _deret(DeretPasangan bentuk, String kunci) {
    // Kolom milik SISI INI, bukan kolom pasangannya — lihat
    // [DeretPasangan.kolomUut].
    final kolom = bentuk.kolomUntuk(kunci);

    if (kolom.length == 1) {
      return _kolom(kunci, kolom.first);
    }

    return List<Map<String, double>?>.generate(jumlahPengulangan, (i) {
      final isi = <String, double>{};

      for (final kode in kolom) {
        final nilai = parseAngka(kotak(kunci, kode, i).text);
        if (nilai != null) isi[kode] = nilai;
      }

      return isi.isEmpty ? null : isi;
    });
  }

  /// Titik lembar pasangan yang sama sekali belum disentuh — nggak ikut
  /// dikirim, sama seperti set point grid Enclosure yang kosong.
  ///
  /// Kuncinya lewat [deret] dengan alasan yang sama seperti
  /// [toSubmissionPasangan]: kunci yang dipatok bikin SETIAP titik Thermohygro
  /// kelihatan kosong, dan seluruh lembarnya dibuang sebelum dikirim.
  bool pasanganKosong(DeretPasangan deret) =>
      _deret(deret, deret.kunciStandar).every((n) => n == null) &&
      _deret(deret, deret.kunciUut).every((n) => n == null);

  void dispose() {
    noProbeCtl.dispose();
    titikCtl.dispose();
    for (final c in _kotak.values) {
      c.dispose();
    }
  }
}

/// Kunci sel & kolom KEDUA tabel deret satu blok parameter lembar pasangan.
///
/// Ada supaya [TitikState.toSubmissionPasangan] nggak perlu tahu bentuk
/// lembarnya, dan supaya kunci selnya nggak dipatok jadi string mati — lihat
/// docblock method itu untuk kegagalan yang lahir dari mematoknya.
///
/// Satu blok parameter = satu pasang tabel. Thermohygrometer punya DUA blok
/// (`suhu` & `kelembaban`), jadi dua [DeretPasangan]; sisanya satu.
class DeretPasangan {
  const DeretPasangan({
    required this.kunciStandar,
    required this.kunciUut,
    required this.kolomStandar,
    required this.kolomUut,
  });

  /// [TabelHasil.kunciTabel] tabel sisi standar — `standar`, `suhu_standar`,
  /// atau `waktu_standar`, tergantung `grup` yang dikirim server.
  final String kunciStandar;

  final String kunciUut;

  /// Kode kolom per ulangan sisi STANDAR, urut seperti tercetak.
  /// `['pembacaan']` buat ketiga alat suhu; `['jam','menit','detik',
  /// 'milidetik']` buat Timer.
  final List<String> kolomStandar;

  /// Kode kolom sisi UUT. Kelima lembar pasangan yang ada sekarang mencetak
  /// kolom yang SAMA di kedua sisi, jadi isinya selalu sama dengan
  /// [kolomStandar] — tapi disimpan terpisah, bukan dianggap sama.
  ///
  /// Sebabnya bukan kerapian. Kalau suatu saat ada lembar yang kedua sisinya
  /// beda kolom, memakai daftar milik satu sisi buat sisi lain berarti membaca
  /// kunci sel yang nggak pernah digambar tabelnya: seluruh deret itu pulang
  /// `null`, `pasanganKosong` menyatakan titiknya belum disentuh, dan titiknya
  /// dibuang sebelum dikirim. Nol error — kegagalan yang bentuknya SAMA PERSIS
  /// dengan yang ditutup [TitikState.toSubmissionPasangan], cuma lewat sumbu
  /// kolom bukan sumbu kunci tabel.
  final List<String> kolomUut;

  /// Kode kolom sisi yang kunci selnya [kunci].
  List<String> kolomUntuk(String kunci) =>
      kunci == kunciStandar ? kolomStandar : kolomUut;
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
  double kunciBaris(
    List<BarisTabelHasil> baris,
    int index, [
    TabelHasil? tabel,
  ]) {
    // Lembar PASANGAN dikunci ke POSISI baris di dalam blok parameternya,
    // bukan ke titik ukurnya.
    //
    // Sebabnya Thermohygrometer: set point `50` ada di DUA tabel lembar itu —
    // 50 °C di blok suhu dan 50 %RH di blok kelembapan. Dikunci ke angka,
    // dua baris itu berbagi satu `TitikState`, jadi barisnya tinggal sembilan
    // (bukan sepuluh) dan baris RH mewarisi satuan °C milik tetangganya. Nol
    // error; yang terbit sertifikat yang kehilangan satu titik.
    //
    // Deret standar & deret UUT SENGAJA berbagi kunci yang sama: dua-duanya
    // memang set point yang sama, dibaca bergantian. Yang membedakan isian
    // keduanya `TabelHasil.kunciTabel` di dalam `TitikState`, bukan kunci ini.
    if (tabel != null && tabel.berpasangan) {
      return (_offsetParameter(tabel.parameter) + index).toDouble();
    }

    // Tabel yang menyebut offsetnya sendiri — lihat `TabelHasil.offsetKunci`.
    // Dipakai lembar Timbangan supaya baris Repeatability (Middle 50 kg,
    // Maximum 100 kg) nggak berbagi `TitikState` dengan titik Accuracy 50 kg
    // & 100 kg yang nilainya kebetulan sama.
    if (tabel?.offsetKunci != null) {
      return (tabel!.offsetKunci! + index).toDouble();
    }

    final titikUnik = baris.map((b) => b.titikUkur).toSet().length;

    return titikUnik == baris.length
        ? baris[index].titikUkur
        : index.toDouble();
  }

  /// Kunci sel & kolom kedua tabel deret buat blok [parameter].
  ///
  /// Dibaca dari BENTUK tiap kali, bukan disimpan: bentuk lembar bisa diganti
  /// (mis. jumlah kolom pengulangan disetel ulang), dan deskriptor basi bikin
  /// payload dibaca dari kunci yang sudah nggak ada — kelas kegagalan yang
  /// persis sama dengan yang ditutup [TitikState.toSubmissionPasangan].
  ///
  /// `null` = lembar ini nggak punya blok pasangan untuk parameter itu. Titik
  /// yang jatuh ke situ nggak ikut dikirim, dan itu jawaban yang benar: tanpa
  /// tabel, nggak ada satu pun sel yang bisa dibaca.
  DeretPasangan? deretPasangan(String? parameter) {
    String? standar;
    String? uut;
    List<String>? kolomStandar;
    List<String>? kolomUut;

    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        if (!t.berpasangan || (t.parameter ?? '') != (parameter ?? '')) {
          continue;
        }

        // Kolom diambil dari tabel SISINYA masing-masing. Dulu dari tabel mana
        // pun yang ketemu duluan lalu dipakai buat dua-duanya — benar buat
        // kelima lembar yang ada, tapi diam-diam mengikat keduanya harus sama.
        // Lihat [DeretPasangan.kolomUut].
        if (t.deretStandar) {
          standar ??= t.kunciTabel;
          kolomStandar ??= [for (final k in t.kolom) k.kode];
        }

        if (t.deretUut) {
          uut ??= t.kunciTabel;
          kolomUut ??= [for (final k in t.kolom) k.kode];
        }
      }
    }

    if (standar == null ||
        uut == null ||
        kolomStandar == null ||
        kolomStandar.isEmpty ||
        kolomUut == null ||
        kolomUut.isEmpty) {
      return null;
    }

    return DeretPasangan(
      kunciStandar: standar,
      kunciUut: uut,
      kolomStandar: kolomStandar,
      kolomUut: kolomUut,
    );
  }

  /// Nomor kunci pertama buat satu blok parameter lembar pasangan.
  ///
  /// Dihitung dari BENTUK, bukan disimpan: blok bisa berubah waktu bentuknya
  /// diganti, dan offset basi bikin dua blok tumpang tindih lagi.
  int _offsetParameter(String? parameter) {
    var offset = 0;

    for (final p in _urutanParameter()) {
      if (p == (parameter ?? '')) return offset;
      offset += _jumlahBarisParameter(p);
    }

    return offset;
  }

  /// Parameter lembar ini, urut seperti tercetak di kertas.
  List<String> _urutanParameter() {
    final urut = <String>[];

    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        if (!t.berpasangan) continue;
        final p = t.parameter ?? '';
        if (!urut.contains(p)) urut.add(p);
      }
    }

    return urut;
  }

  int _jumlahBarisParameter(String parameter) {
    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        if (t.berpasangan && (t.parameter ?? '') == parameter) {
          return barisTabel(t).length;
        }
      }
    }

    return 0;
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

  /// [TitikState] milik baris ke-[index] di [baris].
  ///
  /// Kuncinya WAJIB dihitung lewat [kunciBaris] — bukan dari `titikUkur`
  /// langsung. Dua bentuk lembar bikin keduanya beda: lembar pasangan
  /// (Thermohygro) mengunci ke posisi di dalam blok parameternya, dan tabel
  /// yang penanda barisnya kembar jatuh ke mode indeks. Mengambil pintasan di
  /// sini berarti kotak yang digambar dan kotak yang dikirim jadi dua objek
  /// yang beda — dan bedanya nggak memunculkan error di mana pun.
  ///
  /// `null` cuma kalau tabelnya belum dibangun; layar menggambar kotak mati.
  TitikState? titikUntukBaris(
    List<BarisTabelHasil> baris,
    int index,
    TabelHasil tabel,
  ) => titik[kunciBaris(baris, index, tabel)];

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
  bool get titikBisaDiubah =>
      bentuk.bagian.any((bagian) => bagian.tabel.any((t) => t.titikBisaDiubah));

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
            kunciBaris(baris, i, t),
            () => TitikState(
              titikUkur: b.titikUkur,
              // Baris yang set point-nya kosong di kertas dapat kotaknya
              // sendiri — lihat `TitikState.titikDitentukan`.
              titikDitentukan: b.titikDitentukan,
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
              // Besaran baris ini — pembeda blok suhu & blok kelembapan di
              // lembar Thermohygrometer. Null buat lembar lain.
              parameter: t.parameter,
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
          kunciBaris(barisTabel(t, calon), i, t),
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
            .where(
              (t) => !titikTerkunci(t.titikUkur) && t.adaPembacaanTanpaSuhu,
            )
            .toList()
      : const [];

  /// Baris yang pembacaannya meleset satu orde dari nominalnya — penahan
  /// sebelum kirim, sejajar sama penjaga suhu & penjaga isian yatim.
  ///
  /// Lihat [TitikState.adaPembacaanJauhDariTitik] soal kenapa ini ditahan di HP
  /// dan bukan dibiarin jadi peringatan di admin.
  List<TitikState> get titikPembacaanJauh => titik.values
      .where((t) => !titikTerkunci(t.titikUkur) && t.adaPembacaanJauhDariTitik)
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

  /// Kunci sel tabel yang isinya jadi `measurements[].pembacaan`.
  ///
  /// ## Kenapa nggak boleh dipaku ke `sesudah_adjustment`
  ///
  /// Kunci sel tiap tabel itu [TabelHasil.kunciTabel], dan isinya `tahap` yang
  /// dikirim backend. Sembilan belas lembar mengirim `sesudah_adjustment`,
  /// jadi kunci mati di [TitikState.toSubmission] kebetulan benar selama
  /// bertahun-tahun. Lembar TIDS mengirim `pembacaan_uut`.
  ///
  /// Waktu dua sisi itu nggak ketemu, yang terjadi BUKAN error: kotaknya
  /// kesimpen di `pembacaan_uut|pembacaan|i`, payloadnya dirakit dari
  /// `sesudah_adjustment|pembacaan|i` yang memang nggak pernah ada, dan
  /// `measurements` terkirim berisi set point yang benar dengan `pembacaan`
  /// null semua. Kelas kegagalan yang sama dengan seluruh berkas ini: layar
  /// penuh, tombol jalan, datanya hilang di perjalanan.
  ///
  /// Yang ditanya BACKEND, bukan daftar nama alat di sini: `simpan_ke`
  /// menyatakan tujuannya eksplisit, jadi lembar ke-21 yang tahapnya beda lagi
  /// ikut benar tanpa berkas ini disentuh.
  ///
  /// Bawaannya `sesudah_adjustment` — lembar yang nggak mengirim `simpan_ke`
  /// sama sekali (semua yang sudah ada) nggak berubah perilakunya sedikit pun.
  String get kunciTabelPembacaan {
    for (final b in bentuk.bagian) {
      for (final t in b.tabel) {
        if (t.berpasangan || t.tanpaTempatSimpan) continue;
        if (t.simpanKe == 'measurements[].pembacaan') return t.kunciTabel;
      }
    }

    return 'sesudah_adjustment';
  }

  /// Kotak tambahan per baris (`tabel.kolom_baris`) yang isinya ikut ke
  /// `measurements[]` — di luar `no_probe`, yang punya jalur gambarnya sendiri.
  ///
  /// Cuma lembar Timbangan yang punya sejauh ini: kotak `nominal`, berisi
  /// susunan keping yang ditumpuk di titik itu (`20+20+10`). Server yang
  /// menjumlahkannya jadi `titik_ukur`, jadi kotak ini bukan pelengkap —
  /// tanpa dia titiknya bernilai nol dan seluruh koreksinya nggak berarti.
  ///
  /// Diambil dari tabel PEMBACAAN saja: kotak baris di tabel yang isinya
  /// mendarat di `spesifikasi_alat` nggak punya `measurements[]` buat
  /// ditumpangi.
  List<FieldLembarKerja> get kotakBarisPembacaan {
    for (final b in bentuk.bagian) {
      for (final t in b.tabel) {
        if (t.berpasangan || t.tanpaTempatSimpan) continue;
        if (t.simpanKe != null && t.simpanKe!.startsWith('spesifikasi_alat.')) {
          continue;
        }
        if (t.kolomBaris.isEmpty) continue;

        return [
          for (final f in t.kolomBaris)
            if (f.kode != 'no_probe') f,
        ];
      }
    }

    return const [];
  }

  /// Kunci baris yang isinya mendarat di `spesifikasi_alat`, BUKAN di
  /// `measurements[]`.
  ///
  /// `titik` itu satu peta datar buat seluruh lembar — semua tabel menaruh
  /// barisnya di situ, dibedakan kuncinya. Bagus buat sembilan belas lembar
  /// yang semua tabelnya memang tabel titik; salah buat lembar Timbangan,
  /// yang tabel Repeatability-nya berisi KAPASITAS (Middle & Maximum), bukan
  /// titik yang dikoreksi.
  ///
  /// Dibiarkan lolos, sertifikatnya terbit dengan dua baris titik tambahan
  /// yang nggak pernah diminta siapa pun — 50 kg & 100 kg yang isinya sepuluh
  /// pengulangan, bukan satu pembacaan. Nggak ada error di jalur itu: dua
  /// baris itu punya set point yang sah dan angka yang sah.
  ///
  /// Kunci yang JUGA dipakai tabel pembacaan biasa nggak ikut dibuang —
  /// membuang baris yang dipakai bersama berarti kehilangan titik beneran.
  /// Sejauh ini nggak pernah terjadi (`offset_kunci` yang menjaganya), tapi
  /// murah dijaga di sini juga.
  Set<double> get kunciTitikSpesifikasi {
    const awalan = 'spesifikasi_alat.';
    final milikSpek = <double>{};
    final milikTitik = <double>{};

    for (final bagian in bentuk.bagian) {
      for (final tabel in bagian.tabel) {
        final baris = barisTabel(tabel);
        final tujuan = tabel.simpanKe;
        final keSpek = tujuan != null && tujuan.startsWith(awalan);

        for (var i = 0; i < baris.length; i++) {
          (keSpek ? milikSpek : milikTitik).add(kunciBaris(baris, i, tabel));
        }
      }
    }

    return milikSpek.difference(milikTitik);
  }

  /// Baris yang ANGKANYA keisi tapi kotak `Setpoint`-nya kosong atau nggak
  /// kebaca sebagai angka.
  ///
  /// Cuma lembar TIDS yang bisa kena — cuma di sana set point-nya diketik
  /// teknisi. Dan di sana akibatnya sunyi: baris tanpa set point nggak punya
  /// identitas buat dihitung, jadi [TitikState.siapKirim] MEMBUANG SELURUH
  /// BARISNYA — kelima kotak pembacaan yang sudah diisi ikut hilang, tanpa
  /// satu pun tanda, di lembar yang kelihatan penuh di layar.
  ///
  /// Itu kelas kerusakan yang paling mahal di berkas ini, jadi penjaganya
  /// MENAHAN (bukan bertanya), sejajar sama [titikTerisiTanpaStandar]: yang
  /// hilang bukan dugaan soal kewajaran angka, tapi angka yang beneran ada di
  /// tangan teknisi dan beneran nggak jadi terkirim.
  List<TitikState> get titikTanpaSetPoint => titik.values
      .where((t) => !t.titikDitentukan && t.adaPembacaan && !t.siapKirim)
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

  /// Sel matriks yang isinya datang dari FOTO, belum diadu ke kertas — keyed
  /// sama dengan [matriks]. Ditandai kuning di layar, alasan yang sama dengan
  /// [selRendahKeyakinan] di tabel biasa: hasil OCR itu saran, dan yang
  /// menandatangani sertifikatnya manusia.
  final Set<String> matriksDariFoto = {};

  /// Tebakan mesin per sel matriks yang keisi dari foto. Kuncinya
  /// [kunciMatriks], sama persis kayak [matriksDariFoto].
  ///
  /// Sengaja nggak pernah dihapus waktu teknisi mengetik ulang — lihat
  /// [bacaanMesinSel] soal kenapa pasangan (tebakan, angka final) itu
  /// satu-satunya bahan buat mengukur akurasi kamera.
  final Map<String, BacaanMesin> bacaanMesinMatriks = {};

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

  /// Tebakan mesin per sel yang keisi dari foto. Kuncinya [kunciSel], sama
  /// persis kayak [selRendahKeyakinan].
  ///
  /// **Sengaja nggak pernah dihapus waktu teknisi mengetik ulang.** Itu bukan
  /// kelalaian: pasangan (tebakan mesin, angka yang akhirnya dikirim) justru
  /// SATU-SATUNYA bahan buat menghitung akurasi kamera. Sebelum ini teknisi
  /// mengoreksi di kotak yang sama, tebakannya tertimpa, dan yang sampai server
  /// cuma hasil akhir — jadi tidak ada yang bisa menjawab "kameranya sering
  /// salah atau nggak", termasuk buat metrik yang paling menentukan: sel yang
  /// keisi otomatis dengan keyakinan tinggi padahal salah.
  ///
  /// Dikirim lewat `measurements[].ocr[]`; lihat [BacaanMesin].
  final Map<String, BacaanMesin> bacaanMesinSel = {};

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
  static String kunciSel(
    double titikUkur,
    String tahap,
    String kolom,
    int index,
  ) => '$titikUkur|$tahap|$kolom|$index';

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

  /// Kunci `TitikState` buat satu SLOT CETAK — bukan nilai titik ukurnya
  /// langsung.
  ///
  /// ## Kenapa dua hal ini bisa berbeda
  ///
  /// Di lembar Conductivity keduanya sama: slot menunjuk baris lewat
  /// `titik_ukur`, dan kunci barisnya memang nilai itu. Lembar TIMBANGAN
  /// memakai `offset_kunci` — baris Repeatability dikunci `1000`/`1001` supaya
  /// tidak rebutan dengan titik Accuracy 50 kg & 100 kg yang nilainya
  /// kebetulan sama.
  ///
  /// Dibiarkan mencari `titik[50]`, yang ketemu **null** dan seluruh empat
  /// puluh selnya digambar MATI: kotaknya ada, garisnya ada, teknisi mengetik
  /// dan tidak ada satu pun karakter yang masuk. Tanpa error, dan tanpa cara
  /// menebak sebabnya dari layar.
  ///
  /// Tabel yang menyebut `offset_kunci` dipasangkan lewat URUTAN — slot ke-i
  /// milik baris ke-i. Itu janji yang dinyatakan bentuknya (`slotKeterulangan`
  /// mengirim Middle dulu, Maximum kedua, sejajar dengan `baris`), dan cuma
  /// berlaku di situ: Conductivity yang slotnya tidak sejajar baris tetap
  /// lewat jalur lama, persis seperti sebelumnya.
  double? kunciTitikSlot(TabelHasil tabel, int index, SlotCetak slot) {
    if (tabel.offsetKunci == null) return titikAktifSlot(tabel.kunciTabel, index, slot);

    final baris = barisTabel(tabel);

    if (index < 0 || index >= baris.length) return null;

    return kunciBaris(baris, index, tabel);
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

  /// Status sertifikat standar sesi yang dibuka lagi — banner kepala lembar.
  ///
  /// Ditaruh di sini, bukan dioper turun lewat konstruktor, karena persis
  /// itu yang sudah dilakukan [catatanRevisi] & [revisiField] buat banner di
  /// sebelahnya: dua tata letak (satu & dua kolom) sama-sama menerima `isian`,
  /// jadi menambah satu parameter berarti menambahnya di empat tempat.
  ///
  /// Null buat lembar BARU — sesinya belum ada, jadi belum ada standar yang
  /// bisa dicek statusnya.
  StatusStandar? statusStandar;

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
    final kunciUtama = kunciTabelPembacaan;

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
      final tujuan = m.bagianPasangan
          ? _titikPasangan(m.titikUkur, m.satuan)
          // Baris yang set point-nya diketik teknisi (TIDS) NGGAK bisa ketemu
          // lewat [_titikTerdekat] — lihat [_titikBelumDitentukan].
          : (_titikTerdekat(m.titikUkur) ?? _titikBelumDitentukan(m.titikUkur));

      if (tujuan == null) {
        kebuang++;
        continue;
      }

      // No. Termokopel ikut pulih — dia nempel ke deret STANDAR dan nentuin
      // koreksi probe mana yang dipakai. Nggak dipulihkan, teknisi membuka
      // lembar revisi dengan kolomnya kosong lalu memilih yang pertama di
      // daftar, dan koreksi probe yang terpakai bukan milik probe yang beneran
      // dicelup — nol error di sepanjang jalur itu.
      final sensorKe = m.sensorKe;

      if (sensorKe != null && tujuan.noProbeCtl.text.trim().isEmpty) {
        tujuan.noProbeCtl.text = sensorKe.toString();
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

      // Kunci kotaknya: PERAN dulu, baru tahap.
      //
      // Lembar pasangan (Thermocouple, Termometer Gelas, Thermohygrometer)
      // menyimpan dua deret yang `tahap`-nya SAMA — yang membedakan
      // `peran_sensor`. Dikunci ke tahap, kedua deret jatuh ke kotak yang sama:
      // deret UUT menimpa deret standar, dan yang kelihatan cuma satu tabel
      // yang isinya angka deret sebelah. Nol pesan error — angkanya wajar,
      // tempatnya salah.
      //
      // Nilainya sama persis dengan `TabelHasil.kunciTabel` di sisi bentuk
      // lembar kerja, dan itu yang bikin dua sisi ini ketemu.
      // Kunci utamanya dari BENTUK lembar ([kunciTabelPembacaan]), bukan
      // dipaku — kembarannya di [TitikState.toSubmission]. Dua sisi ini wajib
      // memakai kunci yang sama: yang dipulihkan ke kotak yang salah sama
      // saja dengan nggak dipulihkan, cuma tanpa ada yang kehitung `kebuang`.
      final tahap = m.bagianPasangan
          ? m.peranSensor!
          : (m.tahap == TahapPembacaan.sebelumAdjustment
                ? 'sebelum_adjustment'
                : kunciUtama);

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
          final peran =
              _urutanPeran(a.peranSensor) - _urutanPeran(b.peranSensor);
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
  /// Angka FINAL satu sel MATRIKS (Autoklaf) — label buat potongan fotonya.
  ///
  /// Alamatnya beda dari lembar bertabel: baris matriks itu BESARAN
  /// (`suhu.disk.0`), bukan titik ukur, dan penanda barisnya karangan
  /// ([MatriksHasil.kunciBarisFoto]). Makanya penerjemahannya harus lewat
  /// [_barisMatriks], persis seperti waktu angkanya ditempatkan — dua cara
  /// yang beda bikin labelnya meleset diam-diam.
  ///
  /// Balikin `null` kalau barisnya nggak ketemu, barisnya kolom jam (bukan
  /// angka ukur), atau titik waktunya nggak ada di lembar itu.
  String? labelSelMatriks(MatriksHasil m, double penanda, int titikWaktu) {
    if (!m.titikWaktu.contains(titikWaktu)) return null;

    final b = _barisMatriks(m.semuaBaris, penanda);
    if (b == null || b.tipe == 'jam') return null;

    return kotakMatriks(b.kodeData, titikWaktu).text;
  }

  /// Angka FINAL di satu sel — label buat potongan yang ditahan sejak difoto.
  ///
  /// [repeatNo] diterjemahkan jadi posisi kolom lewat [pengulangan] DI SINI,
  /// bukan di pemanggil — tanda tangannya sengaja dibikin sama dengan
  /// [terapkanHasilFotoTabel] supaya dua-duanya nggak bisa berselisih.
  ///
  /// Ditaruh di pemanggil, penerjemahannya jadi lem yang nggak diuji, dan
  /// kelas bug `repeatNo - 1` punya tempat baru buat muncul.
  ///
  /// Titiknya dicari lewat [titikBarisTabel], BUKAN `titik[...]` — jalur foto
  /// menempatkan angkanya dengan cara yang sama, dan dua cara yang beda bikin
  /// labelnya meleset diam-diam di baris yang titiknya cuma cocok dalam
  /// toleransi.
  ///
  /// Teksnya dibalikin APA ADANYA, bukan lewat `parseAngka`: yang dilatih
  /// nantinya membaca coretan jadi TULISAN, dan `25,3` yang diketik teknisi
  /// itu label yang benar — bukan `25.3` hasil bolak-balik lewat `double`.
  ///
  /// Balikin `null` kalau titiknya nggak ada atau posisinya di luar jangkauan;
  /// pemanggil yang menghitungnya sebagai "tanpa label".
  String? labelSelFoto({
    required TabelHasil tabel,
    required double titikUkur,
    required int repeatNo,
    required String fieldId,
  }) {
    final t = titikBarisTabel(tabel, titikUkur);
    if (t == null) return null;

    final posisi = tabel.pengulangan.indexOf(repeatNo);
    if (posisi < 0 || posisi >= t.jumlahPengulangan) return null;

    return t.kotak(tabel.kunciTabel, fieldId, posisi).text;
  }

  /// Baris TABEL INI yang titik ukurnya [titikUkur]. `null` = nggak ada.
  ///
  /// ## Kenapa nggak lewat `titik[x]` atau [_titikTerdekat]
  ///
  /// Kunci peta [titik] itu [kunciBaris], dan di lembar BERPASANGAN isinya
  /// POSISI baris (0, 1, 2, …), bukan titik ukurnya — dua deret memang berbagi
  /// satu baris. Jadi `titik[60.0]` di lembar Timer dicari di antara kunci
  /// 0.0/1.0/2.0 dan nggak pernah ketemu, sementara angka yang datang dari
  /// foto SELALU titik ukur asli (pemetanya dikasih
  /// `[for (final t in titikTabel(tabel)) t.titikUkur]`).
  ///
  /// Akibatnya diukur, bukan dikira-kira: sebelum 1 Sep 2026 tombol "FOTO
  /// TABEL INI" mengisi NOL sel di lembar Timer, Thermohygrometer,
  /// Thermocouple, dan Termometer Gelas — dan di TIDS malah melaporkan "1 sel
  /// terisi" sambil meninggalkan kotaknya kosong, karena angkanya mendarat di
  /// baris lain yang kebetulan kuncinya cocok.
  ///
  /// Dibatasi ke baris TABEL INI, bukan seluruh lembar: set point `50` ada di
  /// dua blok Thermohygrometer (50 °C dan 50 %RH), jadi pencarian se-lembar
  /// bisa menaruh angka kelembapan di baris suhu. Alasan yang sama sudah
  /// dipakai [titikTabel] waktu memberi makan pemeta fotonya.
  ///
  /// [_titikSama], bukan `==`: `double` dari server bisa pulang sebagai
  /// 1018,0000000001, dan pembulatan itu bukan baris yang berbeda.
  TitikState? titikBarisTabel(TabelHasil tabel, double titikUkur) {
    final baris = barisTabel(tabel);

    for (var i = 0; i < baris.length; i++) {
      final t = titik[kunciBaris(baris, i, tabel)];
      if (t != null && _titikSama(t.titikUkur, titikUkur)) return t;
    }

    return null;
  }

  TitikState? _titikTerdekat(double titikUkur) {
    final persis = titik[titikUkur];
    if (persis != null) return persis;

    for (final e in titik.entries) {
      if (_titikSama(e.key, titikUkur)) return e.value;
    }

    return null;
  }

  /// Cari baris lembar PASANGAN dari titik ukur + satuannya.
  ///
  /// Nggak bisa lewat [_titikTerdekat]: di lembar pasangan kunci `titik` itu
  /// POSISI baris (lihat [kunciBaris]), bukan titik ukurnya, jadi
  /// `titik[50.0]` nggak pernah ketemu dan SELURUH pembacaan sesi yang
  /// dikembalikan admin dianggap kebuang.
  ///
  /// Satuan ikut jadi kunci karena set point `50` ada di dua blok lembar
  /// Thermohygrometer — 50 °C dan 50 %RH. Tanpa satuan, angka blok kelembapan
  /// mendarat di baris suhu: bentuknya wajar, tempatnya salah.
  TitikState? _titikPasangan(double titikUkur, String? satuan) {
    TitikState? cadangan;

    for (final t in titik.values) {
      if (!_titikSama(t.titikUkur, titikUkur)) continue;

      if (satuan == null || satuan.isEmpty || t.satuan == satuan) return t;

      cadangan ??= t;
    }

    // Satuannya nggak cocok sama satu pun baris — dipakai yang titiknya sama.
    // Sesi lama bisa tersimpan sebelum kolom satuan per baris ada, dan angka
    // yang mendarat di baris yang benar TAPI satuannya nggak kecatat lebih
    // baik daripada angka yang hilang.
    return cadangan;
  }

  /// Cari baris TIDS buat set point tersimpan [titikUkur] — dan tulis balik
  /// angkanya ke kotak `Setpoint`-nya.
  ///
  /// ## Kenapa [_titikTerdekat] nggak bisa dipakai
  ///
  /// Di lembar TIDS kunci `titik` itu NOMOR BARIS (1..7): kertasnya mencetak
  /// tujuh baris `Setpoint` kosong, jadi bentuk lembar dari server memang
  /// nggak punya angka buat dikunci. Yang DIKIRIM waktu sesinya disimpan
  /// [TitikState.titikUkurEfektif] — angka yang diketik teknisi, mis. `121,5`.
  ///
  /// Dua sisi itu nggak ketemu. `titik[121.5]` nggak ada, `_titikTerdekat`
  /// pulang null, dan tiap baris kehitung `kebuang`: teknisi yang membuka lagi
  /// draf TIDS-nya — atau lembar yang dikembalikan admin buat dibetulkan —
  /// dapat tabel KOSONG, dan yang dia kirim balik cuma sisa yang sempat
  /// diketik ulang dari kertas. Kelas kerusakan yang sama persis dengan yang
  /// ditutup [terapkanPembacaan] sendiri, cuma di lembar yang lolos karena
  /// barisnya nggak punya identitas angka.
  ///
  /// ## Aturannya, dan kenapa urutannya begitu
  ///
  ///  1. Baris yang kotak `Setpoint`-nya SUDAH berisi angka yang sama →
  ///     itu barisnya. Ini yang bikin lima pembacaan satu set point mendarat
  ///     di baris yang sama, bukan memakan lima baris.
  ///  2. Belum ada → baris pertama yang kotaknya masih kosong, dan angkanya
  ///     ditulis ke situ. Kotaknya diisi DULUAN, sebelum sel pembacaannya —
  ///     baris tanpa set point nggak ikut dikirim ([TitikState.siapKirim]),
  ///     jadi urutan terbalik memulihkan angka ke baris yang langsung dibuang
  ///     lagi waktu disimpan.
  ///  3. Kehabisan baris kosong → null, dan pemanggilnya menghitungnya
  ///     `kebuang`. Sengaja nggak menambah baris: tujuh baris itu bentuk
  ///     kertasnya, dan diam-diam menumbuhkannya menyembunyikan bahwa data
  ///     tersimpannya nggak muat.
  ///
  /// Lembar yang SEMUA barisnya ber-set point tetap pulang null di baris
  /// pertama loop — sembilan belas lembar lain nggak berubah perilakunya.
  TitikState? _titikBelumDitentukan(double titikUkur) {
    TitikState? kosong;

    for (final t in titik.values) {
      if (t.titikDitentukan) continue;

      final terisi = parseAngka(t.titikCtl.text);

      if (terisi != null) {
        if (_titikSama(terisi, titikUkur)) return t;

        continue;
      }

      kosong ??= t;
    }

    if (kosong == null) return null;

    kosong.titikCtl.text = formatAngka(titikUkur);

    return kosong;
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
  Map<String, dynamic> get spesifikasiAlat {
    final hasil = <String, dynamic>{};

    for (final bagian in bentuk.bagian) {
      for (final f in bagian.field) {
        if (!f.spesifikasiAlat) continue;

        final isi = teks[f.kode]?.text.trim() ?? '';
        if (isi.isEmpty) continue;

        _tanamSpesifikasi(hasil, f.kunciSpesifikasi.split('.'), isi);
      }
    }

    _tanamTabelSpesifikasi(hasil);

    return hasil;
  }

  /// Tanam satu nilai ke [induk] mengikuti [jalur] — `['eksentrisitas',
  /// 'baca', 'center']` jadi `{eksentrisitas: {baca: {center: …}}}`.
  ///
  /// ## Kenapa titik di dalam `spesifikasi_alat.*` artinya BERSARANG
  ///
  /// Di kode kolom biasa, titik artinya "kolom turunan" — read-only, diisi
  /// sistem dari alat yang dipilih, dan nggak pernah ikut payload
  /// (`FieldLembarKerja.turunan`). `spesifikasi_alat.*` sudah dikecualikan dari
  /// aturan itu sejak Refractometer: di sana titiknya PENGELOMPOKAN.
  ///
  /// Lembar Timbangan yang bikin pengelompokan itu perlu lebih dari satu
  /// tingkat. Lima bloknya dibaca backend sebagai objek bersarang
  /// (`eksentrisitas.baca.center`, `histeresis.baca1.0`), dan yang mengirimkan
  /// mereka sebagai kunci DATAR bertuliskan titik bakal lolos validasi tanpa
  /// error — `spesifikasi_alat` itu kolom JSON tanpa skema — lalu dibaca nol
  /// oleh kalkulatornya. Komponen Eccentricity-nya nol di setiap sesi, dan
  /// nggak ada satu pun tanda di layar maupun di sertifikat.
  ///
  /// Segmen yang seluruhnya angka tetap jadi kunci teks (`"0"`, `"7"`);
  /// PHP membaca `{"0": …, "7": …}` sebagai array berindeks, jadi
  /// `count($b) >= 8` dan `$b[0]` di sisi sana tetap benar.
  ///
  /// Kalau satu jalur menabrak nilai yang sudah ada (`a.b` dan `a.b.c`
  /// dua-duanya dikirim), yang DULUAN menang dan yang belakangan dibuang —
  /// bukan bentuknya yang ditimpa. Bentuk begitu cuma bisa lahir dari lembar
  /// yang kodenya salah tulis, dan menimpa berarti kehilangan kotak yang
  /// teknisi memang isi.
  static void _tanamSpesifikasi(
    Map<String, dynamic> induk,
    List<String> jalur,
    String nilai,
  ) {
    if (jalur.isEmpty) return;

    if (jalur.length == 1) {
      induk.putIfAbsent(jalur.first, () => nilai);

      return;
    }

    final anak = induk[jalur.first];

    if (anak != null && anak is! Map<String, dynamic>) return;

    final peta = (anak as Map<String, dynamic>?) ?? <String, dynamic>{};
    induk[jalur.first] = peta;

    _tanamSpesifikasi(peta, jalur.sublist(1), nilai);
  }

  /// Tabel yang `simpan_ke`-nya nunjuk ke dalam `spesifikasi_alat` dikirim
  /// sebagai **cerminan tabelnya**, bukan sebagai titik ukur.
  ///
  /// Tabel Repeatability lembar Timbangan begitu: dua barisnya KAPASITAS
  /// (Middle & Maximum), bukan dua titik yang dikoreksi — besaran satu per
  /// sesi, jadi nggak punya `titik_ke` dan nggak bisa lewat `measurements`.
  ///
  /// Bentuk yang dikirim sengaja nggak menyebut "mid" maupun "maks":
  ///
  ///     {baris: [{titik_ukur, <kode kolom>: [nilai per ulangan]}, …]}
  ///
  /// Nama slot itu kosakata master alatnya, dan menaruhnya di layar yang
  /// menggambar dua puluh lembar berarti daftar tulis-tangan yang menyusut
  /// diam-diam tiap ada alat baru — persis pola yang dijaga docblock
  /// [LembarKerja.berpasangan]. Yang menerjemahkannya profil alat di server.
  ///
  /// Baris yang sama sekali kosong tetap ikut DI POSISINYA: urutan barislah
  /// yang menentukan mana Middle dan mana Maximum di sisi sana.
  void _tanamTabelSpesifikasi(Map<String, dynamic> hasil) {
    const awalan = 'spesifikasi_alat.';

    for (final bagian in bentuk.bagian) {
      for (final tabel in bagian.tabel) {
        final tujuan = tabel.simpanKe;

        if (tujuan == null || !tujuan.startsWith(awalan)) continue;

        final baris = barisTabel(tabel);
        final isi = <Map<String, dynamic>>[];

        for (var i = 0; i < baris.length; i++) {
          final t = titikUntukBaris(baris, i, tabel);

          isi.add({
            'titik_ukur': t?.titikUkurEfektif ?? baris[i].titikUkur,
            // Indeksnya POSISI (0-based), bukan nomor Repeat yang tercetak —
            // sama persis dengan kunci yang dipakai kotaknya waktu digambar
            // (`tahap|kolom|index`). Memakai nomor tercetak di sini bikin
            // sepuluh kotak dibaca dari kunci yang nggak pernah ada, dan yang
            // terkirim sepuluh null tanpa satu pun error.
            for (final kolom in tabel.kolom)
              kolom.kode: [
                for (var r = 0; r < tabel.pengulangan.length; r++)
                  parseAngka(
                    t?.kotak(tabel.kunciTabel, kolom.kode, r).text ?? '',
                  ),
              ],
            // Tebakan mesin per kolom, sejajar indeks sama deret nilainya.
            // Cuma ikut kalau ADA yang datang dari foto.
            for (final kolom in tabel.kolom)
              if (_ocrKolomSpesifikasi(t, tabel, kolom.kode) case final o?)
                '${kolom.kode}_ocr': o,
          });
        }

        if (isi.isEmpty) continue;

        _tanamSpesifikasi(
          hasil,
          tujuan.substring(awalan.length).split('.'),
          '',
        );

        // Ditulis lewat jalur yang sama supaya kunci bersarang
        // (`a.b.keterulangan`) tetap jalan, lalu nilainya diganti — `_tanam`
        // cuma tahu teks.
        var induk = hasil;
        final jalur = tujuan.substring(awalan.length).split('.');

        for (var i = 0; i < jalur.length - 1; i++) {
          induk = induk[jalur[i]] as Map<String, dynamic>;
        }

        induk[jalur.last] = {'baris': isi};
      }
    }
  }

  /// Deret tebakan mesin buat satu kolom tabel yang disimpan ke
  /// `spesifikasi_alat` — blok keterulangan / eksentrisitas / histeresis
  /// lembar Timbangan.
  ///
  /// ## Kenapa tabel ini nggak lewat `measurements`
  ///
  /// Kamera lembar Timbangan mendarat di blok-blok ini, BUKAN di deret
  /// pembacaan. Angkanya disimpan sebagai JSON di `spesifikasi_alat`, jadi
  /// `raw_measurements.ocr_raw_text` — tempat tebakan dua puluh alat lain —
  /// nggak pernah kesentuh sama sekali.
  ///
  /// Kalau blok ini nggak ikut membawa tebakannya, seluruh lembar Timbangan
  /// hilang dari pengukuran akurasi, dan diamnya bakal kebaca sebagai
  /// "kameranya bagus di Timbangan" — padahal artinya nol data.
  ///
  /// Balik `null`, bukan deret berisi null, kalau nggak ada satu pun sel yang
  /// datang dari foto: kunci kosong bikin pembacanya mengira ada jalur kamera
  /// di kolom itu.
  List<Map<String, dynamic>?>? _ocrKolomSpesifikasi(
    TitikState? t,
    TabelHasil tabel,
    String kolom,
  ) {
    if (t == null) return null;

    // Indeksnya POSISI, sama persis dengan kunci yang dipakai deret nilainya
    // di atas. Memakai nomor Repeat tercetak bikin tebakannya dibaca dari
    // kunci yang nggak pernah ada.
    final bacaan = [
      for (var r = 0; r < tabel.pengulangan.length; r++)
        bacaanMesinSel[kunciSel(t.titikUkur, tabel.kunciTabel, kolom, r)]
            ?.toJson(),
    ];

    return bacaan.any((b) => b != null) ? bacaan : null;
  }

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
    // `siapKirim` menahan SATU hal saja: baris yang set point-nya memang belum
    // ada (tujuh baris kosong lembar TIDS). Baris bawaan yang belum disentuh
    // tetap ikut — backend menyimpan titiknya mentah, dan itu yang bikin lembar
    // setengah jadi tetap kebaca utuh sama admin.
    final kunciUtama = kunciTabelPembacaan;

    final kotakBaris = kotakBarisPembacaan;
    final bukanTitik = kunciTitikSpesifikasi;

    final measurements = titik.entries
        .where((e) => !bukanTitik.contains(e.key) && e.value.siapKirim)
        .map((e) {
          final payload = e.value.toSubmission(
            kunciUtama: kunciUtama,
            kotakBaris: kotakBaris,
          );
          _lampirkanBacaanMesin(payload, e.value, kunciUtama);

          return payload;
        })
        .toList();

    // Lembar ber-GRID nggak punya `titik` sama sekali — bentuknya nggak
    // mengirim `tabel`, jadi `measurements` di atas selalu kosong. Set point-nya
    // disusun dari isian grid, dan yang benar-benar kosong dibuang di sana.
    // Lembar PASANGAN lewat jalur `measurementsGrid` yang sama dengan
    // Enclosure — bukan karena bentuknya mirip (nggak mirip sama sekali), tapi
    // karena dua-duanya butuh mengirim kunci yang `TitikLembarKerja` nggak
    // punya. Menambahkan `standar`/`uut` ke sana berarti 17 alat lain ikut
    // mengirim dua kunci kosong tiap titik.
    //
    // Titik yang sama sekali belum disentuh DIBUANG, sama seperti set point
    // grid yang kosong: backend memakai urutan `measurements` sebagai
    // `titik_ke`, jadi baris kosong di tengah bikin nomor titik sesudahnya
    // geser.
    //
    // `siapKirim` ikut menyaring DI SINI, sejajar dengan jalur datar di atas —
    // dan tanpa itu baris yang angkanya keisi tapi kotak `Setpoint`-nya kosong
    // lolos dengan set point KARANGAN. Rantainya:
    //
    //  1. `pasanganKosong` false (angkanya memang ada), jadi barisnya ikut.
    //  2. `toSubmissionPasangan()` jatuh ke cadangan `?? titikUkur` — di TIDS
    //     itu nomor barisnya (1..7).
    //  3. Penjaga `titikTanpaSetPoint` cuma jalan di `if (!draft)`, jadi
    //     SIMPAN DRAFT lewat tanpa ditahan.
    //  4. Draftnya dibuka lagi: `_titikBelumDitentukan()` menulis angka itu
    //     ke kotak `Setpoint` yang tadinya kosong.
    //  5. Sekarang kotaknya KEISI, `siapKirim` jadi true, dan penjaga di
    //     langkah 3 nggak bunyi lagi. Sertifikatnya terbit dengan set point 3
    //     buat pembacaan yang diambil di 121,5.
    //
    // Nomor baris nggak pernah boleh menyamar jadi set point; baris tanpa
    // identitas lebih baik nggak terkirim, persis seperti sembilan belas
    // lembar lain. Yang menjaga teknisi nggak kehilangan angkanya diam-diam
    // tetap `titikTanpaSetPoint`, yang MENAHAN kiriman sungguhan.
    final measurementsPasangan = bentuk.berpasangan
        ? [
            for (final t in titik.values)
              if (deretPasangan(t.parameter) case final d?)
                if (!t.pasanganKosong(d) && t.siapKirim)
                  _lampirkanBacaanMesinPasangan(t.toSubmissionPasangan(d), t, d),
          ]
        : null;

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
      alatBantu: kalimat('alat_bantu'),
      tipePencelupan: kalimat('tipe_pencelupan'),
      // Tiga kotak terpisah (`titik_es.0`..`.2`), bukan satu kotak berkoma:
      // yang dibaca server rentangnya, dan rentang dari teks berkoma berarti
      // satu typo memisahkan angka jadi dua nilai tanpa ada yang sadar.
      titikEs: [for (var i = 1; i <= 3; i++) angka('titik_es_$i')],
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
      measurementsGrid: measurementsGrid ?? measurementsPasangan,
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
        // Kunci yang sama dengan yang dirakit [TitikState.toSubmission] —
        // ringkasan yang membaca kotak lain bilang "0 dari 5 terisi" di lembar
        // yang penuh, atau lebih buruk, "5 dari 5" di lembar yang isinya nggak
        // ikut terkirim.
        final isi = [
          for (var i = 0; i < t.jumlahPengulangan; i++)
            parseAngka(t.kotak(kunciTabelPembacaan, 'pembacaan', i).text),
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
    final punyaTabel = {for (final b in barisTabel(tabel)) b.titikUkur};

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
  int selPerTabelIni(TabelHasil tabel) => titikTabel(
    tabel,
  ).fold(0, (jumlah, t) => jumlah + t.jumlahPengulangan * tabel.kolom.length);

  /// Tuang angka hasil pindai yang UDAH lewat layar review ke kotak isian.
  /// Balikin jumlah sel yang beneran keisi.
  ///
  /// Yang masuk ke sini bukan bacaan mentah OCR: [sel] isinya angka yang
  /// teknisi setujui di `PindaiReviewScreen`, sesudah dia mbandingin tiap sel
  /// kuning & merah sama potongan citranya. Hasil pindai itu USULAN — yang
  /// bikin dia jadi data cuma persetujuan orang.
  ///
  /// **Selnya dicari lewat titik ukur + kunci tabel + nomor Repeat, bukan
  /// urutan array.** Aturannya sama kayak kunci sel di sisi server: begitu ada
  /// satu tahap yang ngandelin urutan, angka bisa mendarat di baris sebelah
  /// tanpa satu pun error muncul. Sel yang titik ukurnya nggak ada di lembar
  /// ini DIBUANG, bukan dipaksa masuk ke baris terdekat.
  int terapkanHasilPindai(List<SelDipakaiPindai> sel) {
    var terisi = 0;

    for (final s in sel) {
      // Tabelnya diresolusi SEKALI, lalu dipakai buat dua hal yang harus
      // sejalan: cara nyari barisnya dan alamat kotaknya. Dihitung
      // sendiri-sendiri, yang satu bisa bilang "baris ke-3 blok kelembapan"
      // sementara yang lain nulis ke kunci blok suhu.
      final tabel = _tabelPindai(s.tabelId);

      final state = tabel != null
          ? titikBarisTabel(tabel, s.titikUkur)
          : _titikTerdekat(s.titikUkur);
      if (state == null) continue;

      // `repeat_no` di server 1-based, index kotak di sini 0-based —
      // diterjemahkan lewat `pengulangan` TABELNYA, bukan `repeatNo - 1`.
      //
      // Dua-duanya sama selama daftarnya `[1, 2, 3, …]`, dan semua lembar yang
      // ada sekarang memang begitu. Tapi daftarnya datang dari server, dan
      // lembar yang Repeat-nya nggak mulai dari 1 bikin tiap angka mendarat di
      // kolom sebelah — tanpa satu pun error, dengan tabel yang penuh dan wajar
      // di layar. Kelas bug yang sama sudah ditutup di `grid_sensor_state.dart`
      // lalu di [terapkanHasilFotoTabel]; ini sisa terakhirnya.
      //
      // Tabel nggak ketemu (server lama) = balik ke perilaku lama.
      final index = tabel != null
          ? tabel.pengulangan.indexOf(s.repeatNo)
          : s.repeatNo - 1;
      if (index < 0 || index >= state.jumlahPengulangan) continue;

      terisi += _isiSel(
        state,
        tabel?.kunciTabel ?? s.tahap,
        s.fieldId,
        index,
        s.nilai,
        s.perluDicek,
      );
    }

    if (terisi > 0) adaIsianDariFoto = true;

    return terisi;
  }

  /// Tabel lembar yang identitas servernya [tabelId] (`grup ?? tahap` — lihat
  /// `TemplateLembarKerja::tabel`). `null` = nggak ada yang cocok.
  ///
  /// ## Kenapa nggak boleh pakai `tahap` langsung
  ///
  /// Server dan HP menamai tabel yang sama dengan cara yang beda:
  ///
  /// | lembar        | `tahap` server       | kunci kotak di HP |
  /// |---------------|----------------------|-------------------|
  /// | pH Meter      | `sesudah_adjustment` | `sesudah_adjustment` |
  /// | TIDS          | `pembacaan_uut`      | `uut`             |
  /// | Thermohygro   | `sesudah_adjustment` | `suhu_standar`, `suhu_uut`, `kelembaban_standar`, `kelembaban_uut` |
  /// | Timer         | `sesudah_adjustment` | `waktu_standar`, `waktu_uut` |
  ///
  /// Buat sembilan belas lembar yang satu tahap = satu tabel keduanya
  /// kebetulan sama, jadi menuang pakai `tahap` benar selama bertahun-tahun.
  /// Buat lima lembar BERPASANGAN dia salah dua kali sekaligus: kuncinya beda
  /// (angka mendarat di controller yang nggak digambar siapa-siapa), dan empat
  /// tabel Thermohygro punya `tahap` yang SAMA — jadi kalaupun kuncinya benar,
  /// suhu dan kelembapan bakal saling menimpa.
  ///
  /// Gagalnya diam, dan itu yang bikin dia mahal: `_isiSel` tetap balik 1
  /// karena controller barunya memang kosong, jadi teknisi dikasih tahu "x sel
  /// terisi dari foto" dan `input_method` sesinya jadi `ocr` — di atas lembar
  /// yang sebenarnya masih kosong.
  ///
  /// Dicocokin ke BENTUK lembar, bukan ke daftar nama alat: `TabelHasil` sudah
  /// tau kedua namanya, jadi lembar berikutnya yang tahapnya beda lagi ikut
  /// benar tanpa berkas ini disentuh.
  ///
  /// Nggak ketemu = pemanggilnya balik ke perilaku lama (`tahap` +
  /// [_titikTerdekat]) — respons server lama yang belum ngirim `tabel_id`, dan
  /// di lembar satu-tahap dua-duanya memang sama.
  TabelHasil? _tabelPindai(String tabelId) {
    if (tabelId.isEmpty) return null;

    for (final bagian in bentuk.bagian) {
      for (final t in bagian.tabel) {
        if ((t.grup ?? t.tahap) == tabelId) return t;
      }
    }

    return null;
  }

  /// Baris matriks yang penanda fotonya [penanda]. `null` = bukan penanda baris
  /// mana pun di matriks ini.
  static BarisMatriks? _barisMatriks(List<BarisMatriks> baris, double penanda) {
    for (var i = 0; i < baris.length; i++) {
      if (MatriksHasil.kunciBarisFoto(i) == penanda) return baris[i];
    }

    return null;
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
  /// Nomor Repeat diterjemahkan jadi posisi kolom lewat `tabel.pengulangan`,
  /// URUT seperti kolomnya tercetak.
  ///
  /// Dulu di sini `index = repeatNo - 1`, dan itu benar cuma selama daftarnya
  /// `[1, 2, 3, …]`. Daftarnya datang dari server (`json['pengulangan']`),
  /// jadi lembar yang Repeat-nya nggak mulai dari 1 atau nggak berurutan bikin
  /// tiap angka hasil foto mendarat di kolom yang salah — tanpa satu pun
  /// error, dengan tabel yang penuh dan wajar di layar.
  ///
  /// Bentuk bug yang SAMA sudah pernah menggigit `grid_sensor_state.dart` dan
  /// diperbaiki di sana dengan `indexOf`. Yang di sini kelewat karena semua
  /// lembar yang ada sekarang kebetulan `[1, 2, 3, …]` — jadi salahnya nggak
  /// pernah kelihatan, dan bakal muncul pertama kali di lembar baru yang
  /// nggak ada hubungannya dengan foto.
  int terapkanHasilFotoTabel(
    List<SelTabelFoto> sel, {
    required TabelHasil tabel,
  }) {
    var terisi = 0;

    for (final s in sel) {
      // Tabelnya sendiri yang jadi ruang cari, bukan seluruh lembar — lihat
      // [titikBarisTabel]. Sebelum ini `_titikTerdekat`, dan itu yang bikin
      // tombol foto lima lembar berpasangan mengisi nol sel.
      final state = titikBarisTabel(tabel, s.titikUkur);
      if (state == null) continue;

      final index = tabel.pengulangan.indexOf(s.repeatNo);
      if (index < 0 || index >= state.jumlahPengulangan) continue;

      // Teksnya dibaca jadi angka DI SINI, bukan di pemetanya: yang di sana
      // cuma menjawab "tempatnya di mana", dan mencampur dua urusan itu bikin
      // aturan angka tersebar di dua tempat.
      //
      // Teks KOSONG ikut lewat sini, dan itu disengaja. `FotoReviewScreen`
      // memulangkan SELURUH sel — termasuk yang teknisi kosongkan — supaya
      // keputusan "kosong = nggak usah ditaruh" cuma ada di satu tempat, yaitu
      // baris ini. Kosong berarti **jangan taruh apa-apa**, BUKAN "hapus isi
      // kotaknya": sel yang sudah ada isinya nggak pernah disentuh jalur foto
      // (lihat `GabungTabel.nilaiBaru` di `_isiSel`), jadi mengosongkan di
      // layar review nggak bisa dan nggak boleh menghapus angka yang sudah
      // diketik teknisi sebelumnya.
      final nilai = parseAngka(s.teks);
      if (nilai == null) continue;

      terisi += _isiSel(
        state,
        tabel.kunciTabel,
        s.fieldId,
        index,
        nilai,
        true,
        // Teks APA ADANYA, bukan `nilai` yang sudah jadi angka: yang mau diukur
        // nanti persis apa yang dilihat pengenalnya, termasuk waktu dia salah.
        bacaanMesin: BacaanMesin(teksMentah: s.teks, keyakinan: s.keyakinan),
      );
    }

    if (terisi > 0) adaIsianDariFoto = true;

    return terisi;
  }

  /// Tempelin tebakan mesin ke payload lembar BERPASANGAN (`standar_ocr` &
  /// `uut_ocr`), sejajar indeks sama deret sisinya masing-masing.
  ///
  /// ## Kenapa dua sisi dipisah
  ///
  /// Sisi standar dan sisi UUT punya tebakan yang beda, dan menukarnya bikin
  /// kolom `Correction` — selisih dua sisi itu — bergeser tanpa satu pun
  /// error. Kuncinya karena itu dibangun dari [DeretPasangan.kunciStandar] /
  /// [DeretPasangan.kunciUut], bukan dari satu kunci yang dipakai dua kali.
  ///
  /// ## Yang SENGAJA dilewati: lembar berkolom banyak
  ///
  /// Lembar Timer/Stopwatch menulis satu penunjukan di EMPAT kotak
  /// (jam/menit/detik/milidetik), dan server menyimpannya sebagai SATU baris
  /// dalam milidetik. Jadi empat tebakan mesin nggak punya satu kolom pun buat
  /// ditaruh, dan menggabungkannya jadi satu teks berarti mengarang bacaan
  /// yang nggak pernah dilihat pengenalnya. Dilewat di sini, bukan ditambal —
  /// lihat `docs/temuan-gerbang0-ocr-model-lokal.md`.
  Map<String, dynamic> _lampirkanBacaanMesinPasangan(
    Map<String, dynamic> payload,
    TitikState state,
    DeretPasangan deret,
  ) {
    for (final (kunci, nama) in [
      (deret.kunciStandar, 'standar'),
      (deret.kunciUut, 'uut'),
    ]) {
      final kolom = deret.kolomUntuk(kunci);
      if (kolom.length != 1) continue;

      final nilai = payload[nama] as List<dynamic>;
      final bacaan = <Map<String, dynamic>?>[];

      for (var i = 0; i < nilai.length; i++) {
        // Cuma buat sel yang angkanya beneran ikut terkirim — tebakan tanpa
        // angka final nggak punya pasangan buat diadu.
        bacaan.add(
          nilai[i] == null
              ? null
              : bacaanMesinSel[kunciSel(
                  state.titikUkur,
                  kunci,
                  kolom.first,
                  i,
                )]?.toJson(),
        );
      }

      if (bacaan.any((b) => b != null)) payload['${nama}_ocr'] = bacaan;
    }

    return payload;
  }

  /// Tempelin tebakan mesin ke deret `ocr` payload, sejajar indeks sama
  /// `pembacaan`.
  ///
  /// Dua hal di sini gampang salah dan dua-duanya gagal TANPA error:
  ///
  ///  - Kuncinya dibangun dari [TitikState.titikUkur], **bukan**
  ///    `titikUkurEfektif` yang dipakai payload. Yang dipakai [_isiSel] waktu
  ///    menyimpan yang pertama, dan di lembar yang titiknya bervarian dua nilai
  ///    itu beda — memakai yang salah bikin seluruh tebakan hilang diam-diam.
  ///  - Tahapnya [kunciTabelPembacaan], bukan tabel mana pun yang kebetulan
  ///    difoto. Foto tabel As-found nggak punya padanan di `measurements[].ocr`
  ///    (server memang selalu nulis tahap itu manual), jadi dia memang harus
  ///    nggak nempel — bukan nempel di deret yang salah.
  void _lampirkanBacaanMesin(
    TitikLembarKerja payload,
    TitikState state,
    String kunciUtama,
  ) {
    for (var i = 0; i < payload.ocr.length; i++) {
      // Cuma buat sel yang angkanya beneran ikut terkirim. Tebakan buat sel
      // yang akhirnya dikosongkan teknisi nggak punya pasangan buat diadu, dan
      // server juga melewatinya — `pembacaan` null berarti barisnya nggak lahir
      // sama sekali.
      if (payload.pembacaan[i] == null) continue;

      final bacaan =
          bacaanMesinSel[kunciSel(state.titikUkur, kunciUtama, 'pembacaan', i)];

      if (bacaan != null) payload.ocr[i] = bacaan;
    }
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
    bool perluDicek, {
    BacaanMesin? bacaanMesin,
  }) {
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

    final kunci = kunciSel(state.titikUkur, tahap, kolom, index);

    // Sel yang vonis servernya kuning/merah ditandai; kalau pindai ulang
    // mengisinya dengan vonis bagus, tandanya dilepas.
    _tandai(kunci, perluDicek);

    // Disimpan TERPISAH dari kotaknya — lihat [bacaanMesinSel] soal kenapa dia
    // harus selamat waktu teknisi mengetik ulang isinya.
    if (bacaanMesin != null) bacaanMesinSel[kunci] = bacaanMesin;

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
        () =>
            TextEditingController()..addListener(() => onIsianDiketik?.call()),
      );

  /// Tempelkan hasil foto matriks ke kotak-kotaknya. Balik berapa sel keisi.
  ///
  /// Penanda barisnya karangan ([MatriksHasil.kunciBarisFoto]) karena baris
  /// matriks itu besaran, bukan titik ukur — jadi yang menerjemahkannya balik
  /// ke `kodeData` cuma boleh method ini, dan urutan `semuaBaris` yang dipakai
  /// wajib SAMA dengan yang dipakai waktu penandanya dibikin.
  ///
  /// Dua hal yang sengaja dilewat:
  ///
  ///  - **Baris `Time`.** Isinya jam (`HH:mm:ss`), bukan hasil ukur. Dia tetap
  ///    ikut sebagai JANGKAR supaya angka yang kebetulan jatuh di barisnya
  ///    diklaim lalu dibuang di sini — bukan melayang ke baris tetangganya.
  ///  - **Kotak yang sudah ada isinya.** Angka yang sudah diketik orang
  ///    keputusan orang; foto cuma jalan pintas.
  int terapkanHasilFotoMatriks(MatriksHasil m, List<SelTabelFoto> sel) {
    final baris = m.semuaBaris;
    var terisi = 0;

    for (final s in sel) {
      if (!m.titikWaktu.contains(s.repeatNo)) continue;

      final b = _barisMatriks(baris, s.titikUkur);
      if (b == null || b.tipe == 'jam') continue;

      final nilai = double.tryParse(s.teks.trim().replaceAll(',', '.'));
      if (nilai == null) continue;

      final kotak = kotakMatriks(b.kodeData, s.repeatNo);
      if (kotak.text.trim().isNotEmpty) continue;

      kotak.text = s.teks.trim();

      final kunci = kunciMatriks(b.kodeData, s.repeatNo);
      matriksDariFoto.add(kunci);
      // Teks APA ADANYA, bukan `nilai` yang sudah jadi angka.
      bacaanMesinMatriks[kunci] = BacaanMesin(
        teksMentah: s.teks,
        keyakinan: s.keyakinan,
      );
      terisi++;
    }

    if (terisi > 0) adaIsianDariFoto = true;

    return terisi;
  }

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
  Map<String, dynamic> payloadMatriks(
    MatriksHasil m,
    TabelSatuBaris? tambahan,
  ) {
    final hasil = <String, dynamic>{};

    void tulis(String jalur, List<dynamic> nilai, {bool paksa = false}) {
      // `paksa` cuma dipakai deret `ocr`, dan alasannya bukan kenyamanan —
      // lihat komentar di pemanggilnya. Deret nilai yang kosong semua tetap
      // dibuang seperti biasa.
      if (!paksa && nilai.every((v) => v == null)) return;

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

    // Blok `ocr` cuma ada kalau memang ada yang difoto — lembar yang seluruhnya
    // diketik tangan nggak menitip kunci kosong.
    final adaFoto = bacaanMesinMatriks.isNotEmpty;

    for (final b in m.semuaBaris) {
      if (b.kodeData.isEmpty) continue;

      final nilai = [
        for (final t in m.titikWaktu)
          _nilaiSelMatriks(b, LembarKerjaState.kunciMatriks(b.kodeData, t)),
      ];

      // Baris yang sama sekali kosong nggak dikirim — dan karena itu, deret
      // `ocr`-nya juga nggak boleh dikirim. Lihat di bawah kenapa itu penting.
      if (nilai.every((v) => v == null)) continue;

      tulis(b.kodeData, nilai);

      if (!adaFoto) continue;

      /*
       * Tebakan mesin ditulis ke jalur yang SAMA, cuma berawalan `ocr.` — jadi
       * pasangannya di server ketemu lewat jalur yang identik, bukan lewat
       * kunci datar yang harus diurai ulang.
       *
       * `paksa: true`, dan ini BUKAN kelalaian. `_ratakanWadahBernomor`
       * meratakan wadah bernomor (`suhu.disk`) jadi List **menurut urutan
       * kunci yang ada**, bukan menurut nomornya. Jadi kalau cuma Temp Disk 3
       * yang difoto sementara ketiga disknya terisi, deret `ocr` yang cuma
       * berisi satu kunci bakal mendarat di indeks 0 — dan tebakan Disk 3
       * tercatat sebagai tebakan Disk 1.
       *
       * Salah pasangan begitu nggak pernah kelihatan: angkanya wajar,
       * jumlahnya pas, dan yang bohong cuma pasangannya. Dengan `paksa`, deret
       * `ocr` punya kunci yang SAMA PERSIS dengan deret nilainya, jadi
       * dua-duanya rata jadi List dengan panjang & urutan yang sama.
       */
      tulis('ocr.${b.kodeData}', [
        for (final t in m.titikWaktu)
          bacaanMesinMatriks[LembarKerjaState.kunciMatriks(
            b.kodeData,
            t,
          )]?.toJson(),
      ], paksa: true);
    }

    if (tambahan != null && tambahan.kodeData.isNotEmpty) {
      tulis(tambahan.kodeData, [
        for (final t in tambahan.pengulangan)
          parseAngka(
            matriks[LembarKerjaState.kunciMatriks(tambahan.kodeData, t)]
                    ?.text ??
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
            matriks[LembarKerjaState.kunciMatriks(b.kodeData, t)]?.text
                .trim() ??
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
        final urut = [...isi.keys]
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
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
        'tanggal_kalibrasi': tanggalKalibrasi.toIso8601String().substring(
          0,
          10,
        ),
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
