import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Satu angka yang kebaca dari foto, beserta letaknya.
///
/// Posisi ikut dibawa karena buat tabel, "angka apa" doang nggak cukup — yang
/// nentuin `4,04` itu milik kolom buffer 3,99 atau 7,00 adalah **letaknya**,
/// bukan urutan kemunculannya di teks. ML Kit ngeluarin blok teks dengan urutan
/// yang nggak dijamin ngikutin bacaan manusia.
class KotakAngka {
  const KotakAngka({required this.nilai, required this.x, required this.y});

  final double nilai;

  /// Titik tengah kotak, dalam piksel foto.
  final double x;
  final double y;
}

/// Satu baris pengulangan di tabel worksheet (Repeat 1..5).
///
/// Panjang [ph] & [suhu] selalu sama dengan jumlah titik buffer (3). `null`
/// berarti sel itu nggak kebaca — **bukan** nol, dan bukan ditebak.
class BarisTabel {
  const BarisTabel({required this.ph, required this.suhu});

  final List<double?> ph;
  final List<double?> suhu;

  /// Semua sel di baris ini kebaca.
  bool get lengkap =>
      !ph.contains(null) && !suhu.contains(null);
}

/// Hasil baca satu tabel (Before ATAU After adjustment).
class HasilTabelOcr {
  const HasilTabelOcr({
    required this.baris,
    required this.teksMentah,
    required this.jumlahSelKebaca,
    required this.jumlahSelDiharapkan,
    this.jumlahAngkaTerdeteksi = 0,
  });

  final List<BarisTabel> baris;

  /// Seluruh teks apa adanya — dikirim ke backend sebagai `ocr_raw_text`,
  /// jadi kalau ada sengketa angka, ini buktinya.
  final String teksMentah;

  final int jumlahSelKebaca;
  final int jumlahSelDiharapkan;

  /// Berapa angka yang ML Kit lihat di foto, sebelum dipetakan ke sel.
  ///
  /// Bedanya sama [jumlahSelKebaca] itu yang bikin pesan gagal berguna:
  /// - terdeteksi 0  -> fotonya yang bermasalah (gelap, buram, kejauhan)
  /// - terdeteksi banyak tapi sel 0 -> angkanya kebaca, tapi **posisinya**
  ///   nggak kebentuk tabel: fotonya miring, atau yang kefoto selembar penuh
  ///
  /// Dua masalah itu beda obatnya. Tanpa angka ini, dua-duanya cuma jadi
  /// "nggak ada angka yang kebaca" dan teknisi nebak-nebak.
  final int jumlahAngkaTerdeteksi;

  /// 0..1 — sekadar seberapa penuh tabelnya kebaca, **bukan** jaminan
  /// angkanya bener. Dipakai buat mutusin "cukup" atau "foto ulang".
  double get kelengkapan =>
      jumlahSelDiharapkan == 0 ? 0 : jumlahSelKebaca / jumlahSelDiharapkan;
}

/// Baca satu **tabel worksheet** (bukan layar alat) — semua di HP.
///
/// Beda dari [OcrService] di `ocr_service.dart` yang baca layar digital pH
/// meter satu angka per foto. Yang ini buat lembar worksheet yang udah diisi di
/// lapangan: sekali foto, satu tabel penuh.
///
/// **Akurasi tergantung isian worksheet-nya.** Angka tercetak (worksheet
/// Excel) kebaca bagus; tulisan tangan jauh lebih meleset — ML Kit dilatih buat
/// teks cetak, dan `4`/`9`, `1`/`7`, koma/titik itu yang paling sering ketuker.
/// Makanya nggak ada jalur "langsung terima": semua hasil masuk sebagai
/// isian yang masih harus dicek manusia.
abstract class WorksheetOcrService {
  Future<HasilTabelOcr?> bacaTabel(File foto, {int jumlahTitik, int jumlahBaris});

  void dispose();
}

class MlKitWorksheetOcrService implements WorksheetOcrService {
  final _pengenal = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<HasilTabelOcr?> bacaTabel(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
  }) async {
    final hasil = await _pengenal.processImage(InputImage.fromFile(foto));

    // Dipecah sampai level `element` (satu "kata"), bukan `line`: satu baris
    // tabel kebaca ML Kit sebagai satu line panjang, dan kalau dipakai
    // apa adanya, posisi tiap angkanya ilang.
    final kotak = <KotakAngka>[];
    for (final blok in hasil.blocks) {
      for (final baris in blok.lines) {
        for (final elemen in baris.elements) {
          final nilai = TabelWorksheetParser.keAngka(elemen.text);
          if (nilai == null) continue;

          final b = elemen.boundingBox;
          kotak.add(
            KotakAngka(
              nilai: nilai,
              x: b.left + b.width / 2,
              y: b.top + b.height / 2,
            ),
          );
        }
      }
    }

    return TabelWorksheetParser.susun(
      kotak,
      teksMentah: hasil.text,
      jumlahTitik: jumlahTitik,
      jumlahBaris: jumlahBaris,
    );
  }

  @override
  void dispose() => _pengenal.close();
}

/// Pesan hasil foto tabel — **satu tempat**, dipakai gerbang depan maupun
/// tombol foto di halaman data.
///
/// Kuncinya: foto yang gagal bukan jalan buntu. Tiap cabang selalu nutup
/// dengan "kolomnya tetap bisa diketik manual", karena teknisi udah berdiri di
/// depan alat pelanggan — dia butuh jalan maju, bukan vonis.
String pesanHasilFotoTabel({
  required int terisi,
  required int diharapkan,
  required int terdeteksi,
  required String takTerbaca,
  required String Function(int) posisiKacau,
  required String Function(int, int) berhasil,
  required String sisa,
}) {
  if (terisi > 0) {
    return terisi < diharapkan
        ? '${berhasil(terisi, diharapkan)} $sisa'
        : berhasil(terisi, diharapkan);
  }

  // Nol sel keisi punya dua sebab yang beda obatnya — dibedain di sini biar
  // teknisi nggak nebak-nebak.
  return terdeteksi == 0 ? takTerbaca : posisiKacau(terdeteksi);
}

/// Nyusun angka-angka berserakan jadi tabel.
///
/// Dipisah dari ML Kit **dengan sengaja** — ini bagian yang paling gampang
/// salah, dan harus bisa diuji tanpa kamera, HP, atau foto sungguhan. Semua
/// aturannya ada di sini, satu tempat.
class TabelWorksheetParser {
  const TabelWorksheetParser._();

  /// Batas skala pH. Angka di atas ini nggak mungkin pembacaan pH.
  static const double phMaks = 14.0;

  /// Rentang suhu larutan yang masuk akal di lab. Dipakai buat mastiin kolom
  /// pH dan kolom °C nggak ketuker — bukan buat nolak data.
  static const double suhuMin = 5.0;
  static const double suhuMaks = 60.0;

  /// Ambil satu bilangan dari teks OCR. Koma dianggap titik desimal —
  /// worksheet di sini pakai format Indonesia (`4,04`).
  ///
  /// Teks yang bukan bilangan murni (mis. `pH`, `Repeat`) dibuang.
  static double? keAngka(String teks) {
    // Tulisan tangan bikin ML Kit sering nempelin sampah di ujung angka:
    // `4,04.`, `|7,02`, `9,61°`, `(22,2)`. Dulu pola ini ditolak mentah-mentah
    // karena harus bilangan murni — di lembar tulisan tangan itu artinya
    // hampir semua sel kebuang, dan hasilnya "nggak ada angka yang kebaca"
    // padahal angkanya kelihatan jelas di foto.
    final bersih = teks
        .trim()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'^[^\d]+'), '')
        .replaceAll(RegExp(r'[^\d]+$'), '');

    if (bersih.isEmpty) return null;

    // Titik desimal ganda (`4.0.4`) = kebacaan ngaco, jangan ditebak.
    if (RegExp(r'\.').allMatches(bersih).length > 1) return null;
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(bersih)) return null;

    return double.tryParse(bersih);
  }

  /// Buang angka yang jelas BUKAN isi sel tabel.
  ///
  /// Foto worksheet itu selembar penuh, bukan tabelnya doang: ada nomor
  /// formulir (`0509`), nomor akreditasi (`285`), tahun (`2024`), nomor
  /// halaman, dan label kolom standar (`4.00`, `7.00`, `10.01`). Kalau semua
  /// itu ikut, pusat baris & kolom dihitung dari sebaran yang salah — dan
  /// seluruh tabel meleset walaupun tiap angkanya kebaca benar.
  ///
  /// Aturannya sengaja longgar: yang dibuang cuma yang **mustahil** jadi isi
  /// sel, bukan yang kelihatan aneh. Pembacaan menyimpang justru temuan yang
  /// harus lolos.
  static List<KotakAngka> saringKandidat(List<KotakAngka> kotak) {
    return kotak.where((k) {
      // Isi sel cuma dua macam: pembacaan pH (0–14) atau suhu larutan (5–60).
      final mungkinPh = k.nilai >= 0 && k.nilai <= phMaks;
      final mungkinSuhu = k.nilai >= suhuMin && k.nilai <= suhuMaks;
      return mungkinPh || mungkinSuhu;
    }).toList();
  }

  /// Kelompokin angka jadi baris (pakai koordinat y), lalu urutkan tiap baris
  /// kiri→kanan (pakai x).
  static HasilTabelOcr? susun(
    List<KotakAngka> kotak, {
    required String teksMentah,
    int jumlahTitik = 3,
    int jumlahBaris = 5,
  }) {
    final diharapkan = jumlahBaris * jumlahTitik * 2;
    if (kotak.isEmpty) return null;

    // Buang kop, nomor formulir, tahun, dan label kolom standar dulu —
    // kalau ikut, pusat baris & kolom dihitung dari sebaran yang salah.
    final bersih = saringKandidat(kotak);

    // Sengaja NGGAK balikin null: hasil kosong yang bawa jumlah angka
    // terdeteksi jauh lebih berguna daripada null yang cuma bisa bilang
    // "gagal". Layar yang mutusin pesannya.
    if (bersih.isEmpty) {
      return HasilTabelOcr(
        baris: List.generate(
          jumlahBaris,
          (_) => BarisTabel(
            ph: List.filled(jumlahTitik, null),
            suhu: List.filled(jumlahTitik, null),
          ),
        ),
        teksMentah: teksMentah,
        jumlahSelKebaca: 0,
        jumlahSelDiharapkan: diharapkan,
        jumlahAngkaTerdeteksi: 0,
      );
    }

    final baris = _kelompokkanBaris(bersih, jumlahBaris);

    // Kolom ditentukan SEKALI dari seluruh angka, bukan per baris.
    //
    // Ini inti kebenarannya: kalau tiap baris dipasangin berurutan
    // (angka ke-1 & ke-2 = titik pertama, dst), satu sel yang nggak kebaca
    // bikin seluruh sisa baris geser satu kolom — dan angka gesernya tetap
    // "masuk akal" (pH 7,01 nempel ke kolom buffer 4), jadi lolos diam-diam.
    // Dengan kolom global, sel yang hilang meninggalkan lubang di tempatnya.
    final kolom = _pusatKolom(bersih, jumlahTitik);

    final hasil = <BarisTabel>[];
    var kebaca = 0;

    for (var i = 0; i < jumlahBaris; i++) {
      final isi = i < baris.length ? baris[i] : <KotakAngka>[];
      final sel = _petakanBaris(isi, kolom, jumlahTitik);

      hasil.add(sel);
      kebaca += sel.ph.whereType<double>().length +
          sel.suhu.whereType<double>().length;
    }

    return HasilTabelOcr(
      baris: hasil,
      teksMentah: teksMentah,
      jumlahSelKebaca: kebaca,
      jumlahSelDiharapkan: diharapkan,
      jumlahAngkaTerdeteksi: bersih.length,
    );
  }

  /// Pisahin angka jadi baris berdasarkan kedekatan vertikal.
  ///
  /// Ambangnya diturunkan dari sebaran data itu sendiri (setengah jarak
  /// rata-rata antar baris), bukan angka piksel tetap — foto dari jarak beda
  /// bikin tinggi barisnya beda, dan ambang tetap bakal salah di salah satunya.
  static List<List<KotakAngka>> _kelompokkanBaris(
    List<KotakAngka> kotak,
    int jumlahBaris,
  ) {
    final urut = [...kotak]..sort((a, b) => a.y.compareTo(b.y));

    final rentang = urut.last.y - urut.first.y;
    // Semua angka nyaris sejajar → cuma satu baris.
    if (rentang <= 0) return [urut];

    final ambang = (rentang / math.max(jumlahBaris, 1)) * 0.6;

    final baris = <List<KotakAngka>>[];
    var sekarang = <KotakAngka>[urut.first];

    for (var i = 1; i < urut.length; i++) {
      if (urut[i].y - sekarang.last.y > ambang) {
        baris.add(sekarang);
        sekarang = [];
      }
      sekarang.add(urut[i]);
    }
    baris.add(sekarang);

    return baris;
  }

  /// Titik tengah tiap kolom data, diturunkan dari sebaran x seluruh angka.
  ///
  /// Balikin persis `jumlahTitik * 2` kolom (pH, °C, pH, °C, ...) — kolom
  /// nomor Repeat di paling kiri dibuang di sini, sekali, bukan ditebak ulang
  /// tiap baris.
  static List<double> _pusatKolom(List<KotakAngka> kotak, int jumlahTitik) {
    final perlu = jumlahTitik * 2;
    final urut = [...kotak]..sort((a, b) => a.x.compareTo(b.x));

    final rentang = urut.last.x - urut.first.x;
    if (rentang <= 0) return const [];

    // Ambang dari sebaran data, bukan piksel tetap — foto dari jarak beda
    // bikin lebar kolomnya beda.
    final ambang = (rentang / math.max(perlu, 1)) * 0.5;

    final gugus = <List<double>>[];
    var sekarang = <double>[urut.first.x];

    for (var i = 1; i < urut.length; i++) {
      if (urut[i].x - sekarang.last > ambang) {
        gugus.add(sekarang);
        sekarang = [];
      }
      sekarang.add(urut[i].x);
    }
    gugus.add(sekarang);

    final pusat = gugus
        .map((g) => g.reduce((a, b) => a + b) / g.length)
        .toList();

    // Kolom nomor Repeat (1..5) ikut kebaca OCR sebagai angka. Kalau
    // kolomnya kelebihan persis satu, yang paling kiri itu dia.
    if (pusat.length == perlu + 1) return pusat.sublist(1);

    return pusat;
  }

  /// Petakan satu baris ke kolom-kolom yang udah ditentukan.
  ///
  /// Tiap angka ditaruh di kolom TERDEKAT, bukan diurut berpasangan — jadi sel
  /// yang nggak kebaca ninggalin lubang di kolomnya sendiri, nggak menggeser
  /// tetangganya.
  static BarisTabel _petakanBaris(
    List<KotakAngka> baris,
    List<double> kolom,
    int jumlahTitik,
  ) {
    final kosong = BarisTabel(
      ph: List.filled(jumlahTitik, null),
      suhu: List.filled(jumlahTitik, null),
    );

    if (baris.isEmpty || kolom.length != jumlahTitik * 2) return kosong;

    final isiKolom = List<double?>.filled(kolom.length, null);
    final jarakTerdekat = List<double>.filled(kolom.length, double.infinity);

    for (final angka in baris) {
      var terdekat = 0;
      var jarak = (angka.x - kolom[0]).abs();

      for (var k = 1; k < kolom.length; k++) {
        final d = (angka.x - kolom[k]).abs();
        if (d < jarak) {
          jarak = d;
          terdekat = k;
        }
      }

      // Dua angka rebutan satu kolom (mis. nomor Repeat yang nggak kebuang):
      // yang paling pas posisinya yang menang, sisanya dibuang.
      if (jarak < jarakTerdekat[terdekat]) {
        isiKolom[terdekat] = angka.nilai;
        jarakTerdekat[terdekat] = jarak;
      }
    }

    final ph = <double?>[];
    final suhu = <double?>[];

    for (var t = 0; t < jumlahTitik; t++) {
      final kiri = isiKolom[t * 2];
      final kanan = isiKolom[t * 2 + 1];

      // Tiap sel dinilai sendiri-sendiri: pH di luar skala 0–14, atau suhu di
      // luar rentang lab, berarti kolomnya ketuker atau OCR-nya meleset.
      ph.add(kiri != null && kiri <= phMaks ? kiri : null);
      suhu.add(
        kanan != null && kanan >= suhuMin && kanan <= suhuMaks ? kanan : null,
      );
    }

    return BarisTabel(ph: ph, suhu: suhu);
  }
}

/// Aturan penggabungan hasil foto ke isian yang udah ada di form.
///
/// Dipisah jadi fungsi murni karena ini **aturan paling berbahaya** di seluruh
/// alur foto: teknisi boleh motret berkali-kali buat nambal sel yang kurang,
/// dan angka yang udah dia betulin manual nggak boleh keganti sama jepretan
/// berikutnya. Kalau ketimpa, koreksinya ilang tanpa jejak — dan yang masuk
/// sertifikat justru angka OCR yang tadi salah.
class GabungTabel {
  const GabungTabel._();

  /// Nilai baru buat satu sel, atau `null` kalau sel itu nggak boleh diubah.
  ///
  /// Sel dianggap kosong kalau isinya spasi doang — teknisi yang nge-tap kolom
  /// lalu pindah tanpa ngetik ninggalin spasi, dan itu tetap "belum diisi".
  static String? nilaiBaru(String sekarang, double? hasilOcr) {
    if (hasilOcr == null) return null;
    if (sekarang.trim().isNotEmpty) return null;
    return _rapi(hasilOcr);
  }

  /// Buang nol di belakang: `4.0` → `4`, `22.2` tetap `22.2`, `10.11` tetap
  /// `10.11`.
  ///
  /// Bukan dibulatkan ke jumlah desimal tetap — pH ditulis 2 desimal (`4,04`)
  /// tapi suhu cuma 1 (`22,2`). Dipaksa sama-sama 2 bikin suhunya nampil
  /// `22.20`, dan teknisi yang ngebandingin sama worksheet jadi ragu apakah
  /// angkanya kebaca bener.
  static String _rapi(double nilai) {
    // `toStringAsFixed` dijamin punya titik desimal, jadi pola di bawah nggak
    // akan makan nol dari bilangan bulat (`100` nggak jadi `1`).
    return nilai.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// Data tiruan buat test & jalanin app tanpa kamera.
class MockWorksheetOcrService implements WorksheetOcrService {
  MockWorksheetOcrService({this.hasil, this.gagal = false});

  final HasilTabelOcr? hasil;
  final bool gagal;

  @override
  Future<HasilTabelOcr?> bacaTabel(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
  }) async {
    if (gagal) throw Exception('kamera nggak bisa dibuka');
    return hasil;
  }

  @override
  void dispose() {}
}
