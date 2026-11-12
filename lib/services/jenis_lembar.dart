import '../models/worksheet_template.dart';
import 'pembaca_halaman.dart' show TeksTerbaca;
import 'registrasi_jangkar_teks.dart' show normalisasiKodeDokumen;

/// PETUNJUK jenis lembar dari kode formulir tercetak (`SIDIK-FM-CAL-05xx`).
///
/// Aturan keras (pemilik, 12 Nov 2026):
///  - Hasil di sini HANYA mengisi usulan awal pilihan jenis lembar. Tidak
///    pernah mengunci, tidak pernah menavigasi sendiri, tidak mengisi sel.
///  - Tombol "pilih jenis lembar manual" SELALU tampil (lihat
///    `PilihJenisLembarSheet`), juga saat kode terdeteksi.
///  - Kode yang dipakai beberapa profil menurut desain server (0504, 0507,
///    0513, 0514, 0515, 0529 ...) TIDAK diakali: semua profil yang cocok
///    ditampilkan dan teknisi memilih.
///  - Pemetaan kode -> profil datang dari server (`GET /worksheet-templates`),
///    tidak ditulis di aplikasi: alat baru ikut dikenali tanpa APK baru.

/// Dari mana jenis lembar disimpulkan.
enum SumberJenisLembar {
  /// Kode formulir tercetak (`SIDIK-FM-CAL-0509`) terbaca dan cocok persis
  /// dengan satu template yang dikenal server. Satu-satunya sumber yang boleh
  /// dipakai memilih profil lembar.
  kodeFormulir,

  /// Kode tidak terbaca; judul tercetak ("... Work Sheet - pH Meter")
  /// cocok dengan judul tepat satu template. HANYA petunjuk untuk teknisi:
  /// tidak pernah dipakai memilih profil atau mengisi apa pun.
  judul,
}

/// Hasil [detectWorksheetType].
class HasilJenisLembar {
  const HasilJenisLembar({
    required this.sumber,
    this.kodeFormulir,
    this.revisiTerbaca,
    this.kandidat = const [],
    this.kodeLain = const [],
  });

  final SumberJenisLembar sumber;

  /// Kode formulir yang terbaca, dinormalkan (`SIDIK-FM-CAL-0508.A`).
  final String? kodeFormulir;

  /// Revisi yang tercetak di dekat kode ("Revise : 4"), bila ada.
  final String? revisiTerbaca;

  /// Template server yang cocok dengan kode/judul ini. Satu kode formulir
  /// BISA dipakai beberapa profil (0504: bath, furnace, inkubator, oven,
  /// refrigerator; 0507: tiga alat tekanan), jadi ini daftar, bukan satu
  /// nilai. Kosong bila server tidak mengenal kodenya (belum dipetakan).
  final List<FormulirDikenal> kandidat;

  /// KODE PROFIL server (`ph_meter`, ...) — kunci yang sama dengan
  /// `GET /worksheet-templates/{kode}` dan `profilLembarKerjaUntuk()`. Hanya
  /// terisi bila [kandidat] TEPAT satu; selain itu `null` (kosong atau
  /// ambigu) dan pemanggil tidak boleh memilihkan. Pun saat terisi, ini
  /// usulan awal: teknisi tetap bisa mengganti.
  String? get templateId =>
      kandidat.length == 1 ? kandidat.single.templateId : null;

  /// Judul template server bila [kandidat] tepat satu.
  String? get judul => kandidat.length == 1 ? kandidat.single.judul : null;

  /// Kode FM lain yang ikut terbaca di halaman yang sama. Lebih dari satu
  /// berarti foto memuat beberapa formulir atau bacaan yang kacau; pemanggil
  /// tidak boleh memilih salah satunya diam-diam.
  final List<String> kodeLain;

  /// Tepat SATU profil yang cocok dan tidak ada kode FM lain di halaman yang
  /// sama. Cukup untuk MEMILIH-AWAL satu baris di daftar usulan; BUKAN izin
  /// melewati pilihan teknisi (nama lama `pastiProfil` dihapus karena
  /// menyiratkan kepastian yang tidak ada).
  bool get satuKandidat =>
      sumber == SumberJenisLembar.kodeFormulir &&
      templateId != null &&
      kodeLain.isEmpty;
}

/// Satu formulir yang dikenal server, bahan [detectWorksheetType]. Diambil
/// dari `GET /worksheet-templates` (dan/atau template asli), BUKAN ditulis di
/// aplikasi: alat baru ikut dikenali begitu server memetakannya.
typedef FormulirDikenal = ({
  String templateId,
  String kodeDokumen,
  String judul,
});

FormulirDikenal formulirDikenalDari(WorksheetTemplate t) =>
    (templateId: t.templateId, kodeDokumen: t.kodeDokumen, judul: t.judul);

// `SIDIK-FM-CAL-0508.A`: awalan, nomor deret 05xx, varian huruf opsional.
// Spasi dan strip yang dipecah/ditempel OCR ditoleransi; huruf TIDAK ditebak
// (`O5O9` bukan `0509`) — aturan yang sama dengan `cariKodeDokumen`. Hanya
// deret 05xx (lembar kerja): `SIDIK-FM-CAL-2403` (formulir sertifikat) bukan
// jenis lembar dan tidak dihitung sebagai "kode lain".
final _polaKode = RegExp(
  r'SIDIK\s*-?\s*FM\s*-?\s*CAL\s*-?\s*(05\d{2})(?!\d)(?:\s*\.\s*([A-Z])(?![A-Za-z0-9]))?',
  caseSensitive: false,
);

// "Revise : 4", "Rev: 3", "Rev. 0", "Rev : 3" di dekat kode.
final _polaRevisi = RegExp(
  r'\bRev(?:ise|isi|ision)?\b\s*[.:]?\s*:?\s*(\d{1,3})\b',
  caseSensitive: false,
);

/// Judul lembar: bagian sesudah "Work Sheet -"/"Worksheet -" sampai "LK-".
final _polaJudul = RegExp(
  r'WORK\s*SHEET\s*[-:]?\s*(.+?)(?:\s+LK-\d+|$)',
  caseSensitive: false,
  multiLine: true,
);

/// `kodeDokumen` server bisa berbentuk `SIDIK-FM-CAL-0509`,
/// `SIDIK-FM-CAL-0509_Rev.4`, atau varian `.A`. Ambil bagian kodenya saja.
String? _kodePokok(String kodeDokumen) {
  final m = _polaKode.firstMatch(kodeDokumen);
  if (m == null) return null;

  return 'SIDIK-FM-CAL-${m.group(1)}${m.group(2) == null ? '' : '.${m.group(2)!.toUpperCase()}'}';
}

String _normJudul(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');

/// Menyimpulkan JENIS lembar dari teks seluruh halaman foto (hasil ML Kit
/// sehalaman). Murni fungsi teks, tidak menyentuh kamera, jaringan, atau
/// state — dan tidak mengisi apa pun.
///
/// 1. **Kode formulir** (`SIDIK-FM-CAL-xxxx[.X]`): pengenal utama, tercetak di
///    kaki ke-41 formulir. Dicocokkan PERSIS (varian `.A` ≠ polos) ke
///    [dikenal]; pemetaan ke profil mengikuti `templateId` server.
/// 2. **Judul** ("PT. SIDIK Calibration Work Sheet - pH Meter"): hanya bila
///    kode tidak ada sama sekali; cocok bila judul itu sama dengan judul
///    TEPAT SATU template. Hasilnya [SumberJenisLembar.judul] dan
///    [HasilJenisLembar.satuKandidat] false.
///
/// `null` = tidak ada petunjuk sama sekali.
HasilJenisLembar? detectWorksheetType(
  String fullText, {
  required List<FormulirDikenal> dikenal,
}) {
  final teks = fullText.replaceAll(RegExp(r'[\r\n]+'), '\n');

  // ---- 1. kode formulir ------------------------------------------------
  final kode = <String>[];
  for (final m in _polaKode.allMatches(teks)) {
    final k = normalisasiKodeDokumen(
      'SIDIK-FM-CAL-${m.group(1)}'
      '${m.group(2) == null ? '' : '.${m.group(2)!.toUpperCase()}'}',
    );
    if (!kode.contains(k)) kode.add(k);
  }

  if (kode.isNotEmpty) {
    // Mana yang dikenal server? Kode pertama yang dikenal jadi jawaban; kode
    // lain di halaman yang sama dilaporkan di [kodeLain] (ambigu).
    List<FormulirDikenal> cocokUntuk(String k) => [
      for (final d in dikenal)
        if (_kodePokok(d.kodeDokumen) case final pokok?
            when normalisasiKodeDokumen(pokok) == k)
          d,
    ];

    final utama = kode.firstWhere(
      (k) => cocokUntuk(k).isNotEmpty,
      orElse: () => kode.first,
    );
    final lain = [
      for (final k in kode)
        if (k != utama) k,
    ];

    return HasilJenisLembar(
      sumber: SumberJenisLembar.kodeFormulir,
      kodeFormulir: utama,
      revisiTerbaca: _revisiDekat(teks, utama),
      kandidat: cocokUntuk(utama),
      kodeLain: lain,
    );
  }

  // ---- 2. judul (petunjuk saja) ----------------------------------------
  for (final m in _polaJudul.allMatches(teks)) {
    final calon = _normJudul(m.group(1) ?? '');
    if (calon.length < 3) continue;

    final kena = [
      for (final d in dikenal)
        if (_judulCocok(calon, d.judul)) d,
    ];
    if (kena.length == 1) {
      return HasilJenisLembar(sumber: SumberJenisLembar.judul, kandidat: kena);
    }
  }

  return null;
}

/// "Calibration Worksheet - pH Meter" -> "pH Meter".
String namaPendekJudul(String judul) =>
    judul.split(RegExp(r'\s[-–]\s')).last.trim();

/// Nama pendek jenis lembar untuk pesan ke teknisi: bagian judul server
/// sesudah strip ("Calibration Worksheet - pH Meter" -> "pH Meter"), tanpa
/// duplikat, paling banyak tiga. `null` bila tidak ada kandidat.
String? namaJenisLembar(HasilJenisLembar hasil) {
  final nama = <String>{
    for (final k in hasil.kandidat)
      if (namaPendekJudul(k.judul) case final n when n.isNotEmpty) n,
  }.toList();
  if (nama.isEmpty) return null;

  return nama.length <= 3
      ? nama.join(' / ')
      : '${nama.take(3).join(' / ')} / ...';
}

/// Judul tercetak lawan judul server. Server menulis "Calibration Worksheet -
/// pH Meter"; yang dicocokkan bagian sesudah strip, atau seluruh judul.
bool _judulCocok(String calon, String judulServer) {
  final bagian = judulServer.split(RegExp(r'\s[-–]\s')).last;
  final a = _normJudul(bagian);
  final b = _normJudul(judulServer);

  return a.isNotEmpty && (a == calon || b == calon);
}

/// Revisi yang tercetak di baris/dekat kode (kaki: "Page 1 of 1 Revise : 4
/// SIDIK-FM-CAL-0509"). Dicari di jendela 40 karakter sebelum kode.
String? _revisiDekat(String teks, String kodeNormal) {
  for (final m in _polaKode.allMatches(teks)) {
    final k = normalisasiKodeDokumen(
      'SIDIK-FM-CAL-${m.group(1)}'
      '${m.group(2) == null ? '' : '.${m.group(2)!.toUpperCase()}'}',
    );
    if (k != kodeNormal) continue;

    final awal = m.start - 40 < 0 ? 0 : m.start - 40;
    final jendela = teks.substring(awal, m.start);
    final r = _polaRevisi.allMatches(jendela);

    return r.isEmpty ? null : r.last.group(1);
  }

  return null;
}

/// Teks seluruh halaman dari hasil ML Kit sehalaman, urut baca (atas ke bawah,
/// kiri ke kanan; elemen sebaris dikelompokkan lewat toleransi setengah
/// tinggi), satu baris per kelompok. Bahan [detectWorksheetType].
String teksHalaman(List<TeksTerbaca> terbaca) {
  final urut = [...terbaca]
    ..sort((a, b) => a.kotak.center.dy.compareTo(b.kotak.center.dy));
  final baris = <List<TeksTerbaca>>[];

  for (final t in urut) {
    if (baris.isNotEmpty) {
      final acuan = baris.last.first.kotak;
      final tol = acuan.height / 2;
      if ((t.kotak.center.dy - acuan.center.dy).abs() <= tol) {
        baris.last.add(t);
        continue;
      }
    }
    baris.add([t]);
  }

  return [
    for (final b in baris)
      (b..sort((a, c) => a.kotak.left.compareTo(c.kotak.left)))
          .map((e) => e.teks)
          .join(' '),
  ].join('\n');
}
