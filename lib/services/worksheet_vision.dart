/// Ekstraksi tabel worksheet lewat **AI Vision** (bukan OCR on-device lagi).
///
/// Alurnya: foto worksheet diunggah ke backend, backend manggil model vision
/// (Claude, lihat `SPEC-vision-ai-worksheet-extraction.md`) dan balikin angka
/// per sel **beserta tingkat keyakinannya**. Bedanya besar dari OCR ML Kit yang
/// dulu: AI paham layout tabel & tulisan tangan, jadi nggak perlu lagi nebak
/// posisi angka dari koordinat piksel — itu bagian yang dulu paling sering
/// meleset di lapangan.
///
/// **Tetap wajib dikonfirmasi manusia.** Hasil AI cuma **pra-isi** sel yang
/// masih bisa diedit teknisi; sel keyakinan rendah ditandai biar dicek ekstra.
/// Nggak ada data yang kesimpen tanpa teknisi menekan kirim.
library;

import 'dart:io';

import '../core/utils/angka.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

/// Tingkat keyakinan AI buat satu sel. Sel [rendah] ditandai di layar supaya
/// teknisi ngecek angka itu, bukan seluruh tabel (spec §4.1).
enum TingkatKeyakinan {
  tinggi,
  sedang,
  rendah;

  /// String asing / hilang dianggap [rendah] — lebih aman nyuruh cek daripada
  /// diam-diam ngelolosin angka yang backend sendiri nggak yakin.
  static TingkatKeyakinan fromApi(String? v) => switch (v) {
    'high' || 'tinggi' => TingkatKeyakinan.tinggi,
    'medium' || 'sedang' => TingkatKeyakinan.sedang,
    _ => TingkatKeyakinan.rendah,
  };

  bool get perluDicek => this == TingkatKeyakinan.rendah;
}

/// Satu baris pengulangan di tabel worksheet (Repeat 1..5).
///
/// Panjang [ph] & [suhu] selalu sama dengan jumlah larutan standar (3). `null`
/// berarti sel nggak kebaca — **bukan** nol, dan bukan ditebak.
class BarisTabel {
  const BarisTabel({
    required this.ph,
    required this.suhu,
    this.phKeyakinan = const [],
    this.suhuKeyakinan = const [],
  });

  final List<double?> ph;
  final List<double?> suhu;

  /// Keyakinan per sel, sejajar [ph]/[suhu]. Kosong = anggap [TingkatKeyakinan
  /// .tinggi] (mis. data mock lama / test yang nggak peduli confidence).
  final List<TingkatKeyakinan> phKeyakinan;
  final List<TingkatKeyakinan> suhuKeyakinan;

  TingkatKeyakinan keyakinanPh(int i) =>
      i < phKeyakinan.length ? phKeyakinan[i] : TingkatKeyakinan.tinggi;
  TingkatKeyakinan keyakinanSuhu(int i) =>
      i < suhuKeyakinan.length ? suhuKeyakinan[i] : TingkatKeyakinan.tinggi;

  bool get lengkap => !ph.contains(null) && !suhu.contains(null);
}

/// Satu kolom **non-tabel** hasil baca AI (env condition, lokasi, catatan).
///
/// [nilai] disimpen sebagai string, bukan angka: kolomnya campur — `suhu_awal`
/// itu angka tapi `catatan_teknisi` itu kalimat. Konversi ke angka baru terjadi
/// waktu payload disusun, lewat `parseAngka` yang sama dengan ketikan manual.
class NilaiHeader {
  const NilaiHeader({required this.nilai, required this.keyakinan});

  final String nilai;
  final TingkatKeyakinan keyakinan;

  static NilaiHeader? fromJson(dynamic json) {
    if (json is! Map) return null;
    final v = json['nilai'];
    // Angka dikirim balik apa adanya; `null` = nggak kebaca, dan itu **bukan**
    // alasan buat nulis string kosong ke kolomnya.
    final teks = v is num ? '$v' : (v is String ? v.trim() : '');
    if (teks.isEmpty) return null;
    return NilaiHeader(
      nilai: teks,
      keyakinan: TingkatKeyakinan.fromApi(json['keyakinan'] as String?),
    );
  }
}

/// Satu baris Usage Check hasil baca AI (centang standar mana yang dipakai).
///
/// Centang yang kebalik itu bukan salah angka — itu klaim standar mana yang
/// dipakai, alias ketertelusuran. Makanya di layar **semua** baris hasil AI
/// ditandai perlu dicek, bukan cuma yang keyakinannya rendah.
class UsageCheckAi {
  const UsageCheckAi({
    required this.standardId,
    required this.dipakai,
    required this.keterangan,
    required this.keyakinan,
  });

  final int standardId;
  final bool? dipakai;
  final String? keterangan;
  final TingkatKeyakinan keyakinan;

  /// Sengaja **melempar** kalau `standard_id` nggak ada, bukan balikin null:
  /// [parseListAman] yang nangkap & ngelewat baris cacat itu, jadi satu baris
  /// rusak nggak ngebatalin baris usage check lainnya.
  static UsageCheckAi fromJson(Map<String, dynamic> json) {
    final id = json['standard_id'];
    if (id is! num) throw const FormatException('standard_id wajib');
    final ket = json['keterangan'];
    return UsageCheckAi(
      standardId: id.toInt(),
      dipakai: json['dipakai'] is bool ? json['dipakai'] as bool : null,
      keterangan: ket is String && ket.trim().isNotEmpty ? ket.trim() : null,
      keyakinan: TingkatKeyakinan.fromApi(json['keyakinan'] as String?),
    );
  }
}

/// Blok non-tabel worksheet: env condition, lokasi, catatan, tanggal, usage
/// check.
///
/// **Kolom identitas sengaja nggak ada di sini** (nama alat, serial number,
/// merk, pelanggan). Itu semua sudah ada di DB dan ketarik lewat
/// `nilaiTurunan()`; membacanya dari foto strictly lebih buruk — serial number
/// salah satu digit bikin kalibrasi nempel ke instrumen yang salah, dan itu
/// cacat sertifikat, bukan sekadar bug. Kalau backend tetap ngirim kolom
/// bertitik, [LembarKerjaState.terapkanHasilHeader] bakal mengabaikannya
/// karena kolom turunan nggak pernah masuk map `teks`.
class HasilEkstraksiHeader {
  const HasilEkstraksiHeader({
    this.field = const {},
    this.tanggal = const {},
    this.usageCheck = const [],
  });

  /// Kunci = `kode` kolom di formulir (mis. `suhu_awal`, `catatan_teknisi`).
  final Map<String, NilaiHeader> field;

  /// Kunci = `kode` kolom tanggal (mis. `tanggal_terima`).
  final Map<String, NilaiHeader> tanggal;

  final List<UsageCheckAi> usageCheck;

  bool get kosong => field.isEmpty && tanggal.isEmpty && usageCheck.isEmpty;

  factory HasilEkstraksiHeader.fromJson(Map<String, dynamic> json) {
    Map<String, NilaiHeader> petakan(dynamic raw) {
      if (raw is! Map) return const {};
      final hasil = <String, NilaiHeader>{};
      raw.forEach((k, v) {
        if (k is! String) return;
        final nilai = NilaiHeader.fromJson(v);
        if (nilai != null) hasil[k] = nilai;
      });
      return hasil;
    }

    return HasilEkstraksiHeader(
      field: petakan(json['field']),
      tanggal: petakan(json['tanggal']),
      usageCheck: parseListAman<UsageCheckAi>(
        json['usage_check'],
        (e) => UsageCheckAi.fromJson(e),
      ),
    );
  }
}

/// Hasil ekstraksi AI dari satu foto worksheet: tabel hasil (Before ATAU After
/// adjustment) plus blok non-tabel di [header].
class HasilEkstraksiTabel {
  const HasilEkstraksiTabel({
    required this.baris,
    required this.jumlahSelKebaca,
    required this.jumlahSelDiharapkan,
    this.jumlahAngkaTerdeteksi = 0,
    this.header = const HasilEkstraksiHeader(),
  });

  final List<BarisTabel> baris;
  final int jumlahSelKebaca;
  final int jumlahSelDiharapkan;

  /// Blok non-tabel. Kosong kalau backend belum ngirim `header` — versi lama
  /// tetap jalan, cuma tabelnya doang yang keisi.
  final HasilEkstraksiHeader header;

  /// Berapa angka yang AI lihat di foto, sebelum dipetakan ke sel. Bedanya
  /// sama [jumlahSelKebaca] bikin pesan gagal berguna: terdeteksi 0 = fotonya
  /// bermasalah; terdeteksi banyak tapi sel 0 = fotonya bukan tabel worksheet.
  final int jumlahAngkaTerdeteksi;

  double get kelengkapan =>
      jumlahSelDiharapkan == 0 ? 0 : jumlahSelKebaca / jumlahSelDiharapkan;

  /// Parse respons `POST /raw-measurements/extract-from-photo`.
  ///
  /// Bentuk yang diharapkan (tiap larutan standar satu entri di `ph`/`suhu`,
  /// `null` kalau tak terbaca):
  /// ```json
  /// { "baris": [
  ///   { "ph": [4.01, 7.02, 10.11], "suhu": [22.2, 22.3, 22.1],
  ///     "ph_keyakinan": ["high","medium","low"],
  ///     "suhu_keyakinan": ["high","high","high"] }
  /// ] }
  /// ```
  factory HasilEkstraksiTabel.fromJson(
    Map<String, dynamic> json, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
  }) {
    List<double?> angka(dynamic list) {
      if (list is! List) return const [];
      return list.map((e) => e is num ? e.toDouble() : null).toList();
    }

    List<TingkatKeyakinan> keyakinan(dynamic list) {
      if (list is! List) return const [];
      return list
          .map((e) => TingkatKeyakinan.fromApi(e is String ? e : null))
          .toList();
    }

    final baris = parseListAman<BarisTabel>(json['baris'], (b) {
      return BarisTabel(
        ph: angka(b['ph']),
        suhu: angka(b['suhu']),
        phKeyakinan: keyakinan(b['ph_keyakinan']),
        suhuKeyakinan: keyakinan(b['suhu_keyakinan']),
      );
    });

    var kebaca = 0;
    var terdeteksi = 0;
    for (final b in baris) {
      kebaca += b.ph.whereType<double>().length +
          b.suhu.whereType<double>().length;
      terdeteksi += b.ph.length + b.suhu.length;
    }

    return HasilEkstraksiTabel(
      baris: baris,
      jumlahSelKebaca: kebaca,
      jumlahSelDiharapkan: jumlahBaris * jumlahTitik * 2,
      jumlahAngkaTerdeteksi: terdeteksi,
      header: json['header'] is Map
          ? HasilEkstraksiHeader.fromJson(
              Map<String, dynamic>.from(json['header'] as Map),
            )
          : const HasilEkstraksiHeader(),
    );
  }
}

/// Baca satu tabel worksheet dari foto lewat AI Vision di backend.
abstract class WorksheetVisionService {
  /// [sesiId] diisi kalau lagi lanjut draft; sesi baru belum punya id (ekstraksi
  /// jalan sebelum sesi kebentuk), jadi boleh null.
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik,
    int jumlahBaris,
    int? sesiId,
    String? satuan,
    List<double>? nominal,
    List<int?>? desimal,
  });

  void dispose();
}

class ApiWorksheetVisionService implements WorksheetVisionService {
  ApiWorksheetVisionService(this._api, this._token);

  final ApiClient _api;

  /// Token diambil lewat closure, bukan diparam, biar tanda tangan [ekstrak]
  /// sama persis dengan jalur lama — layar & test nggak perlu ikut berubah.
  final Future<String?> Function() _token;

  @override
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
    int? sesiId,
    String? satuan,
    List<double>? nominal,
    List<int?>? desimal,
  }) async {
    // Petunjuk buat AI: satuan + nilai nominal tiap kolom + jumlah desimalnya.
    // Dikirim indexed (`titik_nominal[0]`) biar keparse jadi array di Laravel.
    // Desimal cuma dikirim kalau LENGKAP semua titiknya (backend nolak null).
    final fields = <String, String>{
      if (sesiId != null) 'calibration_session_id': '$sesiId',
      'jumlah_titik': '$jumlahTitik',
      'jumlah_pengulangan': '$jumlahBaris',
      if (satuan != null && satuan.isNotEmpty) 'satuan': satuan,
    };
    if (nominal != null) {
      for (var i = 0; i < nominal.length; i++) {
        fields['titik_nominal[$i]'] = '${nominal[i]}';
      }
    }
    if (desimal != null && desimal.every((d) => d != null)) {
      for (var i = 0; i < desimal.length; i++) {
        fields['desimal[$i]'] = '${desimal[i]}';
      }
    }

    final json = await _api.unggahFile(
      '/raw-measurements/extract-from-photo',
      field: 'foto',
      filePath: foto.path,
      fields: fields,
      token: await _token(),
    );

    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return HasilEkstraksiTabel.fromJson(
      data,
      jumlahTitik: jumlahTitik,
      jumlahBaris: jumlahBaris,
    );
  }

  @override
  void dispose() {}
}

/// Pesan hasil foto tabel — **satu tempat**. Foto yang gagal bukan jalan buntu:
/// tiap cabang nutup dengan "kolomnya tetap bisa diketik manual", karena
/// teknisi udah berdiri di depan alat pelanggan — dia butuh jalan maju.
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
  return terdeteksi == 0 ? takTerbaca : posisiKacau(terdeteksi);
}

/// Aturan penggabungan hasil ekstraksi ke isian yang udah ada di form.
///
/// Ini **aturan paling berbahaya** di seluruh alur foto: teknisi boleh motret
/// berkali-kali buat nambal sel yang kurang, dan angka yang udah dia betulin
/// manual nggak boleh keganti sama jepretan berikutnya. Kalau ketimpa,
/// koreksinya ilang tanpa jejak — dan yang masuk sertifikat justru angka AI
/// yang tadi salah.
class GabungTabel {
  const GabungTabel._();

  /// Nilai baru buat satu sel, atau `null` kalau sel itu nggak boleh diubah.
  /// Sel dianggap kosong kalau isinya spasi doang.
  ///
  /// [desimal] = resolusi titiknya (Turbidimeter: 2/1/0). Kalau diisi,
  /// pembacaan dipad ke situ tanpa buang nol belakang — hasil kamera `4.6` di
  /// titik ber-resolusi 0,01 masuk sebagai `4,60`. `null` = alat resolusi
  /// seragam, pakai perilaku lama (buang nol belakang).
  static String? nilaiBaru(String sekarang, double? hasil, {int? desimal}) {
    if (hasil == null) return null;
    if (sekarang.trim().isNotEmpty) return null;
    // Dua jalurnya sama-sama pakai KOMA. `formatNilai` sengaja nggak diubah
    // global — dia kepakai juga di tabel Perhitungan & sertifikat, dan itu
    // urusan terpisah. Yang diseragamin cuma isian lembar kerja.
    return desimal != null
        ? formatNilai(hasil, desimalMin: desimal).replaceAll('.', ',')
        : _rapi(hasil);
  }

  /// Versi teks buat kolom non-tabel (catatan, lokasi, env condition).
  /// Aturannya **sama persis**: kolom yang udah ada isinya nggak pernah
  /// ditimpa, biar koreksi manual teknisi selamat dari foto berikutnya.
  static String? nilaiBaruTeks(String sekarang, String? hasil) {
    if (hasil == null || hasil.trim().isEmpty) return null;
    if (sekarang.trim().isNotEmpty) return null;
    return hasil.trim();
  }

  /// Buang nol di belakang: `4.0` → `4`, `22.2` tetap `22.2`, `10.11` tetap
  /// `10.11`. Bukan dibulatkan ke desimal tetap — pH 2 desimal, suhu 1 desimal.
  /// **8 desimal, dan komanya dipertahankan.** Dua perbaikan yang ketemu di
  /// merge — dua-duanya kepakai, bukan salah satu.
  ///
  /// *8, bukan 3.* Dulu `toStringAsFixed(3)`, dan itu MEMBUANG digit: AI baca
  /// `1,3362` dari foto Refractometer, yang mendarat di kotak `1,336`. Teknisi
  /// lihat angkanya "kurang" tanpa ada yang error — pembacaan resolusi 0,0001
  /// dipotong jadi 0,001, sepuluh kali lebih kasar dari alatnya. Tiga alat
  /// pertama selamat cuma karena kebetulan (paling halus 0,01).
  ///
  /// Angka 8 disamain sama `formatNilai` (`desimalMaks: 8`) dan kolom DB
  /// `decimal(20,8)` — batas presisi yang sama di seluruh sistem.
  ///
  /// *Desimalnya KOMA*, ngikut lembar kerjanya sendiri (titik ukur ditulis
  /// `1,74`) dan formulir kertasnya. Tanpa ini, di satu tabel yang sama label
  /// barisnya berkoma tapi isian yang dituangin AI bertitik — kelihatan kayak
  /// dua sumber angka yang beda. Kotaknya sendiri nerima dua-duanya
  /// (`parseAngka`), jadi ini murni biar kebacanya seragam.
  ///
  /// Nol di belakang tetap dibuang, jadi `25,0` tetap `25` dan derau float
  /// (`0.30000000000000004`) tetap jadi `0,3`.
  static String _rapi(double nilai) => nilai
      .toStringAsFixed(8)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
}

/// Baca tanggal hasil AI. Menerima `yyyy-MM-dd`, `dd/MM/yyyy`, `dd-MM-yyyy`.
///
/// Sengaja **nggak** nebak format ambigu: `03/04/2026` diartikan 3 April
/// (konvensi formulir Indonesia), dan apa pun di luar tiga pola itu dianggap
/// gagal — tanggal kalibrasi yang meleset sebulan lebih berbahaya daripada
/// kolom yang dibiarkan kosong buat diisi teknisi.
DateTime? parseTanggalAi(String teks) {
  final t = teks.trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
  if (iso != null) {
    return _bikinTanggal(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final lokal = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(t);
  if (lokal != null) {
    return _bikinTanggal(
      int.parse(lokal.group(3)!),
      int.parse(lokal.group(2)!),
      int.parse(lokal.group(1)!),
    );
  }
  return null;
}

/// `DateTime` diam-diam menggulung tanggal nggak valid (32 Jan → 1 Feb).
/// Di sini itu nggak boleh: kalau AI salah baca, kita mau gagal, bukan dapat
/// tanggal ngawur yang kelihatan sah.
DateTime? _bikinTanggal(int tahun, int bulan, int hari) {
  if (bulan < 1 || bulan > 12 || hari < 1 || hari > 31) return null;
  final d = DateTime(tahun, bulan, hari);
  if (d.year != tahun || d.month != bulan || d.day != hari) return null;
  return d;
}

/// Data tiruan buat test & jalanin app tanpa backend AI.
///
/// Default-nya pra-isi angka masuk akal biar `USE_MOCK` tetap bisa nyoba
/// alurnya. Sengaja ada satu sel keyakinan rendah supaya penandaan low-confidence
/// keliatan waktu demo.
///
/// **Pembacaannya diturunkan dari [nominal] tiap titik, bukan hardcode pH.**
/// Dulu mock ini selalu balikin 4.01/7.02/10.11 (buffer pH) apa pun alatnya —
/// jadi di `USE_MOCK`, kamera Turbidimeter ngisi angka pH ke kolom NTU dan
/// kelihatan "nggak jalan". Sekarang tiap kolom dapat angka dekat nilai
/// nominalnya (mis. NTU 1/100/1000 → 1,01/100,1/1001), dipad ke [desimal] titik
/// itu (Turbidimeter 2/1/0). Alur backend asli udah bener dari dulu — ini murni
/// bikin jalur mock ikut sadar-alat.
///
/// Blok [HasilEkstraksiHeader]-nya juga diisi contoh — env condition + catatan.
/// Usage check buffer 4/7/10 (id 3/4/5) **cuma** diisi kalau alatnya pH; buat
/// alat lain id itu nggak nyambung ke standarnya, jadi dikosongin. Sengaja
/// **nggak** ada kolom identitas di sini: itu memang nggak boleh datang dari foto.
class MockWorksheetVisionService implements WorksheetVisionService {
  MockWorksheetVisionService({this.hasil, this.gagal = false});

  final HasilEkstraksiTabel? hasil;
  final bool gagal;

  @override
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
    int? sesiId,
    String? satuan,
    List<double>? nominal,
    List<int?>? desimal,
  }) async {
    if (gagal) throw Exception('ekstraksi AI gagal');
    if (hasil != null) return hasil;

    // Pembacaan tiap kolom dekat nilai NOMINAL-nya (bukan hardcode pH). Kolom
    // terakhir digeser satu langkah resolusi + ditandai low-confidence biar
    // penandaan keliatan waktu demo. Kalau `nominal` nggak dikirim (test lama),
    // jatuh ke deret pH 4/7/10 biar perilakunya nggak berubah.
    double bacaan(int t) {
      final fallback = [4.01, 7.02, 10.11][t % 3];
      if (nominal == null || t >= nominal.length) return fallback;
      final d = (desimal != null && t < desimal.length) ? desimal[t] : null;
      final langkah = d != null ? _pow10(-d) : 0.01;
      // Kolom terakhir menyimpang satu langkah (nunjukin koreksi), lainnya pas.
      final nilai = nominal[t] + (t == jumlahTitik - 1 ? langkah : 0);
      return d != null ? _bulatkanDesimal(nilai, d) : nilai;
    }

    final unitPh = (satuan ?? '').toLowerCase() == 'ph';

    // SEMUA Repeat kebaca, bukan cuma satu.
    //
    // Dulu mock ini balikin satu baris doang, jadi di lembar Chlorine (2 titik)
    // hasilnya "4 dari 20 sel keisi" dan di layar kebaca kayak kameranya gagal
    // 80% — padahal itu emang cuma data contohnya yang sedikit. Backend asli
    // balikin semua Repeat yang kebaca, jadi mock-nya disamain.
    //
    // Satu sel SENGAJA disisain keyakinan rendah (Repeat terakhir, titik
    // terakhir): penandaan low-confidence itu pagar penting di alur foto, dan
    // kalau nggak pernah kelihatan waktu demo, nggak ada yang tau dia ada.
    final baris = [
      for (var r = 0; r < jumlahBaris; r++)
        BarisTabel(
          ph: List.generate(jumlahTitik, bacaan),
          suhu: List.filled(jumlahTitik, 22.2),
          phKeyakinan: List.generate(
            jumlahTitik,
            (t) => (r == jumlahBaris - 1 && t == jumlahTitik - 1)
                ? TingkatKeyakinan.rendah
                : TingkatKeyakinan.tinggi,
          ),
          suhuKeyakinan: List.filled(jumlahTitik, TingkatKeyakinan.tinggi),
        ),
    ];
    final selKebaca = jumlahBaris * jumlahTitik * 2;

    return HasilEkstraksiTabel(
      baris: baris,
      jumlahSelKebaca: selKebaca,
      jumlahSelDiharapkan: selKebaca,
      jumlahAngkaTerdeteksi: selKebaca,
      header: HasilEkstraksiHeader(
        // Env condition itu sifat RUANGAN, sama buat alat apa pun — selalu diisi.
        field: {
          'suhu_awal': const NilaiHeader(
            nilai: '22.4',
            keyakinan: TingkatKeyakinan.tinggi,
          ),
          'kelembaban_awal': const NilaiHeader(
            nilai: '55',
            keyakinan: TingkatKeyakinan.tinggi,
          ),
          'suhu_akhir': const NilaiHeader(
            nilai: '22.9',
            keyakinan: TingkatKeyakinan.tinggi,
          ),
          // Tulisan tangan paling sering meleset di kelembaban akhir yang
          // ditulis mepet garis tabel — dipakai buat nunjukin penandaan.
          'kelembaban_akhir': const NilaiHeader(
            nilai: '54',
            keyakinan: TingkatKeyakinan.rendah,
          ),
          // Catatan contoh yang nyebut "buffer" cuma nyambung buat pH.
          if (unitPh)
            'catatan_teknisi': const NilaiHeader(
              nilai: 'Buffer 10 baru dibuka sebelum pengukuran.',
              keyakinan: TingkatKeyakinan.sedang,
            ),
        },
        tanggal: const {
          'tanggal_terima': NilaiHeader(
            nilai: '23/07/2026',
            keyakinan: TingkatKeyakinan.sedang,
          ),
        },
        // id 3/4/5 = buffer pH 7/4/10 di `standard_service.dart` — cuma nyambung
        // buat pH. Alat lain: dikosongin, biar usage check nggak nunjuk standar
        // yang salah.
        usageCheck: unitPh
            ? const [
                UsageCheckAi(
                  standardId: 4,
                  dipakai: true,
                  keterangan: null,
                  keyakinan: TingkatKeyakinan.tinggi,
                ),
                UsageCheckAi(
                  standardId: 3,
                  dipakai: true,
                  keterangan: null,
                  keyakinan: TingkatKeyakinan.tinggi,
                ),
                UsageCheckAi(
                  standardId: 5,
                  dipakai: true,
                  keterangan: null,
                  keyakinan: TingkatKeyakinan.tinggi,
                ),
              ]
            : const [],
      ),
    );
  }

  @override
  void dispose() {}

  /// 10 pangkat [n] buat n kecil (0..8). Dipakai nyari satu langkah resolusi
  /// dari jumlah desimal: desimal 2 → 0.01, desimal 0 → 1.
  static double _pow10(int n) {
    var hasil = 1.0;
    for (var i = 0; i < n.abs(); i++) {
      hasil *= 10;
    }
    return n < 0 ? 1 / hasil : hasil;
  }

  /// Bulatkan [nilai] ke [desimal] angka di belakang koma — biar mock nggak
  /// nyisain ekor float (1.02 tetap 1.02, bukan 1.0200000001).
  static double _bulatkanDesimal(double nilai, int desimal) {
    final f = _pow10(desimal);
    return (nilai * f).roundToDouble() / f;
  }
}
