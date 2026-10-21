import 'package:flutter/painting.dart' show Color;
import 'package:sidik_calibration/providers/dashboard_provider.dart'
    show TokenHilangException;
import 'package:sidik_calibration/services/auth_service.dart';

import '../widget/grid/grid_sel.dart';
import 'workbook_model.dart';

/// Simulasi "seperti Excel" (Tahap C): edit sel di Studio → server menghitung
/// ulang SELURUH workbook (`POST /hitung`) → hasilnya ditimpakan di atas grid.
/// TIDAK ADA yang disimpan: menutup layar = edit hilang.
///
/// Studio tetap tidak menghitung apa pun. Satu-satunya tafsiran isi di klien
/// adalah TAMPILAN SEMENTARA sel yang editnya belum dijawab server
/// ([selSementara], teks abu) — begitu jawaban tiba, yang tampil adalah sel
/// buatan server.

/// Satu sel yang diedit: lembar + alamat (basis-1).
typedef KunciEditSel = ({int lembarId, int baris, int kolom});

KunciEditSel kunciEdit(int lembarId, AlamatSel a) =>
    (lembarId: lembarId, baris: a.baris, kolom: a.kolom);

/// Satu perubahan di riwayat urung/ulang. `null` = sel itu tanpa edit
/// (isi snapshot impor).
typedef PerubahanEdit = ({
  KunciEditSel kunci,
  String? sebelum,
  String? sesudah,
});

/// Warna teks sel yang editnya BELUM dikonfirmasi server (sedang/gagal
/// dihitung). Grid tetap menjaga kontrasnya ([warnaTeksAman]).
const Color warnaTeksSementara = Color(0xFF808080);

/// Kenapa `/hitung` gagal — layar memilih pesannya.
///
/// Server punya DUA 409 (`GagalHitung` API): `kode` yang membedakannya, jadi
/// [GalatSimulasi.dari] membaca `kode` lebih dulu, baru status.
enum JenisGalatSimulasi {
  /// 409 `berkas_asli_tidak_ada` — workbook tanpa berkas Excel asli (CSV).
  berkasAsliTidakAda,

  /// 409 `perlu_sandi` — `.xlsm` bersandi yang model hitungnya belum
  /// disiapkan di server. Bukan salah edit dan tidak sembuh dengan "coba
  /// lagi": admin menjalankan `php artisan studio:siapkan-hitung <id>` (sandi
  /// diminta) atau mengimpor ulang berkasnya dengan sandi.
  perluSandi,

  /// 422 — alamat/lembar/fungsi terlarang, atau terlalu banyak edit.
  ditolak,

  /// 504 `hitung_terlalu_lama` — server memotong di 20 s.
  terlaluLama,

  /// 429 — jatah `studio-hitung` (30/menit/pengguna) habis. Simulasi
  /// menahan kiriman otomatis sampai "Coba lagi" (`SimulasiWorkbook`).
  terlaluSering,

  /// 403 — peran tidak boleh menjalankan simulasi.
  dilarang,

  /// Jaringan, 5xx, token hilang, dan lainnya.
  lain,
}

class GalatSimulasi {
  const GalatSimulasi({required this.jenis, required this.pesan, this.status});

  final JenisGalatSimulasi jenis;

  /// Pesan server (atau pesan koneksi `ApiClient`) apa adanya.
  final String pesan;
  final int? status;

  /// "Coba lagi" masuk akal: kiriman yang sama bisa berhasil nanti.
  bool get bisaDiulang => switch (jenis) {
    JenisGalatSimulasi.terlaluLama ||
    JenisGalatSimulasi.terlaluSering ||
    JenisGalatSimulasi.lain => true,
    _ => false,
  };

  factory GalatSimulasi.dari(Object e) {
    if (e is ApiException) {
      final body = e.body;
      // `kode` dulu: status saja tidak cukup (dua 409 berbeda obatnya).
      // 409 tanpa `kode` yang dikenal = `lain` dengan pesan server apa
      // adanya — BUKAN ditebak "tidak punya berkas asli".
      final jenis = switch (body['kode']) {
        'perlu_sandi' => JenisGalatSimulasi.perluSandi,
        'berkas_asli_tidak_ada' => JenisGalatSimulasi.berkasAsliTidakAda,
        'hitung_terlalu_lama' => JenisGalatSimulasi.terlaluLama,
        'edit_tidak_valid' => JenisGalatSimulasi.ditolak,
        _ => switch (e.status) {
          422 => JenisGalatSimulasi.ditolak,
          504 => JenisGalatSimulasi.terlaluLama,
          429 => JenisGalatSimulasi.terlaluSering,
          403 => JenisGalatSimulasi.dilarang,
          _ => JenisGalatSimulasi.lain,
        },
      };
      return GalatSimulasi(
        jenis: jenis,
        pesan: _pesanPertama(body) ?? e.message,
        status: e.status,
      );
    }
    if (e is AuthException) {
      return GalatSimulasi(jenis: JenisGalatSimulasi.lain, pesan: e.message);
    }
    if (e is TokenHilangException) {
      return const GalatSimulasi(
        jenis: JenisGalatSimulasi.lain,
        pesan: 'Sesi tidak ditemukan. Masuk lagi.',
      );
    }
    return GalatSimulasi(jenis: JenisGalatSimulasi.lain, pesan: '$e');
  }

  /// 422 Laravel: pesan validasi pertama lebih jelas dari `message` umum.
  static String? _pesanPertama(Map<String, dynamic> body) {
    final galat = body['errors'];
    if (galat is Map) {
      for (final v in galat.values) {
        if (v is List && v.isNotEmpty && v.first is String) {
          return v.first as String;
        }
        if (v is String && v.isNotEmpty) return v;
      }
    }
    final m = body['message'];
    return m is String && m.isNotEmpty ? m : null;
  }
}

/// Lapisan simulasi SATU lembar di atas halaman grid.
///
/// - [sel]: sel jawaban server terakhir yang berhasil (menimpa sel snapshot).
/// - [sementara]: sel yang editnya belum terjawab (isi edit, atau `null` =
///   editnya DIURUNGKAN — kembali ke sel snapshot sampai server menjawab).
/// - [galat]: galat mesin hitung per sel (`galat[]`).
///
/// Dibuat ulang hanya saat edit/jawaban berubah — identitasnya dipakai sel
/// grid untuk tahu kapan membangun ulang.
class OverlayLembar {
  OverlayLembar({
    this.sel = const {},
    this.sementara = const {},
    this.galat = const {},
  });

  static final tanpaSimulasi = OverlayLembar();

  /// `kunciSel` → sel jawaban server.
  final Map<int, SelWorkbook> sel;

  /// `kunciSel` → isi edit yang belum dijawab (`null` = diurungkan).
  final Map<int, String?> sementara;

  /// `kunciSel` → pesan galat mesin hitung.
  final Map<int, String> galat;

  bool get kosong => sel.isEmpty && sementara.isEmpty;

  late final ({int baris, int kolom}) _batas = () {
    var b = 0;
    var k = 0;
    for (final s in sel.values) {
      if (s.alamat.baris > b) b = s.alamat.baris;
      if (s.alamat.kolom > k) k = s.alamat.kolom;
    }
    for (final kunci in sementara.keys) {
      final bb = kunci ~/ (kolomMaksExcel + 1);
      final kk = kunci % (kolomMaksExcel + 1);
      if (bb > b) b = bb;
      if (kk > k) k = kk;
    }
    return (baris: b, kolom: k);
  }();

  /// Baris/kolom terjauh yang disentuh simulasi — grid memperluas rentang
  /// terpakainya sampai sini (edit di luar rentang data tetap terlihat).
  int get barisMaks => _batas.baris;
  int get kolomMaks => _batas.kolom;

  /// Sel jawaban server di alamat ini; `null` bila tidak ada ATAU editnya
  /// sedang diurungkan (yang berlaku sel snapshot).
  SelWorkbook? pada(int baris, int kolom) {
    final kunci = kunciSel(baris, kolom);
    if (sementara.containsKey(kunci) && sementara[kunci] == null) return null;
    return sel[kunci];
  }

  final _grid = <int, SelGrid>{};
  final _gridSementara = <int, (SelGrid, SelGrid)>{};
  bool? _gridGeneral;

  /// Sel grid di ([baris], [kolom]) dengan simulasi di atas [dasar] (sel
  /// snapshot; `null` = halamannya belum termuat).
  SelGrid? selGrid(
    int baris,
    int kolom,
    SelGrid? dasar, {
    bool tiruGeneral = false,
  }) {
    final kunci = kunciSel(baris, kolom);
    final s = sel[kunci];
    final adaSementara = sementara.containsKey(kunci);
    if (s == null && !adaSementara) return dasar;
    if (_gridGeneral != tiruGeneral) {
      _grid.clear();
      _gridSementara.clear();
      _gridGeneral = tiruGeneral;
    }
    if (!adaSementara) {
      return _grid[kunci] ??= s!.keGrid(tiruGeneral: tiruGeneral);
    }
    final isi = sementara[kunci];
    final alas = isi == null || s == null
        ? dasar
        : (_grid[kunci] ??= s.keGrid(tiruGeneral: tiruGeneral));
    if (alas == null) return null;
    final ada = _gridSementara[kunci];
    if (ada != null && identical(ada.$1, alas)) return ada.$2;
    final hasil = isi == null
        ? alas.salin(warnaTeks: warnaTeksSementara)
        : selSementara(alas, isi);
    _gridSementara[kunci] = (alas, hasil);
    return hasil;
  }
}

final _polaAngkaKetikan = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// Tampilan SEMENTARA sel yang editnya belum dijawab server: gaya [alas]
/// tetap, isinya apa yang diketik (teks abu). Bukan hasil hitung — konstanta
/// ditampilkan seperti diketik (rata kanan bila berbentuk angka), rumus
/// menampilkan nilai lama sampai server menjawab.
SelGrid selSementara(SelGrid alas, String isi) {
  if (isi.isEmpty) {
    return alas.salin(
      teks: '',
      rumus: null,
      jenis: JenisSelGrid.kosong,
      nilai: null,
      general: false,
      warnaTeks: warnaTeksSementara,
    );
  }
  if (isi.startsWith('=')) {
    return alas.salin(rumus: isi, warnaTeks: warnaTeksSementara);
  }
  final t = isi.trim();
  final jenis = _polaAngkaKetikan.hasMatch(t)
      ? JenisSelGrid.angka
      : (const {'TRUE', 'FALSE'}.contains(t.toUpperCase())
            ? JenisSelGrid.logika
            : JenisSelGrid.teks);
  return alas.salin(
    teks: jenis == JenisSelGrid.teks
        ? isi
        : (jenis == JenisSelGrid.logika ? t.toUpperCase() : t),
    rumus: null,
    jenis: jenis,
    nilai: null,
    general: false,
    warnaTeks: warnaTeksSementara,
  );
}

/// Susun [OverlayLembar] per lembar dari jawaban terakhir [hasil] (dihitung
/// dengan edit [terhitung]) dan edit yang berlaku sekarang [edit].
Map<int, OverlayLembar> susunOverlay(
  HasilHitung? hasil,
  Map<KunciEditSel, String> edit,
  Map<KunciEditSel, String>? terhitung,
) {
  final sel = <int, Map<int, SelWorkbook>>{};
  final sementara = <int, Map<int, String?>>{};
  final galat = <int, Map<int, String>>{};
  if (hasil != null) {
    for (final e in hasil.sel.entries) {
      final peta = sel[e.key] ??= {};
      for (final s in e.value) {
        peta[kunciSel(s.alamat.baris, s.alamat.kolom)] = s;
      }
    }
    for (final g in hasil.galat) {
      final a = AlamatSel.urai(g.a);
      if (a == null) continue;
      (galat[g.lembarId] ??= {})[kunciSel(a.baris, a.kolom)] = g.pesan;
    }
  }
  final lama = terhitung ?? const {};
  for (final k in {...edit.keys, ...lama.keys}) {
    final isi = edit[k];
    if (isi == lama[k] && lama.containsKey(k) == edit.containsKey(k)) {
      continue;
    }
    (sementara[k.lembarId] ??= {})[kunciSel(k.baris, k.kolom)] = isi;
  }
  return {
    for (final id in {...sel.keys, ...sementara.keys, ...galat.keys})
      id: OverlayLembar(
        sel: sel[id] ?? const {},
        sementara: sementara[id] ?? const {},
        galat: galat[id] ?? const {},
      ),
  };
}

/// Keadaan simulasi satu workbook ([SimulasiWorkbook]).
class KeadaanSimulasi {
  const KeadaanSimulasi({
    this.edit = const {},
    this.hasil,
    this.overlay = const {},
    this.menghitung = false,
    this.galat,
    this.bisaUrungkan = false,
    this.bisaUlangi = false,
  });

  static const awal = KeadaanSimulasi();

  /// SEMUA edit yang berlaku (urut edit) — dikirim utuh tiap hitung.
  final Map<KunciEditSel, String> edit;

  /// Jawaban server terakhir yang berhasil (`null` = belum/tanpa edit).
  final HasilHitung? hasil;
  final Map<int, OverlayLembar> overlay;

  /// Ada kiriman `/hitung` yang sedang ditunggu (atau dijadwalkan).
  final bool menghitung;

  /// Kiriman TERAKHIR gagal.
  final GalatSimulasi? galat;
  final bool bisaUrungkan;
  final bool bisaUlangi;

  bool get adaEdit => edit.isNotEmpty;

  String? isiEdit(int lembarId, AlamatSel a) => edit[kunciEdit(lembarId, a)];

  OverlayLembar overlayUntuk(int lembarId) =>
      overlay[lembarId] ?? OverlayLembar.tanpaSimulasi;

  int get jumlahGalatHitung => hasil?.galat.length ?? 0;
}
