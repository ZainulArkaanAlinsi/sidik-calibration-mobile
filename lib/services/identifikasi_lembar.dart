import 'dart:math' as math;

import 'jenis_lembar.dart';

/// IDENTIFIKASI LEMBAR BERLAPIS: dari teks satu halaman (hasil ML Kit
/// sehalaman), kumpulkan BUKTI dari beberapa tempat di formulir, lalu putuskan
/// apa yang pantas dipilih-awal. Murni fungsi teks: tidak menyentuh kamera,
/// jaringan, atau state.
///
/// INI JALUR PRODUKSI alur "Pindai lembar" (`kenaliJenisLembar` memanggilnya
/// tiap putaran foto). `detectWorksheetType` (`jenis_lembar.dart`, kode bersih
/// persis) tinggal acuan tes; aturan lama "huruf tidak ditebak" TIDAK berlaku
/// di jalur ini, diganti aturan di bawah. `cariKodeDokumen` (pindai sel,
/// `jalankan_pindai_asli.dart`) tetap ketat dan tetap menolak jenis yang
/// kodenya tidak persis sama sebelum satu sel pun terisi, jadi jenis keliru
/// dari bacaan samar tidak bisa mengisi apa pun.
///
/// BOBOT DAN AMBANG DI BAWAH BELUM DIKALIBRASI pada keluaran ML Kit nyata:
/// semuanya dari teks sintetis yang meniru pola galat OCR. Kalibrasi = tugas
/// tersendiri dengan foto asli (target verifikasi 26 Nov 2026), bukan kira-kira.
///
/// Pola galat yang dirancang (dari pengamatan satu foto contoh, belum diukur):
/// kode kaki (`SIDIK-FM-CAL-0511`) terpotong tepi bingkai, 0 terbaca O, pemisah
/// berganti titik; judul tergores lingkaran; dan blok "Calibration Method:
/// SIDIK-IK-CAL-0508" mirip kode formulir padahal bukan. Pengenal satu lapis
/// (regex ketat) kalau bukan menolak semuanya, menebak.
///
/// Aturan yang TIDAK dilonggarkan:
///  - Hanya usulan. Hasil ini memilih-awal satu baris di lembar pilihan;
///    teknisi tetap menekan "Pakai jenis lembar ini". Tidak ada navigasi,
///    isian, atau penyimpanan di sini.
///  - Tidak ada tebakan diam-diam. Setiap bacaan dicocokkan ke himpunan kode
///    dan judul yang DIKENAL server (`dikenal`), bukan ke pola bebas. Kode
///    bersih yang tak ada di daftar tetap "tidak dikenal", tidak "didekati".
///    Himpunannya tertutup: jenis yang belum dipetakan server atau sengaja
///    dikeluarkan (Temperatur Indikator) tidak bisa jadi pesaing, sehingga
///    tetangganya bisa menyerap bacaan rusak. Itu sebab ambang di bawah ketat.
///  - Angka tidak ditukar dengan angka lain (`0599` bukan `0509`). Yang
///    ditoleransi: huruf yang MIRIP angka (O/0, I/l/1, S/5, B/8 ...), huruf
///    asing di posisi angka (biaya tinggi), angka yang hilang (`1` murah,
///    lainnya mahal), dan ekor yang terpotong.
///  - Kode berkelas IK/IM (kode instruksi kerja) dan kode yang didahului kata
///    "Metode" bukan kode formulir; diabaikan.
///  - Judul bukan pengenal: judul saja tidak pernah memilih-awal.
///  - Pilih-awal hanya bila SEMUA lapis yang punya bukti sepakat pada TEPAT
///    satu jenis dan skornya cukup: kode bersih >= 0,70; bacaan kode SAMAR
///    tanpa judul >= 0,78; kode samar + judul sepakat >= 0,70 dengan lapis
///    kode sendiri >= 0,60 (judul yang kuat tidak boleh menyelamatkan serpihan
///    kode yang kosong, mis. `05XX`). Kode bilang A, judul bilang B =
///    bertentangan: keduanya ditampilkan, tidak ada yang dipilihkan.
///  - Revisi ("Revise : 5") hanya pemeriksa konsistensi. Ia tidak pernah
///    menambah skor; revisi yang beda dari server mengurangi.
///
/// Lapis jangkar teks templat (`registrasi_jangkar_teks.dart`) TIDAK dipakai
/// di sini: daftar `GET /worksheet-templates` tidak membawa jangkar per
/// jenis, dan mengunduhnya per jenis sebelum jenisnya diketahui tidak masuk
/// akal.

// ---- Skor dan ambang. Satu tempat, supaya mudah ditinjau. ------------------

/// Skor kode yang terbaca bersih dan cocok persis.
const _skorKodeTepat = 0.92;

/// Pengurang skor kode per satuan biaya jarak (lihat [_biayaNomor]).
const _kemiringanKode = 0.20;
const _skorMinKode = 0.20;

/// Bacaan kode dengan biaya di atas ini dianggap tidak cocok dengan apa pun.
const _biayaKodeMaks = 2.0;

/// Kandidat kode yang biayanya dalam selisih ini dari yang terbaik dianggap
/// "sama dekat" (tidak ada pemenang).
const _celahKodeDekat = 0.6;

/// Lebih dari ini jenis kode yang sama dekat = bacaan kode terlalu kabur untuk
/// berdiri sendiri. Ia hanya boleh MENGUATKAN jenis yang sama-sama ditunjuk
/// judul, tidak pernah menjadi usulan atau penentang.
const _maksGrupKodeDekat = 3;

const _skorJudulTepat = 0.75;
const _kemiringanJudul = 0.15;
const _skorMinJudul = 0.20;

/// Skor gabungan minimal untuk memilih-awal satu baris (kode bersih, atau
/// kode samar yang disepakati judul).
const _ambangPraPilih = 0.70;

/// Pilih-awal dari bacaan kode SAMAR tanpa dukungan judul. Lebih tinggi karena
/// tidak ada bukti kedua: satu huruf asing di posisi angka (skor 0,74) atau satu
/// angka non-1 yang hilang (0,72) tidak cukup, sedangkan sampai dua huruf kembar
/// (0,80) atau "1" yang hilang (0,82) cukup. Sapuan korupsi tunggal peninjau
/// (16 Nov): ambang 0,70 memilihkan jenis keliru untuk kode yang tak ada di
/// daftar (`05X8` asli 0528 -> timbangan).
const _ambangPraPilihKodeSamar = 0.78;

/// Skor lapis KODE sendiri yang disyaratkan agar judul boleh menyepakati kode
/// samar menjadi pilih-awal. Serpihan hampir kosong (`05XX`, skor 0,56) tidak
/// lolos walau judulnya kuat.
const _skorMinKodeBerlapis = 0.60;

/// Denda bila revisi tercetak beda dari revisi yang dipegang server.
const _dendaRevisiBeda = 0.20;
const _skorTertinggi = 0.99;

/// Paling banyak kandidat per sisi yang ditampilkan saat kode dan judul
/// bertentangan.
const _maksKandidatPerSisi = 3;

// ---- Himpunan kode yang dikenal ---------------------------------------------

/// Satu kode formulir yang dikenal server beserta semua jenis yang
/// memakainya (0504: lima jenis; 0538.A dan 0538.B: dua kode terpisah).
class _Grup {
  _Grup(this.kodePokok, this.angka, this.akhiran);

  final String kodePokok;
  final String angka;
  final String? akhiran;
  final templat = <FormulirDikenal>[];
}

final _polaKodeServer = RegExp(
  r'SIDIK\s*-?\s*FM\s*-?\s*CAL\s*-?\s*(\d{4})(?:\s*\.\s*([A-Z])(?![A-Za-z0-9]))?',
  caseSensitive: false,
);

List<_Grup> _bangunGrup(List<FormulirDikenal> dikenal) {
  final peta = <String, _Grup>{};
  for (final d in dikenal) {
    final m = _polaKodeServer.firstMatch(d.kodeDokumen);
    if (m == null) continue;

    final angka = m.group(1)!;
    final akhiran = m.group(2)?.toUpperCase();
    final kode = 'SIDIK-FM-CAL-$angka${akhiran == null ? '' : '.$akhiran'}';
    (peta[kode] ??= _Grup(kode, angka, akhiran)).templat.add(d);
  }

  return peta.values.toList();
}

/// Revisi yang dipegang server, dari `SIDIK-FM-CAL-0511_Rev.5`.
String? _revisiServer(String kodeDokumen) => RegExp(
  r'_REV\.?\s*(\d+)',
  caseSensitive: false,
).firstMatch(kodeDokumen)?.group(1);

// ---- Lapis 1: kode formulir -------------------------------------------------

// Jangkar struktur kode: "CAL" dengan huruf kembar yang lazim (CA1, C4L, CAI).
final _jangkarCal = RegExp(r'C[A4][LI1|]');

// Kata "metode" di depan kode: itu kode metode (instruksi kerja), bukan
// formulir, apa pun awalan yang terbaca.
final _polaMetode = RegExp(r'METH?OD');

/// Karakter yang boleh muncul di nomor kode yang salah dibaca: angka, huruf
/// kembar angka, dan garis tegak yang mirip 1.
const _kelasNomor = r'[A-Z0-9|!]';

/// Kembar OCR di nomor: karakter terbaca -> angka yang mungkin, dengan biaya.
/// Sengaja SEMPIT: angka tidak pernah ditukar dengan angka lain.
const _kembarAngka = <String, (String, double)>{
  'O': ('0', 0.3),
  'Q': ('0', 0.4),
  'D': ('0', 0.5),
  'I': ('1', 0.3),
  'L': ('1', 0.4),
  '|': ('1', 0.3),
  '!': ('1', 0.4),
  'Z': ('2', 0.3),
  'S': ('5', 0.3),
  'G': ('6', 0.4),
  'B': ('8', 0.3),
  'M': ('5', 0.4),
};

/// Biaya satu karakter terbaca [r] menggantikan satu angka [k]; `null` =
/// tidak boleh. Angka mentah tidak pernah menggantikan angka lain.
double? _biayaGanti(String r, String k) {
  if (r == k) return 0;

  final kembar = _kembarAngka[r];
  if (kembar != null) return kembar.$1 == k ? kembar.$2 : null;

  // Huruf lain di posisi angka: gagal baca, bukan angka lain. Mahal.
  final adalahAngka = r.codeUnitAt(0) >= 0x30 && r.codeUnitAt(0) <= 0x39;

  return adalahAngka ? null : 0.9;
}

const _tak = 1000000.0;

/// Biaya jarak berbobot dari [raw] (nomor mentah hasil OCR) ke [angka] (nomor
/// kode yang dikenal), atau `null` bila lebih dari [_biayaKodeMaks].
///
///  - kembar huruf-angka: 0,3-0,5 (lihat [_kembarAngka]);
///  - angka `1` yang hilang: 0,5 (goresan tipis hilang atau menyatu);
///    angka `0` pertama yang terpotong: 0,5; angka lain yang hilang: 1;
///  - ekor yang terpotong bingkai: 0,8 per karakter. Bacaan harus memuat
///    paling sedikit semua angka kecuali satu: potongan lebih pendek bukan
///    bukti;
///  - karakter berlebih: hanya goresan tipis (I L | !), 0,5;
///  - `M` boleh dibaca dua `1`.
double? _biayaNomor(String raw, String angka) {
  if (raw.length < angka.length - 1) return null;

  var terbaik = _tak;
  for (final v in {raw, if (raw.contains('M')) raw.replaceAll('M', '11')}) {
    final b = _dp(v, angka);
    if (b < terbaik) terbaik = b;
  }

  return terbaik <= _biayaKodeMaks ? terbaik : null;
}

double _dp(String raw, String angka) {
  final n = raw.length;
  final m = angka.length;
  // d[i][j]: biaya mencocokkan raw[0..i) dengan angka[0..j).
  final d = List.generate(n + 1, (_) => List<double>.filled(m + 1, _tak));
  d[0][0] = 0;

  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      final sekarang = d[i][j];
      if (sekarang >= _tak) continue;

      if (i < n && j < m) {
        final b = _biayaGanti(raw[i], angka[j]);
        if (b != null) {
          d[i + 1][j + 1] = math.min(d[i + 1][j + 1], sekarang + b);
        }
      }
      if (j < m) {
        // angka[j] hilang dari bacaan.
        final b = angka[j] == '1' || (angka[j] == '0' && j == 0) ? 0.5 : 1.0;
        d[i][j + 1] = math.min(d[i][j + 1], sekarang + b);
      }
      if (i < n && '|!IL'.contains(raw[i])) {
        // goresan tipis berlebih.
        d[i + 1][j] = math.min(d[i + 1][j], sekarang + 0.5);
      }
    }
  }

  var hasil = d[n][m];
  if (n >= 3) {
    // Ekor terpotong bingkai: sisa angka dihitung 0,8 per karakter.
    for (var j = 1; j < m; j++) {
      hasil = math.min(hasil, d[n][j] + 0.8 * (m - j));
    }
  }

  return hasil;
}

enum _Kelas { fm, ikIm, tidakAda }

typedef _Dekat = ({_Grup grup, double biaya});

/// Satu bacaan kode di teks: apa yang tercetak, dan jenis mana yang cocok.
class _BacaKode {
  const _BacaKode({
    required this.mentah,
    required this.awalanBiaya,
    required this.bersih,
    required this.hasil,
    this.takDikenal,
  });

  /// Potongan teks cetak yang dibaca (huruf besar).
  final String mentah;

  /// Biaya awalan "SIDIK" yang terpotong/salah; 0 bila utuh.
  final double awalanBiaya;

  /// Awalan, kelas, dan nomor semuanya terbaca bersih (tanpa kembar huruf,
  /// tanpa potongan).
  final bool bersih;

  /// Kode yang dikenal dan cukup dekat; kosong = tidak cocok atau terlalu
  /// kabur.
  final List<_Dekat> hasil;

  /// Kode 05xx yang terbaca bersih tetapi tidak ada di daftar server.
  final String? takDikenal;

  bool get tepat => bersih && hasil.length == 1 && hasil.single.biaya == 0;
}

({
  _Kelas jenis,
  bool kelasBersih,
  bool awalanBersih,
  double awalanBiaya,
  int mulai,
})?
_bacaKelas(String pra) {
  final potong = pra.replaceFirst(RegExp(r'[^A-Z0-9]+$'), '');
  final mRun = RegExp(r'[A-Z0-9]+$').firstMatch(potong);
  if (mRun == null) return null;

  var run = mRun.group(0)!;
  var mulaiRun = mRun.start;
  var terpecah = false;

  // "F M" yang dipecah menjadi dua kata.
  if (run == 'M' || run == 'N') {
    final kiriPotong = potong
        .substring(0, mulaiRun)
        .replaceFirst(RegExp(r'[^A-Z0-9]+$'), '');
    if (RegExp(r'(?:^|[^A-Z0-9])F$').hasMatch(kiriPotong)) {
      run = 'F$run';
      mulaiRun = kiriPotong.length - 1;
      terpecah = true;
    }
  }

  _Kelas jenis;
  var bersih = false;
  var sisa = '';
  if (run.endsWith('FM') || run.endsWith('FN')) {
    jenis = _Kelas.fm;
    bersih = run.endsWith('FM') && !terpecah;
    sisa = run.substring(0, run.length - 2);
  } else if (run == 'SIDIK') {
    jenis = _Kelas.tidakAda;
  } else if (run.endsWith('IK') || run.endsWith('IM')) {
    jenis = _Kelas.ikIm;
  } else {
    jenis = _Kelas.tidakAda;
  }
  if (jenis != _Kelas.fm) {
    return (
      jenis: jenis,
      kelasBersih: false,
      awalanBersih: false,
      awalanBiaya: 0,
      mulai: mulaiRun,
    );
  }

  // Awalan "SIDIK": menempel pada kelas ("SIDIKFM") atau kata sebelumnya.
  var mulai = mulaiRun;
  if (sisa.isEmpty) {
    final kiri = potong
        .substring(0, mulaiRun)
        .replaceFirst(RegExp(r'[^A-Z0-9]+$'), '');
    final mKiri = RegExp(r'[A-Z0-9]+$').firstMatch(kiri);
    if (mKiri != null) {
      sisa = mKiri.group(0)!;
      mulai = mKiri.start;
    }
  }

  final awalanBersih = sisa.endsWith('SIDIK');
  final kanon = _kanon(sisa);
  final double awalanBiaya;
  if (awalanBersih) {
    awalanBiaya = 0;
  } else if (kanon.endsWith('SIDIK') ||
      (sisa.length >= 2 && 'SIDIK'.endsWith(kanon))) {
    awalanBiaya = 0.1;
  } else {
    awalanBiaya = 0.3;
  }

  return (
    jenis: jenis,
    kelasBersih: bersih,
    awalanBersih: awalanBersih,
    awalanBiaya: awalanBiaya,
    mulai: mulai,
  );
}

/// Nomor sesudah "CAL": run karakter nomor (boleh dipecah dua kata pendek),
/// lalu varian huruf `.A`/`.B`.
({String raw, String? akhiran, int akhir})? _bacaNomor(String sesudah) {
  String? raw;
  var akhir = 0;

  final m2 = RegExp(
    '^[^A-Z0-9|!]{0,4}($_kelasNomor{1,3}) ($_kelasNomor{1,3})(?!$_kelasNomor)',
  ).firstMatch(sesudah);
  if (m2 != null && (m2.group(1)!.length + m2.group(2)!.length) >= 3) {
    raw = '${m2.group(1)}${m2.group(2)}';
    akhir = m2.end;
  } else {
    final m1 = RegExp(
      '^[^A-Z0-9|!]{0,4}($_kelasNomor{2,7})(?!$_kelasNomor)',
    ).firstMatch(sesudah);
    if (m1 == null) return null;

    raw = m1.group(1);
    akhir = m1.end;
  }

  String? akhiran;
  final ms = RegExp(
    r'^\s*\.\s*([A-Z])(?![A-Z0-9])',
  ).firstMatch(sesudah.substring(akhir));
  if (ms != null) {
    akhiran = ms.group(1);
    akhir += ms.end;
  } else if (RegExp(r'^\d{4}[A-D]$').hasMatch(raw!)) {
    // "0538A": titik hilang.
    akhiran = raw.substring(4);
    raw = raw.substring(0, 4);
  }

  return (raw: raw!, akhiran: akhiran, akhir: akhir);
}

List<_Dekat> _cocokkan(String raw, String? akhiran, List<_Grup> grup) {
  final semua = <_Dekat>[];

  for (final g in grup) {
    final b = _biayaNomor(raw, g.angka);
    if (b == null) continue;

    // Varian huruf (.A/.B) harus sama persis. Kode tanpa varian TIDAK
    // dianggap ".A yang terpotong": 0538 polos adalah formulir lain.
    if (g.akhiran != akhiran) continue;

    semua.add((grup: g, biaya: b));
  }
  if (semua.isEmpty) return const [];

  final terbaik = semua.map((e) => e.biaya).reduce(math.min);

  return [
    for (final e in semua)
      if (e.biaya <= terbaik + _celahKodeDekat) e,
  ]..sort((a, b) => a.biaya.compareTo(b.biaya));
}

List<_BacaKode> _bacaKode(List<String> baris, List<_Grup> grup) {
  final hasil = <_BacaKode>[];

  for (final b in baris) {
    final u = b.toUpperCase();

    for (final jangkar in _jangkarCal.allMatches(u)) {
      final kelas = _bacaKelas(u.substring(0, jangkar.start));
      // IK/IM = kode instruksi kerja; tanpa kelas = bukan kode formulir.
      if (kelas == null || kelas.jenis != _Kelas.fm) continue;

      final konteks = u.substring(math.max(0, kelas.mulai - 32), kelas.mulai);
      if (_polaMetode.hasMatch(konteks)) continue;

      final nomor = _bacaNomor(u.substring(jangkar.end));
      if (nomor == null) continue;

      final dekat = _cocokkan(nomor.raw, nomor.akhiran, grup);
      final akhir = math.min(u.length, jangkar.end + nomor.akhir);
      final mentah = u.substring(kelas.mulai, akhir).trim();

      final bersihNomor = RegExp(r'^\d{4}$').hasMatch(nomor.raw);
      final bersih =
          kelas.kelasBersih &&
          kelas.awalanBersih &&
          u.substring(jangkar.start, jangkar.end) == 'CAL' &&
          bersihNomor;

      String? takDikenal;
      if (dekat.isEmpty && bersih && RegExp(r'^05\d{2}$').hasMatch(nomor.raw)) {
        takDikenal =
            'SIDIK-FM-CAL-${nomor.raw}'
            '${nomor.akhiran == null ? '' : '.${nomor.akhiran}'}';
      }

      hasil.add(
        _BacaKode(
          mentah: mentah.length > 32 ? mentah.substring(0, 32) : mentah,
          awalanBiaya: kelas.awalanBiaya,
          bersih: bersih,
          hasil: dekat,
          takDikenal: takDikenal,
        ),
      );
    }
  }

  return hasil;
}

// ---- Lapis 2: judul ---------------------------------------------------------

/// Huruf kembar OCR disamakan SATU sisi-ke-satu sisi (pola dan teks lewat
/// fungsi yang sama), jadi tidak ada yang "ditebak": hanya jarak edit yang
/// tidak menghitung I/l/1, O/0, S/5, B/8, Z/2 sebagai beda.
const _kembarJudul = {
  '0': 'O',
  '1': 'I',
  'L': 'I',
  '5': 'S',
  '8': 'B',
  '2': 'Z',
};

/// Satu karakter diganti satu karakter: indeks tetap sejajar dengan teks asal.
String _kanon(String s) => s.split('').map((c) => _kembarJudul[c] ?? c).join();

/// Huruf besar dan angka saja.
String _padat(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Kekeliruan huruf yang ditoleransi pada ekor judul menurut panjangnya.
/// Judul pendek ("Bath", "Oven") harus persis: sedikit kekeliruan sudah
/// membuatnya jadi kata lain.
int _toleransiJudul(int panjang) => math.min(3, panjang ~/ 6);

/// Jarak edit terkecil [pola] ke potongan [teks] mana pun (tepi bebas), dan
/// di mana potongan itu berakhir. `null` bila lebih dari [maks].
({int biaya, int akhir})? _cariSubstring(
  String pola,
  String teks, {
  required int maks,
}) {
  final m = pola.length;
  var prev = List<int>.generate(m + 1, (i) => i);
  var terbaik = 1 << 30;
  var akhir = -1;

  for (var j = 1; j <= teks.length; j++) {
    final cur = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= m; i++) {
      final ganti = prev[i - 1] + (pola[i - 1] == teks[j - 1] ? 0 : 1);
      cur[i] = math.min(ganti, math.min(prev[i] + 1, cur[i - 1] + 1));
    }
    if (cur[m] < terbaik) {
      terbaik = cur[m];
      akhir = j;
    }
    prev = cur;
  }

  return terbaik <= maks ? (biaya: terbaik, akhir: akhir) : null;
}

/// Jarak edit [pola] ke [teks] dengan ujung-ujung nyaris terikat: potongan
/// boleh mulai paling jauh [awal] karakter dari awal teks dan harus berakhir
/// paling jauh [sisa] karakter dari akhir teks. Judul "Buret" tidak boleh
/// menang atas "Buret Digital" hanya karena "Buret" ada di dalamnya.
int? _jarakTerikat(String pola, String teks, {int awal = 1, int sisa = 2}) {
  const tak = 1 << 20;
  final m = pola.length;
  final n = teks.length;
  var prev = List<int>.generate(m + 1, (i) => i);
  var terbaik = n <= sisa ? prev[m] : tak;

  for (var j = 1; j <= n; j++) {
    final cur = List<int>.filled(m + 1, 0);
    cur[0] = j <= awal ? 0 : tak;
    for (var i = 1; i <= m; i++) {
      final ganti = prev[i - 1] + (pola[i - 1] == teks[j - 1] ? 0 : 1);
      cur[i] = math.min(ganti, math.min(prev[i] + 1, cur[i - 1] + 1));
    }
    if (j >= n - sisa) terbaik = math.min(terbaik, cur[m]);
    prev = cur;
  }

  return terbaik >= tak ? null : terbaik;
}

typedef _HitJudul = ({FormulirDikenal formulir, int jarak, String terbaca});

final _polaLk = RegExp(r'LK\d');

/// Judul dibaca di dekat kata "WORKSHEET" (boleh rusak dua huruf): yang tercetak
/// sesudahnya, sampai "LK-285-IDN", dicocokkan ke ekor judul tiap jenis
/// ("pH Meter", "UV/VIS Spectrophotometer"). Judul yang pecah menjadi dua baris
/// (goresan di tengah kata) disambung dengan baris berikutnya.
List<_HitJudul> _bacaJudul(List<String> baris, List<FormulirDikenal> dikenal) {
  final ekor = [for (final d in dikenal) (d, _padat(namaPendekJudul(d.judul)))];
  final terbaik = <String, _HitJudul>{};

  String potongSampaiLk(String padat, int dari) {
    final bagian = padat.substring(dari);
    final lk = _polaLk.firstMatch(bagian);

    return lk == null ? bagian : bagian.substring(0, lk.start);
  }

  for (var i = 0; i < baris.length; i++) {
    final padat = _padat(baris[i]);
    final String asli;

    final jangkar = _cariSubstring('WORKSHEET', _kanon(padat), maks: 2);
    if (jangkar != null) {
      var sisa = potongSampaiLk(padat, jangkar.akhir);
      final adaLk = _polaLk.hasMatch(padat.substring(jangkar.akhir));
      // Judul pecah di ujung baris: sisanya ada di baris berikutnya.
      if (!adaLk && sisa.length < 4 && i + 1 < baris.length) {
        sisa += potongSampaiLk(_padat(baris[i + 1]), 0);
      }
      asli = sisa;
    } else if (i + 1 < baris.length) {
      // Kata "Worksheet" sendiri yang terbelah antar baris ("Worksh" / "et"):
      // cari jangkar pada sambungan, yang harus melintasi sambungannya.
      final sambung = padat + _padat(baris[i + 1]);
      final lintas = _cariSubstring('WORKSHEET', _kanon(sambung), maks: 2);
      if (lintas == null || lintas.akhir <= padat.length) continue;

      asli = potongSampaiLk(sambung, lintas.akhir);
    } else {
      continue;
    }
    final kanon = _kanon(asli);

    for (final (d, e) in ekor) {
      if (e.length < 3) continue;

      final jarak = _jarakTerikat(_kanon(e), kanon);
      if (jarak == null || jarak > _toleransiJudul(e.length)) continue;

      final lama = terbaik[d.templateId];
      if (lama == null || jarak < lama.jarak) {
        terbaik[d.templateId] = (
          formulir: d,
          jarak: jarak,
          terbaca: asli.length > 32 ? asli.substring(0, 32) : asli,
        );
      }
    }
  }
  if (terbaik.isEmpty) return const [];

  // Hanya yang terdekat: dua judul yang sama-sama "lumayan mirip" tidak
  // saling menggugurkan, tetapi yang lebih jauh dari yang terbaik dibuang.
  final minimum = terbaik.values.map((e) => e.jarak).reduce(math.min);

  return [
    for (final e in terbaik.values)
      if (e.jarak == minimum) e,
  ];
}

// ---- Lapis 3: revisi --------------------------------------------------------

final _polaRevisi = RegExp(
  r'\bR[E3]V(?:[I1L]S[E3]|[I1L]S[I1L]|[I1L]S[I1L]ON)?\b\s*[.:]?\s*:?\s*(\d{1,3})\b',
  caseSensitive: false,
);

/// "Revise : 5" di kaki formulir: hanya tiga baris terakhir yang dilihat, dan
/// yang paling bawah menang. "Rev." di badan lembar bukan revisi formulir.
String? _bacaRevisi(List<String> baris) {
  final terisi = [
    for (final b in baris)
      if (b.trim().isNotEmpty) b,
  ];
  final kaki = terisi.length > 3 ? terisi.sublist(terisi.length - 3) : terisi;

  String? terakhir;
  for (final b in kaki) {
    for (final m in _polaRevisi.allMatches(b)) {
      terakhir = m.group(1);
    }
  }

  return terakhir;
}

// ---- Penggabungan -----------------------------------------------------------

double _skorKode(double biaya, {required bool tepat}) => tepat
    ? _skorKodeTepat
    : math.max(_skorMinKode, _skorKodeTepat - _kemiringanKode * biaya);

double _skorJudul(int jarak) => jarak == 0
    ? _skorJudulTepat
    : math.max(_skorMinJudul, _skorJudulTepat - _kemiringanJudul * jarak);

class _Akum {
  _Akum(this.formulir);

  final FormulirDikenal formulir;
  double? skorKode;
  BuktiLapis? buktiKode;
  double? skorJudul;
  BuktiLapis? buktiJudul;
}

/// Menyimpulkan JENIS lembar dari teks seluruh halaman foto dengan bukti
/// berlapis (kode formulir, judul, revisi). Murni fungsi teks; tidak mengisi
/// apa pun dan tidak menavigasi. Lihat komentar berkas ini untuk aturannya.
///
/// `null` = tidak ada bukti sama sekali (pemanggil menampilkan daftar manual).
/// Selain itu hasilnya SELALU berisi [HasilJenisLembar.alasan] dan, bila ada
/// kandidat, [HasilJenisLembar.peringkat] dengan skor dan bukti per lapis.
/// [HasilJenisLembar.praPilihTemplateId] terisi HANYA bila bukti kuat, unik,
/// dan saling sepakat.
HasilJenisLembar? identifikasiLembar(
  String fullText, {
  required List<FormulirDikenal> dikenal,
}) {
  final teks = fullText.replaceAll(RegExp(r'[\r\n]+'), '\n');
  final baris = teks.split('\n');
  final grup = _bangunGrup(dikenal);

  final revisi = _bacaRevisi(baris);
  // Per baris, ditambah SELURUH halaman sebagai satu baris: kode yang terbelah
  // dua baris ("SIDIK-FM-CAL-" lalu "0511") tetap terbaca, seperti pada jalur
  // ketat yang memakai spasi lintas baris. Bacaan kembar tidak berbahaya:
  // jenis yang sama digabung menurut biaya terendahnya.
  final bacaan = _bacaKode([
    ...baris,
    if (baris.length > 1) baris.join(' '),
  ], grup);
  final judul = _bacaJudul(baris, dikenal);

  // ---- kode: bacaan bersih mengalahkan bacaan samar ------------------------
  final adaTepat = bacaan.any((b) => b.tepat);
  final dipakai = adaTepat
      ? [
          for (final b in bacaan)
            if (b.tepat) b,
        ]
      : bacaan;

  final kode = <_Grup, ({double biaya, bool tepat, String mentah})>{};
  for (final b in dipakai) {
    for (final h in b.hasil) {
      final total = h.biaya + b.awalanBiaya;
      final lama = kode[h.grup];
      if (lama == null || total < lama.biaya) {
        kode[h.grup] = (biaya: total, tepat: b.tepat, mentah: b.mentah);
      }
    }
  }
  if (kode.isNotEmpty) {
    final terbaik = kode.values.map((e) => e.biaya).reduce(math.min);
    kode.removeWhere((_, v) => v.biaya > terbaik + _celahKodeDekat);
  }
  if (kode.length > _maksGrupKodeDekat) {
    // Terlalu kabur untuk berdiri sendiri: hanya jenis yang juga ditunjuk
    // judul yang tersisa sebagai penguat.
    final idJudul = {for (final h in judul) h.formulir.templateId};
    kode.removeWhere(
      (g, _) => !g.templat.any((t) => idJudul.contains(t.templateId)),
    );
  }

  // Kode 05xx bersih yang tidak ada di daftar: tetap dilaporkan apa adanya.
  if (kode.isEmpty) {
    final asing = bacaan.map((b) => b.takDikenal).nonNulls.firstOrNull;
    if (asing != null) {
      return HasilJenisLembar.berlapis(
        sumber: SumberJenisLembar.kodeFormulir,
        alasan: AlasanPetunjuk.kodeTakDikenal,
        kodeFormulir: asing,
        revisiTerbaca: revisi,
      );
    }
  }

  // ---- kandidat per jenis ---------------------------------------------------
  final akum = <String, _Akum>{};

  for (final MapEntry(key: g, value: v) in kode.entries) {
    for (final t in g.templat) {
      final a = akum.putIfAbsent(t.templateId, () => _Akum(t));
      final skor = _skorKode(v.biaya, tepat: v.tepat);
      a.skorKode = skor;
      a.buktiKode = BuktiLapis(
        lapis: LapisBukti.kode,
        mutu: v.tepat ? MutuBukti.tepat : MutuBukti.samar,
        skor: skor,
        terbaca: v.mentah,
        cocok: g.kodePokok,
        biaya: v.biaya,
      );
    }
  }
  for (final h in judul) {
    final a = akum.putIfAbsent(h.formulir.templateId, () => _Akum(h.formulir));
    final skor = _skorJudul(h.jarak);
    a.skorJudul = skor;
    a.buktiJudul = BuktiLapis(
      lapis: LapisBukti.judul,
      mutu: h.jarak == 0 ? MutuBukti.tepat : MutuBukti.samar,
      skor: skor,
      terbaca: h.terbaca,
      cocok: h.formulir.judul,
      biaya: h.jarak.toDouble(),
    );
  }
  if (akum.isEmpty) return null;

  KandidatJenis susun(_Akum a) {
    var skor = 1 - (1 - (a.skorKode ?? 0.0)) * (1 - (a.skorJudul ?? 0.0));
    final bukti = <BuktiLapis>[?a.buktiKode, ?a.buktiJudul];

    // Revisi: pemeriksa, bukan bukti. Hanya bisa mengurangi.
    final dariServer = _revisiServer(a.formulir.kodeDokumen);
    if (revisi != null && dariServer != null) {
      final sama = revisi == dariServer;
      if (!sama) skor -= _dendaRevisiBeda;
      bukti.add(
        BuktiLapis(
          lapis: LapisBukti.revisi,
          mutu: sama ? MutuBukti.tepat : MutuBukti.bertentangan,
          skor: 0,
          terbaca: revisi,
          cocok: dariServer,
        ),
      );
    }

    return KandidatJenis(
      formulir: a.formulir,
      skor: math.max(0.0, math.min(skor, _skorTertinggi)),
      bukti: bukti,
    );
  }

  int urut(KandidatJenis a, KandidatJenis b) {
    final c = b.skor.compareTo(a.skor);

    return c != 0 ? c : a.formulir.templateId.compareTo(b.formulir.templateId);
  }

  final dariKode = {
    for (final e in akum.entries)
      if (e.value.skorKode != null) e.key: susun(e.value),
  };
  final dariJudul = {
    for (final e in akum.entries)
      if (e.value.skorJudul != null) e.key: susun(e.value),
  };

  final kodeTepat = kode.values.any((v) => v.tepat);
  final satuGrup = kode.length == 1;
  final kodeFormulir = satuGrup ? kode.keys.single.kodePokok : null;
  final sumber = kode.isEmpty
      ? SumberJenisLembar.judul
      : kodeTepat
      ? SumberJenisLembar.kodeFormulir
      : SumberJenisLembar.kodeSamar;

  HasilJenisLembar hasil(
    AlasanPetunjuk alasan,
    List<KandidatJenis> peringkat, {
    String? praPilih,
  }) => HasilJenisLembar.berlapis(
    sumber: sumber,
    alasan: alasan,
    kodeFormulir: kodeFormulir,
    revisiTerbaca: revisi,
    peringkat: peringkat,
    praPilihTemplateId: praPilih,
  );

  // 1. Kode dan judul sama-sama punya bukti.
  if (dariKode.isNotEmpty && dariJudul.isNotEmpty) {
    final irisan = [
      for (final id in dariKode.keys)
        if (dariJudul.containsKey(id)) susun(akum[id]!),
    ]..sort(urut);

    if (irisan.isEmpty) {
      final peringkat = [
        ...([...dariKode.values]..sort(urut)).take(_maksKandidatPerSisi),
        ...([...dariJudul.values]..sort(urut)).take(_maksKandidatPerSisi),
      ]..sort(urut);

      return hasil(AlasanPetunjuk.bertentangan, peringkat);
    }
    if (irisan.length > 1) {
      return hasil(
        kodeTepat && satuGrup
            ? AlasanPetunjuk.kodeBersama
            : AlasanPetunjuk.beberapaKandidat,
        irisan,
      );
    }
    // Judul yang kuat tidak boleh menyelamatkan serpihan kode yang kosong
    // (`05XX` cocok dengan hampir semua kode): lapis kode sendiri harus
    // cukup, bukan hanya skor gabungan.
    final idTunggal = irisan.single.formulir.templateId;
    final skorKode = akum[idTunggal]!.skorKode ?? 0.0;
    if (irisan.single.skor < _ambangPraPilih ||
        skorKode < _skorMinKodeBerlapis) {
      return hasil(AlasanPetunjuk.lemah, irisan);
    }

    return hasil(
      kodeTepat ? AlasanPetunjuk.praPilihKode : AlasanPetunjuk.praPilihBerlapis,
      irisan,
      praPilih: idTunggal,
    );
  }

  // 2. Hanya kode.
  if (dariKode.isNotEmpty) {
    final peringkat = [...dariKode.values]..sort(urut);

    if (peringkat.length > 1) {
      return hasil(
        kodeTepat && satuGrup
            ? AlasanPetunjuk.kodeBersama
            : AlasanPetunjuk.beberapaKandidat,
        peringkat,
      );
    }
    // Satu bukti saja: bacaan samar harus lebih kuat daripada bacaan bersih.
    final ambang = kodeTepat ? _ambangPraPilih : _ambangPraPilihKodeSamar;
    if (peringkat.single.skor < ambang) {
      return hasil(AlasanPetunjuk.lemah, peringkat);
    }

    return hasil(
      kodeTepat
          ? AlasanPetunjuk.praPilihKode
          : AlasanPetunjuk.praPilihKodeSamar,
      peringkat,
      praPilih: peringkat.single.formulir.templateId,
    );
  }

  // 3. Hanya judul: usulan, tidak pernah dipilih-awal.
  return hasil(AlasanPetunjuk.judulSaja, [...dariJudul.values]..sort(urut));
}
