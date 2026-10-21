import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../l10n/studio_l10n.dart';
import '../../tema/font_studio.dart';
import '../../tema/warna_studio.dart';
import 'alamat_sel.dart';
import 'format_general.dart';
import 'luber_teks.dart';

export 'alamat_sel.dart';
export 'format_general.dart';
export 'luber_teks.dart';

part 'grid_sel_geometri.dart';
part 'grid_sel_sel.dart';

// ═══════════════════════════════════════════════════════════════ satuan Excel

/// Lebar kolom Excel → dp.
///
/// Excel menyimpan `<col width>` dalam "karakter": kelipatan lebar digit `0`
/// font Normal (Calibri 11 = 7 px pada 96 dpi, "maximum digit width"/MDW),
/// SUDAH termasuk padding 5 px. ECMA-376 Bagian 1 §18.3.1.13:
///
/// ```text
/// px = Truncate(((256·w + Truncate(128/MDW)) / 256) · MDW)
///    = floor(7·w + 18·7/256)          (MDW = 7)
///    = floor(7·w + 0,4921875)
/// ```
///
/// Contoh: lebar bawaan 8,43 karakter tersimpan sebagai `9.140625` → 64 px,
/// persis kolom bawaan Excel. 1 dp di Studio = 1 px Excel pada zoom 100 %.
/// Lebar ≤ 0 = kolom tersembunyi. `lebar_kolom_bawaan` lembar memakai rumus
/// yang sama (satuannya sama dengan `<col width>`).
double lebarKolomExcelKeDp(double lebar) =>
    lebar <= 0 ? 0 : (lebar * 7 + 0.4921875).floorToDouble();

/// Tinggi baris Excel (poin, `<row ht>`) → dp: 1 pt = 96/72 px. Bawaan 15 pt
/// = 20 dp.
double tinggiBarisExcelKeDp(double poin) => poin <= 0 ? 0 : poin * 96 / 72;

/// Lebar kolom bawaan Excel (8,43 karakter) dalam dp.
const double lebarKolomBawaanDp = 64;

/// Tinggi baris bawaan Excel (15 pt) dalam dp.
const double tinggiBarisBawaanDp = 20;

/// Ukuran font sel bawaan Excel (Calibri 11 pt).
const double ukuranFontBawaanPt = 11;

/// Ukuran font Excel (pt) → ukuran font sel grid (dp) pada zoom 100 %.
///
/// Grid memakai Inter (font antarmuka Studio), bukan Calibri: Calibri tidak
/// ada di tablet Android, dan grid harus tampil sama di dua platform. Skala
/// dipilih supaya MUATAN kolom sama dengan Excel, bukan supaya hurufnya sama
/// tinggi: digit Inter pada 11 dp lebarnya 6,94 dp (7,13 dp dengan angka
/// tabular) — diukur di test dengan font yang dibundel — praktis sama dengan
/// MDW Calibri 11 pt = 7 px yang menjadi satuan lebar kolom Excel. Jadi
/// 1 pt Excel = 1 dp: angka 8 digit muat di kolom bawaan 64 dp, 9 digit
/// tidak (jadi `####`), sama seperti di Excel.
double ukuranFontExcelKeDp(double poin) => poin;

/// Font Excel berlebar tetap → grid memakai font mono Studio untuknya.
bool fontMonospace(String? nama) {
  final n = nama?.toLowerCase();
  if (n == null) return false;
  return n.contains('courier') ||
      n.contains('consolas') ||
      n.contains('mono') ||
      n.contains('lucida console');
}

/// Zoom berikutnya dari [zoom] satu langkah ([arah] +1/−1) — kelipatan 10 %
/// seperti tombol zoom Excel, dijepit [KendaliGridSel.zoomMin]..
/// [KendaliGridSel.zoomMaks].
double langkahZoom(double zoom, int arah) {
  final sepersepuluh = (zoom * 10).round() + arah;
  return (sepersepuluh / 10).clamp(
    KendaliGridSel.zoomMin,
    KendaliGridSel.zoomMaks,
  );
}

// ═══════════════════════════════════════════════════════════════ model grid

/// Jenis isi sel — menentukan perataan bawaan & luberan, seperti format
/// "General" Excel: angka kanan (tidak meluber, `####` bila tak muat), teks
/// kiri (meluber), logika & galat tengah.
enum JenisSelGrid { kosong, angka, teks, logika, galat }

/// Perataan vertikal sel. Bawaan Excel = [bawah].
enum RataVertikal { atas, tengah, bawah }

/// Gaya garis tepi Excel (`<border style>`), dikelompokkan menurut cara
/// menggambarnya. [bobot] menentukan pemenang bila dua sel bertetangga
/// sama-sama memberi garis di sisi yang sama (yang lebih tebal menang).
enum JenisGaris {
  tanpa(0),
  rambut(1),
  titik(2),
  putus(3),
  tipis(4),
  sedangPutus(5),
  sedang(6),
  ganda(7),
  tebal(8);

  const JenisGaris(this.bobot);

  final int bobot;

  bool get ada => this != tanpa;

  /// Nama gaya Excel/PhpSpreadsheet (`thin`, `medium`, `dashed`, …) →
  /// jenis. `true` / teks lain yang tidak dikenal = [tipis] (ada garis,
  /// bentuknya tidak diketahui); `null`/`false`/`none`/kosong = [tanpa].
  static JenisGaris dari(Object? v) {
    if (v == null || v == false) return tanpa;
    if (v == true) return tipis;
    if (v is! String) return tipis;
    return switch (v.trim()) {
      '' || 'none' => tanpa,
      'hair' => rambut,
      'dotted' => titik,
      'dashed' || 'dashDot' || 'dashDotDot' => putus,
      'medium' => sedang,
      'mediumDashed' ||
      'mediumDashDot' ||
      'mediumDashDotDot' ||
      'slantDashDot' => sedangPutus,
      'double' => ganda,
      'thick' => tebal,
      _ => tipis,
    };
  }

  /// Yang lebih tebal dari dua garis yang berbagi sisi.
  static JenisGaris terberat(JenisGaris a, JenisGaris b) =>
      a.bobot >= b.bobot ? a : b;
}

/// Garis tepi eksplisit sel (selain garis kisi), per sisi.
@immutable
class GarisSel {
  const GarisSel({
    this.jenisAtas = JenisGaris.tanpa,
    this.jenisKanan = JenisGaris.tanpa,
    this.jenisBawah = JenisGaris.tanpa,
    this.jenisKiri = JenisGaris.tanpa,
  });

  static const tanpa = GarisSel();
  static const semua = GarisSel(
    jenisAtas: JenisGaris.tipis,
    jenisKanan: JenisGaris.tipis,
    jenisBawah: JenisGaris.tipis,
    jenisKiri: JenisGaris.tipis,
  );

  final JenisGaris jenisAtas;
  final JenisGaris jenisKanan;
  final JenisGaris jenisBawah;
  final JenisGaris jenisKiri;

  bool get atas => jenisAtas.ada;
  bool get kanan => jenisKanan.ada;
  bool get bawah => jenisBawah.ada;
  bool get kiri => jenisKiri.ada;
  bool get ada => atas || kanan || bawah || kiri;

  @override
  bool operator ==(Object other) =>
      other is GarisSel &&
      other.jenisAtas == jenisAtas &&
      other.jenisKanan == jenisKanan &&
      other.jenisBawah == jenisBawah &&
      other.jenisKiri == jenisKiri;

  @override
  int get hashCode => Object.hash(jenisAtas, jenisKanan, jenisBawah, jenisKiri);
}

/// Satu sel yang digambar [GridSel] — NETRAL sumber. Workbook, Kelola Data,
/// dan Lembar Hitung memetakan datanya ke sini; grid tidak tahu asal sel.
///
/// Grid TIDAK memformat angka: [teks] adalah teks tampil dari sumbernya
/// (untuk workbook: `s` dari server, hasil format angka Excel). Nilai persis
/// tinggal di sumbernya dan ditampilkan inspektur, bukan di sini. Ubahan
/// tampil di grid hanyalah aturan Excel sendiri: angka yang tak muat jadi
/// `####`, pemisah baris di sel tak-dibungkus jadi spasi, dan sel [general]
/// yang teksnya dibangun dari [nilai] untuk lebar kolomnya
/// ([teksGeneral] — tampilan saja, nilainya tidak berubah).
@immutable
class SelGrid {
  const SelGrid({
    this.teks = '',
    this.rumus,
    this.jenis = JenisSelGrid.teks,
    this.tebal = false,
    this.miring = false,
    this.isi,
    this.warnaTeks,
    this.rata,
    this.vertikal,
    this.bungkus = false,
    this.ukuran,
    this.font,
    this.garis = GarisSel.tanpa,
    this.gagalMuat = false,
    this.nilai,
    this.general = false,
  });

  /// Sel tanpa isi (sudah termuat, memang kosong).
  static const kosong = SelGrid(jenis: JenisSelGrid.kosong);

  /// Data baris ini gagal dimuat — DITANDAI, tidak dikosongkan diam-diam.
  static const gagal = SelGrid(jenis: JenisSelGrid.kosong, gagalMuat: true);

  final String teks;

  /// `=RUMUS` bila sel berumus; ditampilkan di mode "tampilkan rumus".
  final String? rumus;
  final JenisSelGrid jenis;
  final bool tebal;
  final bool miring;

  /// Warna isi sel dari sumbernya (dipakai apa adanya di tema terang,
  /// diredupkan di tema gelap). Isi menutup garis kisi, seperti Excel.
  final Color? isi;

  /// Warna teks dari sumbernya; dipakai hanya bila kontrasnya aman.
  final Color? warnaTeks;

  /// `null` = ikut jenis (angka kanan, teks kiri, logika/galat tengah).
  final TextAlign? rata;

  /// `null` = bawah (bawaan Excel).
  final RataVertikal? vertikal;

  /// "Wrap Text": teks dibungkus di dalam sel, tidak meluber.
  final bool bungkus;

  /// Ukuran font Excel (pt); `null` = [ukuranFontBawaanPt].
  final double? ukuran;

  /// Nama font Excel (cuma menentukan mono/bukan — lihat [fontMonospace]).
  final String? font;
  final GarisSel garis;
  final bool gagalMuat;

  /// Nilai angka sel — dipakai grid HANYA bila [general].
  final num? nilai;

  /// Format angka "General" Excel dari workbook ASLI (bukan teks CSV yang
  /// sudah diformat Excel): grid membangun teks tampilnya dari [nilai] untuk
  /// lebar kolom & font selnya ([teksGeneral]), [teks] tidak dipakai untuk
  /// gambar. Hanya berlaku untuk [JenisSelGrid.angka] dengan [nilai].
  final bool general;

  /// Tidak berisi apa pun yang menghalangi teks tetangga meluber: tanpa
  /// nilai DAN tanpa rumus. Rumus yang menghasilkan `""` tetap menghalangi.
  bool get tanpaIsi => teks.isEmpty && rumus == null;

  static const Object _tetap = Object();

  /// Salinan dengan sebagian isi diganti; gaya tetap. [rumus] & [nilai]
  /// boleh `null` eksplisit (dikosongkan).
  SelGrid salin({
    String? teks,
    Object? rumus = _tetap,
    JenisSelGrid? jenis,
    Color? warnaTeks,
    Object? nilai = _tetap,
    bool? general,
  }) => SelGrid(
    teks: teks ?? this.teks,
    rumus: identical(rumus, _tetap) ? this.rumus : rumus as String?,
    jenis: jenis ?? this.jenis,
    tebal: tebal,
    miring: miring,
    isi: isi,
    warnaTeks: warnaTeks ?? this.warnaTeks,
    rata: rata,
    vertikal: vertikal,
    bungkus: bungkus,
    ukuran: ukuran,
    font: font,
    garis: garis,
    gagalMuat: gagalMuat,
    nilai: identical(nilai, _tetap) ? this.nilai : nilai as num?,
    general: general ?? this.general,
  );
}

/// Penyunting sel [GridSel] — tanpa ini grid BACA-SAJA. Grid tidak tahu ke
/// mana isi pergi (workbook: simulasi `/hitung`; kelak Kelola Data).
@immutable
class PenyuntingSelGrid {
  const PenyuntingSelGrid({
    required this.isiUntukEdit,
    required this.simpan,
    required this.urungkan,
    required this.ulangi,
  });

  /// Isi sel untuk diedit (F2, dobel ketuk, bilah rumus): rumus bila ada,
  /// selain itu isi seperti di bilah rumus. `null` = belum termuat → edit
  /// tidak dimulai (isi lama tidak boleh tertimpa kosong diam-diam).
  final String? Function(WidgetRef ref, AlamatSel sel) isiUntukEdit;

  /// Simpan [isi] (alamat JANGKAR → isi seperti diketik; `""` = kosongkan).
  /// `null` = diterima; teks = alasan penolakan (ditampilkan, edit tetap
  /// terbuka).
  final String? Function(Map<AlamatSel, String> isi) simpan;

  /// Ctrl+Z / Ctrl+Y di luar mode edit.
  final VoidCallback urungkan;
  final VoidCallback ulangi;
}

/// Gambar di atas grid (mis. gambar lembar Excel): jangkar kiri-atas di sel
/// ([kolom], [baris]) + geser [dx]/[dy], ukuran [lebar] × [tinggi] — dp pada
/// zoom 100 %. Ikut zoom, gulir, dan panel beku seperti di Excel; tidak
/// menangkap ketukan.
@immutable
class GambarGrid {
  const GambarGrid({
    required this.kunci,
    required this.kolom,
    required this.baris,
    required this.lebar,
    required this.tinggi,
    required this.isi,
    this.dx = 0,
    this.dy = 0,
  });

  /// Unik per lembar — kunci widget `gambar-<kunci>`.
  final String kunci;
  final int kolom;
  final int baris;
  final double dx;
  final double dy;
  final double lebar;
  final double tinggi;
  final Widget isi;
}

/// Kunci widget gambar [GambarGrid] — untuk test & otomasi.
ValueKey<String> kunciGambarGrid(String kunci) => ValueKey('gambar-$kunci');

/// Kunci kolom isian editor di dalam sel.
const kunciEditorSel = ValueKey<String>('editor-sel');

/// Tempat isi sel sedang diedit: di sel itu sendiri, atau di bilah rumus.
enum TempatEdit { sel, bilah }

/// Sambungan [KendaliGridSel] → [GridSel] yang terpasang (aksi edit yang
/// dipicu dari luar grid: bilah rumus, tombol ✓/✕).
class _PengendaliEdit {
  const _PengendaliEdit({
    required this.mulai,
    required this.simpan,
    required this.batal,
    required this.tombol,
  });

  final void Function(String? isiBaru, TempatEdit tempat) mulai;
  final bool Function(int arahBaris, int arahKolom) simpan;
  final VoidCallback batal;
  final KeyEventResult Function(KeyEvent e, TempatEdit tempat) tombol;
}

/// Tata letak lembar dalam dp pada zoom 100 % (sudah dikonversi dari satuan
/// Excel lewat [lebarKolomExcelKeDp] / [tinggiBarisExcelKeDp]). Indeks
/// basis-1. Zoom diterapkan grid, bukan di sini.
@immutable
class TataLetakGrid {
  const TataLetakGrid({
    this.lebarKolom = const {},
    this.tinggiBaris = const {},
    this.gabungan = const [],
    this.barisBeku = 0,
    this.kolomBeku = 0,
    this.kolomTersembunyi = const {},
    this.barisTersembunyi = const {},
    this.lebarKolomBawaan = lebarKolomBawaanDp,
    this.tinggiBarisBawaan = tinggiBarisBawaanDp,
    this.garisKisi = true,
  });

  static const kosong = TataLetakGrid();

  final Map<int, double> lebarKolom;
  final Map<int, double> tinggiBaris;
  final List<RentangSel> gabungan;

  /// Jumlah baris/kolom yang dibekukan (freeze pane). Freeze `B4` = 3 baris,
  /// 1 kolom.
  final int barisBeku;
  final int kolomBeku;
  final Set<int> kolomTersembunyi;
  final Set<int> barisTersembunyi;
  final double lebarKolomBawaan;
  final double tinggiBarisBawaan;

  /// "Gridlines" lembar (View → Gridlines). `false` = tanpa garis kisi.
  final bool garisKisi;

  bool kolomSembunyi(int kolom) =>
      kolomTersembunyi.contains(kolom) || (lebarKolom[kolom] ?? 1) <= 0;

  bool barisSembunyi(int baris) =>
      barisTersembunyi.contains(baris) || (tinggiBaris[baris] ?? 1) <= 0;

  double lebar(int kolom) =>
      kolomSembunyi(kolom) ? 0 : (lebarKolom[kolom] ?? lebarKolomBawaan);

  double tinggi(int baris) =>
      barisSembunyi(baris) ? 0 : (tinggiBaris[baris] ?? tinggiBarisBawaan);
}

/// Pembaca sel untuk sel yang SEDANG DIGAMBAR. Dipanggil di `build` sel, jadi
/// boleh `ref.watch` (mis. provider halaman baris) — sel menggambar ulang
/// sendiri saat datanya tiba. `null` = belum termuat.
///
/// Grid juga memanggilnya untuk TETANGGA sel yang sedang dibangun (garis
/// tepi bersama, isi yang menutup kisi, teks yang meluber) — hanya di dalam
/// `jumlahBaris × jumlahKolom` [GridSel]. Implementasikan dengan `ref.watch`
/// ke sumber per blok (mis. halaman 200 baris): tetangga di blok yang sama
/// = provider yang sama = satu langganan, murah. JANGAN `ref.read` di sini:
/// di Riverpod 3 tiap `read` membuat & menutup langganan sementara.
typedef PenontonSelGrid =
    SelGrid? Function(WidgetRef ref, int baris, int kolom);

/// Pembaca sel di luar `build` (salin, inspektur) — TANPA berlangganan.
/// `null` = belum termuat.
typedef PembacaSelGrid = SelGrid? Function(WidgetRef ref, int baris, int kolom);

/// Pastikan semua sel di rentang termuat (mis. tarik halaman baris yang
/// belum diambil) sebelum disalin. Melempar bila gagal.
typedef PenyiapRentangGrid =
    Future<void> Function(WidgetRef ref, RentangSel rentang);

/// Seleksi, mode tampilan, dan zoom grid. Dipegang layar supaya bilah
/// rumus, inspektur, dan kontrol zoom di kaki mengikuti; diubah oleh
/// [GridSel].
class KendaliGridSel extends ChangeNotifier {
  KendaliGridSel({AlamatSel awal = const AlamatSel(1, 1)})
    : _aktif = awal,
      _ujung = awal,
      _rentang = RentangSel.tunggal(awal);

  /// Rentang zoom Excel di layar sentuh (pinch) & Ctrl+gulir.
  static const double zoomMin = 0.5;
  static const double zoomMaks = 2.0;

  AlamatSel _aktif;
  AlamatSel _ujung;
  RentangSel _rentang;
  bool _tampilkanRumus = false;
  double _zoom = 1;
  Offset? _fokusZoom;
  double? Function()? _hitungPasLebar;

  /// Sel aktif (kotak nama, bilah rumus, inspektur). Sel gabungan diwakili
  /// sel kiri-atasnya.
  AlamatSel get aktif => _aktif;

  /// Sudut rentang yang digerakkan Shift+panah — sel aktif tetap di tempat,
  /// seperti Excel.
  AlamatSel get ujung => _ujung;

  /// Rentang terpilih (sudah diperluas menutup sel gabungan yang tersentuh).
  RentangSel get rentang => _rentang;

  /// Mode "tampilkan rumus" (Ctrl+`).
  bool get tampilkanRumus => _tampilkanRumus;

  set tampilkanRumus(bool nilai) {
    if (nilai == _tampilkanRumus) return;
    _tampilkanRumus = nilai;
    notifyListeners();
  }

  void balikRumus() => tampilkanRumus = !_tampilkanRumus;

  /// Zoom lembar (1 = 100 %), per lembar seperti Excel.
  double get zoom => _zoom;

  set zoom(double nilai) => aturZoom(nilai);

  /// Ubah zoom; [fokus] = titik (koordinat lokal grid) yang dipertahankan
  /// di tempatnya (jari pinch, kursor Ctrl+gulir). Tanpa fokus, sudut
  /// kiri-atas area gulir yang dipertahankan. Dibulatkan ke 1 %.
  void aturZoom(double nilai, {Offset? fokus}) {
    final baru = (nilai.clamp(zoomMin, zoomMaks) * 100).roundToDouble() / 100;
    if (baru == _zoom) return;
    _zoom = baru;
    _fokusZoom = fokus;
    notifyListeners();
  }

  /// "Pas lebar": zoom supaya semua kolom terpakai muat selebar grid.
  /// Tidak melakukan apa-apa bila belum ada grid yang terpasang.
  void pasLebar() {
    final z = _hitungPasLebar?.call();
    if (z != null) aturZoom(z);
  }

  /// Ada grid terpasang yang bisa menghitung [pasLebar].
  bool get bisaPasLebar => _hitungPasLebar != null;

  Offset? _ambilFokusZoom() {
    final f = _fokusZoom;
    _fokusZoom = null;
    return f;
  }

  /// Dipanggil [GridSel]; rentang sudah memperhitungkan gabungan.
  void atur({
    required AlamatSel aktif,
    required AlamatSel ujung,
    required RentangSel rentang,
  }) {
    if (aktif == _aktif && ujung == _ujung && rentang == _rentang) return;
    _aktif = aktif;
    _ujung = ujung;
    _rentang = rentang;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────── edit

  /// Teks yang sedang diedit — SATU sumber untuk editor sel dan bilah rumus
  /// (mengetik di salah satunya terlihat di yang lain, seperti Excel).
  final TextEditingController teksEdit = TextEditingController();

  /// Fokus kolom isian bilah rumus (dipasang layar). Enter/Tab/Esc di sana
  /// diteruskan ke grid yang terpasang.
  late final FocusNode fokusBilah = FocusNode(
    debugLabel: 'GridSel.bilahRumus',
    onKeyEvent: (_, e) =>
        _edit?.tombol(e, TempatEdit.bilah) ?? KeyEventResult.ignored,
  );

  AlamatSel? _selEdit;
  TempatEdit _tempatEdit = TempatEdit.sel;
  bool _modeKetik = false;
  String _isiAwalEdit = '';
  _PengendaliEdit? _edit;

  /// Sel (jangkar) yang sedang diedit; `null` = tidak sedang mengedit.
  AlamatSel? get selEdit => _selEdit;
  bool get sedangEdit => _selEdit != null;
  TempatEdit get tempatEdit => _tempatEdit;

  /// Grid terpasang punya penyunting (peran boleh mengedit).
  bool get bisaEdit => _edit != null;

  /// Mode "Enter" Excel: edit dimulai dengan MENGETIK — panah menyimpan dan
  /// pindah sel. F2/dobel ketuk = mode "Edit": panah menggeser kursor.
  bool get modeKetik => _modeKetik;

  /// Ketuk bilah rumus: mulai edit sel aktif di bilah rumus; bila sedang
  /// mengedit di sel, pindah ke bilah rumus.
  void mulaiEditDiBilah() => _edit?.mulai(null, TempatEdit.bilah);

  /// Simpan isi yang sedang diedit lalu pindah ([arahBaris], [arahKolom]);
  /// tombol ✓ = tanpa pindah. `false` = ditolak penyunting.
  bool simpanEdit({int arahBaris = 0, int arahKolom = 0}) =>
      _edit?.simpan(arahBaris, arahKolom) ?? true;

  /// Esc / tombol ✕.
  void batalEdit() => _edit?.batal();

  void _aturEdit({
    required AlamatSel sel,
    required TempatEdit tempat,
    required bool modeKetik,
    required String isiAwal,
    required String teks,
  }) {
    _selEdit = sel;
    _tempatEdit = tempat;
    _modeKetik = modeKetik;
    _isiAwalEdit = isiAwal;
    teksEdit.value = TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
    notifyListeners();
  }

  void _pindahTempat(TempatEdit tempat) {
    if (_selEdit == null || _tempatEdit == tempat) return;
    _tempatEdit = tempat;
    _modeKetik = false;
    notifyListeners();
  }

  void _akhiriEdit({bool kabari = true}) {
    if (_selEdit == null) return;
    _selEdit = null;
    _modeKetik = false;
    if (kabari) notifyListeners();
  }

  void _kabari() => notifyListeners();

  @override
  void dispose() {
    teksEdit.dispose();
    fokusBilah.dispose();
    super.dispose();
  }
}

/// Kunci widget sel (anak kiri-atas bila bergabung) — untuk test & otomasi.
ValueKey<String> kunciSelGrid(AlamatSel alamat) => ValueKey('sel-${alamat.a1}');

ValueKey<String> kunciKepalaKolom(int kolom) =>
    ValueKey('kepala-kolom-${hurufKolom(kolom)}');

ValueKey<String> kunciKepalaBaris(int baris) => ValueKey('kepala-baris-$baris');

/// Sudut kiri-atas (pilih semua).
const kunciSudutGrid = ValueKey<String>('sudut-grid');

/// Susun TSV rentang untuk papan klip — bentuk yang ditempel Excel/Sheets.
///
/// Tab memisahkan kolom, `\n` memisahkan baris. Teks yang memuat tab, baris
/// baru, atau tanda petik dibungkus petik ganda dengan petik di dalamnya
/// digandakan (aturan yang sama dengan salinan Excel). Baris/kolom tersembunyi
/// IKUT tersalin — perilaku Excel untuk yang disembunyikan manual.
String susunTsv(
  RentangSel rentang,
  String Function(int baris, int kolom) teks,
) {
  String aman(String s) {
    if (s.contains('\t') ||
        s.contains('\n') ||
        s.contains('\r') ||
        s.contains('"')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  final baris = <String>[];
  for (var b = rentang.barisAwal; b <= rentang.barisAkhir; b++) {
    final kolom = <String>[
      for (var k = rentang.kolomAwal; k <= rentang.kolomAkhir; k++)
        aman(teks(b, k)),
    ];
    baris.add(kolom.join('\t'));
  }
  return baris.join('\n');
}

/// Rasio kontras WCAG 2.x.
double kontrasWarna(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Geser [kandidat] ke hitam/putih (mana yang lebih kontras dengan [latar])
/// sampai rasio kontras ≥ [minimum].
Color warnaTeksAman(Color kandidat, Color latar, {double minimum = 4.5}) {
  final k = kandidat.withValues(alpha: 1);
  if (kontrasWarna(k, latar) >= minimum) return k;
  final tujuan =
      kontrasWarna(Colors.black, latar) >= kontrasWarna(Colors.white, latar)
      ? Colors.black
      : Colors.white;
  for (var i = 1; i <= 10; i++) {
    final c = Color.lerp(k, tujuan, i / 10)!;
    if (kontrasWarna(c, latar) >= minimum) return c;
  }
  return tujuan;
}

// ═══════════════════════════════════════════════════════════════ widget

/// Grid sel ala Excel — ST-T-015, dipakai ulang Workbook Alat (S1b), Kelola
/// Data (S2), dan Lembar Hitung (S4).
///
/// Tampilan meniru Excel 365 (Tahap A):
/// - kepala kolom `A, B, C…` & nomor baris abu muda terkunci; freeze pane
///   menambah baris/kolom terkunci; area di luar data diisi sel kosong
///   bergaris kisi sampai tepi layar, seperti lembar Excel;
/// - garis kisi tipis abu (bisa dimatikan per lembar); isi warna menutup
///   kisi; garis tepi sel digambar DI ATAS kisi, dibagi dengan tetangga;
/// - teks meluber ke sel kosong (kiri/kanan/tengah), angka yang tak muat
///   jadi `####`, teks "Wrap Text" dibungkus; perataan "General";
/// - satu font (Inter) untuk teks & angka seperti Excel — mono hanya di mode
///   tampilkan rumus;
/// - zoom 50–200 %: pinch (tablet), Ctrl+gulir & Ctrl+=/−/0 (meja).
///
/// Virtual dua arah ([TableView]): yang dibangun cuma sel yang terlihat.
/// Seleksi klik/ketuk (Shift = perluas); keyboard: panah, Shift+panah,
/// Ctrl+panah (ke tepi), Tab/Shift+Tab, Enter/Shift+Enter, PgUp/PgDn, Home,
/// Ctrl+Home/End, Ctrl+A, Ctrl+C (TSV), Ctrl+` (tampilkan rumus).
///
/// Sel datang dari [selTonton] (sumber bebas — callback, bukan model
/// workbook). Tanpa [penyunting] grid BACA-SAJA. Dengan [penyunting], mode
/// edit seperti Excel (ke mana isinya pergi diurus penyunting):
/// - mengetik di sel terpilih = ganti isi (mode "Enter": panah menyimpan &
///   pindah); dobel ketuk/F2 = edit isi yang ada (rumus tampil sebagai
///   rumus; mode "Edit"); Backspace = edit dari kosong;
/// - Enter simpan & turun, Shift+Enter naik, Tab kanan, Shift+Tab kiri,
///   Esc batal; Delete = kosongkan rentang terpilih;
/// - Ctrl+Z / Ctrl+Y (di luar edit) = urung/ulang penyunting; di dalam
///   edit Ctrl+Z mengurungkan ketikan;
/// - sel gabungan diedit di sel kiri-atasnya; mengetuk sel lain menyimpan.
///
/// [gambar] digambar di atas sel (ikut zoom, gulir, panel beku).
class GridSel extends ConsumerStatefulWidget {
  const GridSel({
    super.key,
    required this.jumlahBaris,
    required this.jumlahKolom,
    required this.selTonton,
    required this.selBaca,
    this.tataLetak = TataLetakGrid.kosong,
    this.kendali,
    this.siapkanRentang,
    this.onTekanLama,
    this.fokusOtomatis = false,
    this.batasSalinSel = 200000,
    this.labelSemantik,
    this.penyunting,
    this.gambar = const [],
  });

  /// Rentang TERPAKAI lembar. Grid menambah baris/kolom kosong di luarnya
  /// sampai layar penuh (tanpa pernah menanyakan selnya ke sumber).
  final int jumlahBaris;
  final int jumlahKolom;
  final PenontonSelGrid selTonton;
  final PembacaSelGrid selBaca;
  final TataLetakGrid tataLetak;
  final KendaliGridSel? kendali;
  final PenyiapRentangGrid? siapkanRentang;

  /// Tekan lama sel (tablet: buka inspektur).
  final ValueChanged<AlamatSel>? onTekanLama;
  final bool fokusOtomatis;

  /// Salinan (dan Delete rentang) lebih besar dari ini ditolak dengan
  /// pesan, bukan dipotong.
  final int batasSalinSel;
  final String? labelSemantik;

  /// `null` = baca-saja.
  final PenyuntingSelGrid? penyunting;
  final List<GambarGrid> gambar;

  @override
  ConsumerState<GridSel> createState() => _GridSelState();
}

class _GridSelState extends ConsumerState<GridSel> {
  final _vertikal = ScrollController();
  final _horizontal = ScrollController();
  final _fokus = FocusNode(debugLabel: 'GridSel');
  final _ukur = _PengukurTeks();
  KendaliGridSel? _kendaliSendiri;
  KendaliGridSel? _kendaliTerpasang;
  _Geometri? _geo;
  Size _ukuran = Size.zero;
  double _zoom = 1;

  // Pinch (layar sentuh): posisi jari yang sedang menempel.
  final _jari = <int, Offset>{};
  double? _jarakAwal;
  double _zoomAwal = 1;

  KendaliGridSel get _kendali =>
      widget.kendali ?? (_kendaliSendiri ??= KendaliGridSel());

  /// Fokus editor di dalam sel. Enter/Tab/Esc ditangkap di sini, SEBELUM
  /// kolom isian (dan sebelum masukan teks platform) melihatnya.
  late final _fokusEdit = FocusNode(
    debugLabel: 'GridSel.editSel',
    onKeyEvent: (_, e) => _tombolEdit(e, TempatEdit.sel),
  );

  late final _pengendaliEdit = _PengendaliEdit(
    mulai: _mulaiEdit,
    simpan: _simpanEdit,
    batal: _batalEdit,
    tombol: _tombolEdit,
  );

  // Dobel ketuk: ketukan sebelumnya (sel jangkar + waktu jam gestur — ikut
  // FakeAsync di test). Bukan `onDoubleTap`: itu menunda SETIAP ketukan
  // tunggal sampai batas dobel ketuk lewat.
  AlamatSel? _ketukTerakhir;
  DateTime? _waktuKetukTerakhir;

  @override
  void initState() {
    super.initState();
    _pasangKendali();
  }

  @override
  void didUpdateWidget(covariant GridSel lama) {
    super.didUpdateWidget(lama);
    if (!identical(_kendaliTerpasang, _kendali)) {
      _pasangKendali();
    } else if ((lama.penyunting == null) != (widget.penyunting == null)) {
      _pasangEdit(_kendali);
    }
  }

  void _pasangKendali() {
    final lama = _kendaliTerpasang;
    if (lama != null) {
      lama.removeListener(_dengarKendali);
      if (lama._hitungPasLebar == _hitungPasLebar) lama._hitungPasLebar = null;
      _lepasEdit(lama);
    }
    final k = _kendali;
    _kendaliTerpasang = k
      ..addListener(_dengarKendali)
      .._hitungPasLebar = _hitungPasLebar;
    _pasangEdit(k);
    _zoom = k.zoom;
  }

  void _pasangEdit(KendaliGridSel k) {
    if (widget.penyunting != null) {
      k._edit = _pengendaliEdit;
    } else {
      _lepasEdit(k);
    }
  }

  /// Grid lepas / penyunting dicabut (peran berubah): edit yang belum
  /// disimpan DIBATALKAN — tidak ada lagi yang bisa menyimpannya. Kabar ke
  /// pendengar ditunda ke sesudah frame (dipanggil dari `didUpdateWidget`,
  /// saat setState widget lain dilarang); tanpa kabar bila grid dibongkar.
  void _lepasEdit(KendaliGridSel k, {bool kabari = true}) {
    if (!identical(k._edit, _pengendaliEdit)) return;
    k._edit = null;
    final tadi = k.sedangEdit;
    k._akhiriEdit(kabari: false);
    if (tadi && kabari) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) k._kabari();
      });
    }
  }

  @override
  void dispose() {
    final k = _kendaliTerpasang;
    if (k != null) {
      k.removeListener(_dengarKendali);
      if (k._hitungPasLebar == _hitungPasLebar) k._hitungPasLebar = null;
      // Tanpa kabar: pohon sedang dibongkar (setState pendengar lain
      // dilarang di sini).
      _lepasEdit(k, kabari: false);
    }
    _vertikal.dispose();
    _horizontal.dispose();
    _fokus.dispose();
    _fokusEdit.dispose();
    _kendaliSendiri?.dispose();
    _ukur.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────── zoom

  void _dengarKendali() {
    final z = _kendali.zoom;
    if (z == _zoom) return;
    final lama = _zoom;
    final geoLama = _geo;
    final fokus = _kendali._ambilFokusZoom();
    setState(() => _zoom = z);
    if (geoLama == null) return;

    // Titik isi yang ada di bawah [fokus] tetap di bawahnya sesudah zoom.
    final rasio = z / lama;
    final vLama = _vertikal.hasClients ? _vertikal.offset : 0.0;
    final hLama = _horizontal.hasClients ? _horizontal.offset : 0.0;
    final fy = math.max(0.0, (fokus?.dy ?? 0) - geoLama.tinggiTerkunci);
    final fx = math.max(0.0, (fokus?.dx ?? 0) - geoLama.lebarTerkunci);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final geo = _geo;
      if (geo == null) return;
      final fyBaru = math.max(0.0, (fokus?.dy ?? 0) - geo.tinggiTerkunci);
      final fxBaru = math.max(0.0, (fokus?.dx ?? 0) - geo.lebarTerkunci);
      void gulir(ScrollController c, double tujuan) {
        if (!c.hasClients) return;
        final p = c.position;
        c.jumpTo(tujuan.clamp(p.minScrollExtent, p.maxScrollExtent));
      }

      gulir(_vertikal, (vLama + fy) * rasio - fyBaru);
      gulir(_horizontal, (hLama + fx) * rasio - fxBaru);
    });
  }

  /// Zoom yang membuat semua kolom TERPAKAI muat selebar grid.
  double? _hitungPasLebar() {
    if (_ukuran.width <= 0 || widget.jumlahKolom < 1) return null;
    final tl = widget.tataLetak;
    var total = _Geometri.lebarKepalaBarisUntuk(widget.jumlahBaris, 1);
    for (var k = 1; k <= widget.jumlahKolom; k++) {
      total += tl.lebar(k);
    }
    if (total <= 0) return null;
    // Sedikit ruang untuk bilah gulir & pembulatan lebar kolom per zoom.
    return ((_ukuran.width - 12) / total).clamp(
      KendaliGridSel.zoomMin,
      KendaliGridSel.zoomMaks,
    );
  }

  void _sinyal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final papan = HardwareKeyboard.instance;
    if (!papan.isControlPressed && !papan.isMetaPressed) return;
    // Didaftarkan dari dalam sel (lebih dalam dari Scrollable), jadi
    // menang lebih dulu: Ctrl+gulir mengubah zoom, BUKAN menggulir lembar.
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      if (!mounted || ev is! PointerScrollEvent) return;
      final dy = ev.scrollDelta.dy;
      if (dy == 0) return;
      final kotak = context.findRenderObject();
      final fokus = kotak is RenderBox
          ? kotak.globalToLocal(ev.position)
          : null;
      _kendali.aturZoom(
        langkahZoom(_kendali.zoom, dy < 0 ? 1 : -1),
        fokus: fokus,
      );
    });
  }

  double _jarakJari() {
    final p = _jari.values.toList(growable: false);
    return (p[0] - p[1]).distance;
  }

  Offset _tengahJari() {
    final p = _jari.values.toList(growable: false);
    return (p[0] + p[1]) / 2;
  }

  void _jariTurun(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch &&
        e.kind != PointerDeviceKind.stylus) {
      return;
    }
    _jari[e.pointer] = e.localPosition;
    if (_jari.length == 2) {
      _jarakAwal = _jarakJari();
      _zoomAwal = _kendali.zoom;
    }
  }

  void _jariGerak(PointerMoveEvent e) {
    if (!_jari.containsKey(e.pointer)) return;
    _jari[e.pointer] = e.localPosition;
    final awal = _jarakAwal;
    if (_jari.length != 2 || awal == null || awal < 8) return;
    final z = _zoomAwal * _jarakJari() / awal;
    // Langkah 2 %: cukup halus untuk jari, dan grid tidak dibangun ulang
    // setiap piksel gerakan.
    if ((z - _kendali.zoom).abs() >= 0.02) {
      _kendali.aturZoom(z, fokus: _tengahJari());
    }
  }

  void _jariLepas(PointerEvent e) {
    _jari.remove(e.pointer);
    if (_jari.length < 2) _jarakAwal = null;
  }

  // ───────────────────────────────────────────────────────────── geometri

  _Geometri _geometri(Size ukuran) {
    final tl = widget.tataLetak;
    final z = _zoom;
    var beku = math.min(tl.barisBeku, widget.jumlahBaris);
    var bekuK = math.min(tl.kolomBeku, widget.jumlahKolom);
    final kepala = _Geometri.tinggiKepalaUntuk(z);

    // Freeze yang menutupi > 70 % tinggi/lebar layar (freeze 30 baris di
    // tablet potret) membuat lembar tak bisa digulir — bekuannya dilepas di
    // sumbu itu. Excel di layar kecil memang sama tak terpakainya.
    if (ukuran.height.isFinite && ukuran.height > 0) {
      var t = kepala;
      for (var b = 1; b <= beku; b++) {
        t += _Geometri.skala(tl.tinggi(b), z);
      }
      if (t > ukuran.height * 0.7) beku = 0;
    }

    // Baris & kolom tampil: rentang terpakai + sel kosong sampai layar
    // penuh (lembar Excel tidak berhenti di sel terakhir yang berisi).
    var barisTampil = math.max(widget.jumlahBaris, 1);
    var kolomTampil = math.max(widget.jumlahKolom, 1);
    if (ukuran.height.isFinite && ukuran.height > 0) {
      var t = kepala;
      for (var b = 1; b <= barisTampil && t < ukuran.height; b++) {
        t += _Geometri.skala(tl.tinggi(b), z);
      }
      while (t < ukuran.height && barisTampil < widget.jumlahBaris + 400) {
        barisTampil++;
        t += math.max(1.0, _Geometri.skala(tl.tinggi(barisTampil), z));
      }
    }
    // Jangkar gambar di luar rentang terpakai tetap tergambar (Excel tidak
    // berhenti di sel berisi terakhir).
    for (final g in widget.gambar) {
      if (g.baris > barisTampil && g.baris <= barisMaksExcel) {
        barisTampil = g.baris;
      }
      if (g.kolom > kolomTampil && g.kolom <= kolomMaksExcel) {
        kolomTampil = g.kolom;
      }
    }
    final kepalaBaris = _Geometri.lebarKepalaBarisUntuk(barisTampil, z);
    if (ukuran.width.isFinite && ukuran.width > 0) {
      var l = kepalaBaris;
      for (var k = 1; k <= kolomTampil && l < ukuran.width; k++) {
        l += _Geometri.skala(tl.lebar(k), z);
      }
      while (l < ukuran.width && kolomTampil < widget.jumlahKolom + 200) {
        kolomTampil++;
        l += math.max(1.0, _Geometri.skala(tl.lebar(kolomTampil), z));
      }
      var lb = kepalaBaris;
      for (var k = 1; k <= bekuK; k++) {
        lb += _Geometri.skala(tl.lebar(k), z);
      }
      if (lb > ukuran.width * 0.7) bekuK = 0;
    }

    final lama = _geo;
    if (lama != null &&
        identical(lama.tataLetak, tl) &&
        lama.zoom == z &&
        lama.barisData == widget.jumlahBaris &&
        lama.kolomData == widget.jumlahKolom &&
        lama.jumlahBaris == barisTampil &&
        lama.jumlahKolom == kolomTampil &&
        lama.barisBeku == beku &&
        lama.kolomBeku == bekuK) {
      return lama;
    }
    return _geo = _Geometri(
      tataLetak: tl,
      zoom: z,
      barisData: widget.jumlahBaris,
      kolomData: widget.jumlahKolom,
      jumlahBaris: barisTampil,
      jumlahKolom: kolomTampil,
      barisBeku: beku,
      kolomBeku: bekuK,
    );
  }

  // ───────────────────────────────────────────────────────────── seleksi

  void _pilih(AlamatSel sel, {bool perluas = false, bool gulir = true}) {
    final geo = _geo;
    if (geo == null) return;
    final tujuan = geo.jangkar(geo.jepit(sel));
    final k = _kendali;
    if (perluas) {
      k.atur(
        aktif: k.aktif,
        ujung: tujuan,
        rentang: geo.perluasGabungan(RentangSel.dari(k.aktif, tujuan)),
      );
    } else {
      k.atur(
        aktif: tujuan,
        ujung: tujuan,
        rentang: geo.perluasGabungan(RentangSel.tunggal(tujuan)),
      );
    }
    if (gulir) _pastikanTerlihat(tujuan);
  }

  void _ketuk(AlamatSel sel) {
    final geo = _geo;
    final jangkar = geo == null ? sel : geo.jangkar(geo.jepit(sel));
    final kini = GestureBinding.instance.samplingClock.now();
    final sebelum = _waktuKetukTerakhir;
    final dobel =
        _ketukTerakhir == jangkar &&
        sebelum != null &&
        kini.difference(sebelum) <= kDoubleTapTimeout;
    _ketukTerakhir = jangkar;
    _waktuKetukTerakhir = kini;

    final k = _kendali;
    if (k.sedangEdit) {
      // Ketukan di sel yang sedang diedit milik editornya.
      if (k.selEdit == jangkar && k.tempatEdit == TempatEdit.sel) return;
      // Mengetuk sel lain menyimpan edit (seperti Excel); ditolak → tetap.
      if (!_simpanEdit(0, 0)) return;
    }
    _fokus.requestFocus();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    _pilih(sel, perluas: shift);
    if (dobel && !shift && widget.penyunting != null) {
      _ketukTerakhir = null;
      _mulaiEdit(null, TempatEdit.sel);
    }
  }

  /// Navigasi lewat kepala/sudut saat mengedit: simpan dulu.
  bool _simpanSebelumPindah() => !_kendali.sedangEdit || _simpanEdit(0, 0);

  /// Baris/kolom terakhir rentang TERPAKAI (atau tampil, bila lembar kosong).
  int get _barisAkhirData =>
      widget.jumlahBaris >= 1 ? widget.jumlahBaris : (_geo?.jumlahBaris ?? 1);
  int get _kolomAkhirData =>
      widget.jumlahKolom >= 1 ? widget.jumlahKolom : (_geo?.jumlahKolom ?? 1);

  void _pilihKolom(int kolom) {
    final geo = _geo;
    if (geo == null || !_simpanSebelumPindah()) return;
    _fokus.requestFocus();
    final baris = geo.barisTampilPertama();
    final aktif = AlamatSel(baris, kolom);
    _kendali.atur(
      aktif: aktif,
      ujung: AlamatSel(_barisAkhirData, kolom),
      rentang: RentangSel(1, kolom, _barisAkhirData, kolom),
    );
  }

  void _pilihBaris(int baris) {
    final geo = _geo;
    if (geo == null || !_simpanSebelumPindah()) return;
    _fokus.requestFocus();
    final kolom = geo.kolomTampilPertama();
    _kendali.atur(
      aktif: AlamatSel(baris, kolom),
      ujung: AlamatSel(baris, _kolomAkhirData),
      rentang: RentangSel(baris, 1, baris, _kolomAkhirData),
    );
  }

  /// Ctrl+A / sudut kiri-atas: seluruh rentang terpakai.
  void _pilihSemua() {
    final geo = _geo;
    if (geo == null || !_simpanSebelumPindah()) return;
    _fokus.requestFocus();
    final aktif = AlamatSel(geo.barisTampilPertama(), geo.kolomTampilPertama());
    _kendali.atur(
      aktif: aktif,
      ujung: AlamatSel(_barisAkhirData, _kolomAkhirData),
      rentang: RentangSel(1, 1, _barisAkhirData, _kolomAkhirData),
    );
  }

  /// Gulir minimum supaya [sel] (seluruh gabungannya) terlihat.
  void _pastikanTerlihat(AlamatSel sel) {
    final geo = _geo;
    if (geo == null) return;
    final rentang = geo.gabunganPenuh(sel) ?? RentangSel.tunggal(sel);

    if (rentang.barisAwal > geo.barisBeku && _vertikal.hasClients) {
      final atas = geo.offsetBaris(rentang.barisAwal);
      final bawah =
          geo.offsetBaris(rentang.barisAkhir) + geo.tinggi(rentang.barisAkhir);
      final ruang = _ukuran.height - geo.tinggiTerkunci;
      _gulirKe(_vertikal, atas, bawah, ruang);
    }
    if (rentang.kolomAwal > geo.kolomBeku && _horizontal.hasClients) {
      final kiri = geo.offsetKolom(rentang.kolomAwal);
      final kanan =
          geo.offsetKolom(rentang.kolomAkhir) + geo.lebar(rentang.kolomAkhir);
      final ruang = _ukuran.width - geo.lebarTerkunci;
      _gulirKe(_horizontal, kiri, kanan, ruang);
    }
  }

  void _gulirKe(ScrollController c, double awal, double akhir, double ruang) {
    if (ruang <= 0) return;
    var tujuan = c.offset;
    if (awal < tujuan) {
      tujuan = awal;
    } else if (akhir > tujuan + ruang) {
      tujuan = math.min(awal, akhir - ruang);
    }
    tujuan = tujuan.clamp(0.0, c.position.maxScrollExtent);
    if (tujuan != c.offset) c.jumpTo(tujuan);
  }

  // ───────────────────────────────────────────────────────────── keyboard

  KeyEventResult _tombol(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final geo = _geo;
    if (geo == null) return KeyEventResult.ignored;
    final papan = HardwareKeyboard.instance;
    final ctrl = papan.isControlPressed || papan.isMetaPressed;
    final shift = papan.isShiftPressed;
    final t = e.logicalKey;
    final k = _kendali;

    if (k.sedangEdit) {
      // Editor sel belum memegang fokus (frame yang sama dengan ketikan
      // pertama): ketikan berikutnya jangan hilang, tombol edit tetap jalan.
      if (k.tempatEdit == TempatEdit.sel && !_fokusEdit.hasFocus) {
        final c = _karakterKetik(e);
        if (c != null) {
          final teks = k.teksEdit.text + c;
          k.teksEdit.value = TextEditingValue(
            text: teks,
            selection: TextSelection.collapsed(offset: teks.length),
          );
          return KeyEventResult.handled;
        }
        return _tombolEdit(e, TempatEdit.sel);
      }
      // Selebihnya milik kolom isian (kursor, Ctrl+Z ketikan, Ctrl+A, …).
      return KeyEventResult.ignored;
    }

    final p = widget.penyunting;
    if (p != null) {
      if (ctrl && t == LogicalKeyboardKey.keyZ) {
        shift ? p.ulangi() : p.urungkan();
        return KeyEventResult.handled;
      }
      if (ctrl && t == LogicalKeyboardKey.keyY) {
        p.ulangi();
        return KeyEventResult.handled;
      }
      if (!ctrl && t == LogicalKeyboardKey.f2) {
        _mulaiEdit(null, TempatEdit.sel);
        return KeyEventResult.handled;
      }
      if (!ctrl && t == LogicalKeyboardKey.delete) {
        _kosongkan();
        return KeyEventResult.handled;
      }
      if (!ctrl && t == LogicalKeyboardKey.backspace) {
        // Excel: sel aktif dikosongkan dan langsung masuk edit; Esc batal.
        _mulaiEdit('', TempatEdit.sel);
        return KeyEventResult.handled;
      }
      final c = _karakterKetik(e);
      if (c != null) {
        _mulaiEdit(c, TempatEdit.sel);
        return KeyEventResult.handled;
      }
    }

    if (ctrl && t == LogicalKeyboardKey.keyC) {
      _salin();
      return KeyEventResult.handled;
    }
    if (ctrl && t == LogicalKeyboardKey.backquote) {
      k.balikRumus();
      return KeyEventResult.handled;
    }
    if (ctrl && t == LogicalKeyboardKey.keyA) {
      _pilihSemua();
      return KeyEventResult.handled;
    }
    if (ctrl &&
        (t == LogicalKeyboardKey.equal ||
            t == LogicalKeyboardKey.add ||
            t == LogicalKeyboardKey.numpadAdd)) {
      k.aturZoom(langkahZoom(k.zoom, 1));
      return KeyEventResult.handled;
    }
    if (ctrl &&
        (t == LogicalKeyboardKey.minus ||
            t == LogicalKeyboardKey.numpadSubtract)) {
      k.aturZoom(langkahZoom(k.zoom, -1));
      return KeyEventResult.handled;
    }
    if (ctrl &&
        (t == LogicalKeyboardKey.digit0 || t == LogicalKeyboardKey.numpad0)) {
      k.aturZoom(1);
      return KeyEventResult.handled;
    }

    // Shift+panah menggerakkan UJUNG rentang; selain itu sel aktif.
    final dari = shift ? k.ujung : k.aktif;

    AlamatSel? tujuan;
    var perluas = false;
    // Ke tepi AWAL lembar (Ctrl+Home, Ctrl+←/↑): panel gulir ikut kembali ke
    // awal walau sel tujuannya di area beku — seperti Excel.
    var awalV = false;
    var awalH = false;
    if (t == LogicalKeyboardKey.arrowUp) {
      tujuan = ctrl ? geo.tepi(dari, -1, 0) : geo.langkah(dari, -1, 0);
      perluas = shift;
      awalV = ctrl;
    } else if (t == LogicalKeyboardKey.arrowDown) {
      tujuan = ctrl ? geo.tepi(dari, 1, 0) : geo.langkah(dari, 1, 0);
      perluas = shift;
    } else if (t == LogicalKeyboardKey.arrowLeft) {
      tujuan = ctrl ? geo.tepi(dari, 0, -1) : geo.langkah(dari, 0, -1);
      perluas = shift;
      awalH = ctrl;
    } else if (t == LogicalKeyboardKey.arrowRight) {
      tujuan = ctrl ? geo.tepi(dari, 0, 1) : geo.langkah(dari, 0, 1);
      perluas = shift;
    } else if (t == LogicalKeyboardKey.tab) {
      tujuan = geo.langkah(k.aktif, 0, shift ? -1 : 1);
    } else if (t == LogicalKeyboardKey.enter ||
        t == LogicalKeyboardKey.numpadEnter) {
      tujuan = geo.langkah(k.aktif, shift ? -1 : 1, 0);
    } else if (t == LogicalKeyboardKey.pageDown ||
        t == LogicalKeyboardKey.pageUp) {
      final arah = t == LogicalKeyboardKey.pageDown ? 1 : -1;
      final ruang = _ukuran.height - geo.tinggiTerkunci;
      tujuan = geo.halaman(dari, arah, ruang);
      perluas = shift;
    } else if (t == LogicalKeyboardKey.home) {
      tujuan = ctrl
          ? AlamatSel(geo.barisTampilPertama(), geo.kolomTampilPertama())
          : AlamatSel(dari.baris, geo.kolomTampilPertama());
      perluas = shift;
      awalV = ctrl;
      awalH = true;
    } else if (t == LogicalKeyboardKey.end && ctrl) {
      tujuan = AlamatSel(geo.barisDataTerakhir(), geo.kolomDataTerakhir());
      perluas = shift;
    }

    if (tujuan == null) return KeyEventResult.ignored;
    if (awalV && _vertikal.hasClients) _vertikal.jumpTo(0);
    if (awalH && _horizontal.hasClients) _horizontal.jumpTo(0);
    _pilih(tujuan, perluas: perluas);
    return KeyEventResult.handled;
  }

  // ───────────────────────────────────────────────────────────── edit

  /// Karakter yang diketik (bukan pintasan/tombol kendali), atau `null`.
  static String? _karakterKetik(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return null;
    final c = e.character;
    if (c == null || c.isEmpty) return null;
    final papan = HardwareKeyboard.instance;
    if (papan.isControlPressed || papan.isMetaPressed || papan.isAltPressed) {
      return null;
    }
    final kode = c.codeUnitAt(0);
    if (kode < 0x20 || kode == 0x7f) return null;
    return c;
  }

  void _mulaiEdit(String? isiBaru, TempatEdit tempat) {
    final p = widget.penyunting;
    final geo = _geo;
    if (p == null || geo == null) return;
    final k = _kendali;
    if (k.sedangEdit) {
      if (tempat == TempatEdit.bilah) {
        k._pindahTempat(TempatEdit.bilah);
        k.fokusBilah.requestFocus();
      }
      return;
    }
    final a = geo.jangkar(geo.jepit(k.aktif));
    final awal = p.isiUntukEdit(ref, a);
    if (awal == null && isiBaru == null) return;
    _pastikanTerlihat(a);
    k._aturEdit(
      sel: a,
      tempat: tempat,
      modeKetik: isiBaru != null && tempat == TempatEdit.sel,
      isiAwal: awal ?? '',
      teks: isiBaru ?? awal!,
    );
    // Simpul editor belum terpasang di frame ini: permintaan fokusnya
    // ditunda Flutter sampai simpulnya terpasang.
    (tempat == TempatEdit.sel ? _fokusEdit : k.fokusBilah).requestFocus();
  }

  /// Simpan isi editor lalu pindah ([db], [dk]). `false` = penyunting
  /// menolak (pesan ditampilkan, edit tetap terbuka).
  bool _simpanEdit(int db, int dk) {
    final k = _kendali;
    final a = k.selEdit;
    if (a == null) return true;
    final p = widget.penyunting;
    final teks = k.teksEdit.text;
    if (p != null && teks != k._isiAwalEdit) {
      final tolak = p.simpan({a: teks});
      if (tolak != null) {
        _kabar(tolak);
        return false;
      }
    }
    k._akhiriEdit();
    _fokus.requestFocus();
    final geo = _geo;
    if (geo != null && (db != 0 || dk != 0)) _pilih(geo.langkah(a, db, dk));
    return true;
  }

  void _batalEdit() {
    _kendali._akhiriEdit();
    _fokus.requestFocus();
  }

  /// Tombol di editor sel / bilah rumus. Yang tidak ditangani di sini
  /// diteruskan ke kolom isian (kursor, hapus, Ctrl+Z ketikan).
  KeyEventResult _tombolEdit(KeyEvent e, TempatEdit tempat) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = _kendali;
    if (!k.sedangEdit) return KeyEventResult.ignored;
    final papan = HardwareKeyboard.instance;
    final shift = papan.isShiftPressed;
    final ctrl = papan.isControlPressed || papan.isMetaPressed;
    final t = e.logicalKey;
    if (t == LogicalKeyboardKey.enter || t == LogicalKeyboardKey.numpadEnter) {
      // Alt+Enter Excel = baris baru di sel; tidak ditiru (isian satu baris).
      if (papan.isAltPressed) return KeyEventResult.handled;
      _simpanEdit(shift ? -1 : 1, 0);
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.tab) {
      _simpanEdit(0, shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (t == LogicalKeyboardKey.escape) {
      _batalEdit();
      return KeyEventResult.handled;
    }
    if (tempat == TempatEdit.sel && t == LogicalKeyboardKey.f2) {
      // F2 di dalam edit: mode Enter ⇄ mode Edit (seperti Excel).
      k._modeKetik = !k._modeKetik;
      return KeyEventResult.handled;
    }
    if (tempat == TempatEdit.sel && k.modeKetik && !shift && !ctrl) {
      final arah = switch (t) {
        LogicalKeyboardKey.arrowUp => (-1, 0),
        LogicalKeyboardKey.arrowDown => (1, 0),
        LogicalKeyboardKey.arrowLeft => (0, -1),
        LogicalKeyboardKey.arrowRight => (0, 1),
        _ => null,
      };
      if (arah != null) {
        _simpanEdit(arah.$1, arah.$2);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Delete: kosongkan isi (bukan format) setiap sel berisi di rentang
  /// terpilih — satu langkah urung. Sel di luar rentang terpakai memang
  /// kosong; anggota gabungan selain jangkarnya tidak punya isi.
  Future<void> _kosongkan() async {
    final p = widget.penyunting;
    if (p == null) return;
    final l10n = StudioL10n.of(context);
    final rentang = _kendali.rentang;
    if (rentang.jumlahSel > widget.batasSalinSel) {
      _kabar(
        l10n.gridSalinTerlaluBesar(rentang.jumlahSel, widget.batasSalinSel),
      );
      return;
    }
    if (widget.jumlahBaris < rentang.barisAwal ||
        widget.jumlahKolom < rentang.kolomAwal) {
      return;
    }
    final dalam = RentangSel(
      rentang.barisAwal,
      rentang.kolomAwal,
      math.min(rentang.barisAkhir, widget.jumlahBaris),
      math.min(rentang.kolomAkhir, widget.jumlahKolom),
    );
    try {
      await widget.siapkanRentang?.call(ref, dalam);
    } catch (_) {
      if (mounted) _kabar(l10n.gridSalinGagalMuat);
      return;
    }
    if (!mounted) return;
    final geo = _geo;
    final isi = <AlamatSel, String>{};
    for (var b = dalam.barisAwal; b <= dalam.barisAkhir; b++) {
      for (var c = dalam.kolomAwal; c <= dalam.kolomAkhir; c++) {
        final a = AlamatSel(b, c);
        final g = geo?.gabunganPenuh(a);
        if (g != null && g.awal != a) continue;
        final sel = widget.selBaca(ref, b, c);
        if (sel == null || sel.gagalMuat) {
          // Menghapus "sebagian" diam-diam lebih buruk dari tidak sama sekali.
          _kabar(l10n.gridSalinGagalMuat);
          return;
        }
        if (!sel.tanpaIsi) isi[a] = '';
      }
    }
    if (isi.isEmpty) return;
    final tolak = p.simpan(isi);
    if (tolak != null) _kabar(tolak);
  }

  // ───────────────────────────────────────────────────────────── salin

  Future<void> _salin() async {
    final l10n = StudioL10n.of(context);
    final rentang = _kendali.rentang;
    final rumus = _kendali.tampilkanRumus;

    if (rentang.jumlahSel > widget.batasSalinSel) {
      _kabar(
        l10n.gridSalinTerlaluBesar(rentang.jumlahSel, widget.batasSalinSel),
      );
      return;
    }
    // Sel di luar rentang terpakai = kosong; sumbernya tidak ditanya.
    final dalam = RentangSel(
      rentang.barisAwal,
      rentang.kolomAwal,
      math.min(rentang.barisAkhir, math.max(1, widget.jumlahBaris)),
      math.min(rentang.kolomAkhir, math.max(1, widget.jumlahKolom)),
    );
    final adaData =
        widget.jumlahBaris >= rentang.barisAwal &&
        widget.jumlahKolom >= rentang.kolomAwal;
    try {
      if (adaData) await widget.siapkanRentang?.call(ref, dalam);
    } catch (_) {
      if (mounted) _kabar(l10n.gridSalinGagalMuat);
      return;
    }
    if (!mounted) return;

    var belumTermuat = false;
    final tsv = susunTsv(rentang, (b, k) {
      if (b > widget.jumlahBaris || k > widget.jumlahKolom) return '';
      final sel = widget.selBaca(ref, b, k);
      if (sel == null || sel.gagalMuat) {
        belumTermuat = true;
        return '';
      }
      return rumus && sel.rumus != null ? sel.rumus! : sel.teks;
    });
    // Salinan bolong diam-diam lebih buruk daripada tidak menyalin: yang
    // menempel di Excel mengira sel itu memang kosong.
    if (belumTermuat) {
      _kabar(l10n.gridSalinGagalMuat);
      return;
    }

    await Clipboard.setData(ClipboardData(text: tsv));
    if (mounted) {
      _kabar(l10n.gridDisalin(rentang.jumlahBaris, rentang.jumlahKolom));
    }
  }

  void _kabar(String pesan) {
    final pembawa = ScaffoldMessenger.maybeOf(context);
    pembawa
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(pesan), duration: const Duration(seconds: 2)),
      );
  }

  // ───────────────────────────────────────────────────────────── bangun

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, batas) {
        final lama = _ukuran;
        _ukuran = batas.biggest;
        final geo = _geometri(_ukuran);
        final edit = _kendali.selEdit;
        if (edit != null && lama != _ukuran) {
          // Keyboard lunak muncul → grid memendek: sel yang diedit tetap
          // terlihat.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _kendali.selEdit == edit) _pastikanTerlihat(edit);
          });
        }
        final konteks = _KonteksGrid(
          kendali: _kendali,
          selTonton: widget.selTonton,
          geo: geo,
          warna: w,
          dpr: dpr,
          ukur: _ukur,
          onKetuk: _ketuk,
          onTekanLama: widget.onTekanLama,
          onPilihKolom: _pilihKolom,
          onPilihBaris: _pilihBaris,
          onPilihSemua: _pilihSemua,
          onSinyal: _sinyal,
          fokusEdit: _fokusEdit,
          onSimpanEdit: _simpanEdit,
        );

        final tabel = TableView.builder(
          primary: false,
          diagonalDragBehavior: DiagonalDragBehavior.free,
          verticalDetails: ScrollableDetails.vertical(controller: _vertikal),
          horizontalDetails: ScrollableDetails.horizontal(
            controller: _horizontal,
          ),
          rowCount: geo.jumlahBaris + 1,
          columnCount: geo.jumlahKolom + 1,
          pinnedRowCount: 1 + geo.barisBeku,
          pinnedColumnCount: 1 + geo.kolomBeku,
          rowBuilder: (i) => TableSpan(
            extent: FixedTableSpanExtent(
              i == 0 ? geo.tinggiKepala : geo.tinggi(i),
            ),
          ),
          columnBuilder: (i) => TableSpan(
            extent: FixedTableSpanExtent(
              i == 0 ? geo.lebarKepalaBaris : geo.lebar(i),
            ),
          ),
          cellBuilder: (context, v) => _bangunSel(konteks, v),
        );

        return Semantics(
          container: true,
          label: widget.labelSemantik,
          child: Focus(
            focusNode: _fokus,
            autofocus: widget.fokusOtomatis,
            onKeyEvent: _tombol,
            child: Listener(
              onPointerDown: _jariTurun,
              onPointerMove: _jariGerak,
              onPointerUp: _jariLepas,
              onPointerCancel: _jariLepas,
              onPointerPanZoomStart: (_) => _zoomAwal = _kendali.zoom,
              onPointerPanZoomUpdate: (e) {
                if (e.scale == 1) return;
                final z = _zoomAwal * e.scale;
                if ((z - _kendali.zoom).abs() >= 0.02) {
                  _kendali.aturZoom(z, fokus: e.localPosition);
                }
              },
              child: ColoredBox(
                color: w.permukaan,
                child: MouseRegion(
                  cursor: SystemMouseCursors.cell,
                  child: Scrollbar(
                    controller: _horizontal,
                    notificationPredicate: (n) =>
                        n.metrics.axis == Axis.horizontal,
                    child: Scrollbar(
                      controller: _vertikal,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.vertical,
                      child: widget.gambar.isEmpty
                          ? tabel
                          : Stack(
                              children: [
                                tabel,
                                Positioned.fill(child: _lapisGambar(geo)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Gambar di atas sel, per panel seperti Excel: tiap panel (beku
  /// kiri-atas, beku atas, beku kiri, gulir) adalah jendela ke lembar yang
  /// SAMA dengan gulirannya sendiri, dipotong ke panelnya — gambar di area
  /// gulir lewat di BAWAH baris/kolom beku. Hanya gambar yang terlihat di
  /// suatu panel yang dibangun (byte-nya ditarik saat itu).
  Widget _lapisGambar(_Geometri geo) => IgnorePointer(
    child: ListenableBuilder(
      listenable: Listenable.merge([_vertikal, _horizontal]),
      builder: (context, _) {
        final sv = _vertikal.hasClients ? _vertikal.offset : 0.0;
        final sh = _horizontal.hasClients ? _horizontal.offset : 0.0;
        final x0 = geo.lebarKepalaBaris;
        final x1 = geo.lebarTerkunci;
        final y0 = geo.tinggiKepala;
        final y1 = geo.tinggiTerkunci;
        final x2 = math.max(x1, _ukuran.width);
        final y2 = math.max(y1, _ukuran.height);
        final z = geo.zoom;
        final panel = <(Rect, double, double)>[
          if (x1 > x0 && y1 > y0) (Rect.fromLTRB(x0, y0, x1, y1), 0, 0),
          if (y1 > y0) (Rect.fromLTRB(x1, y0, x2, y1), sh, 0),
          if (x1 > x0) (Rect.fromLTRB(x0, y1, x1, y2), 0, sv),
          (Rect.fromLTRB(x1, y1, x2, y2), sh, sv),
        ];
        return Stack(
          children: [
            for (final (kotak, gx, gy) in panel)
              if (!kotak.isEmpty)
                Positioned.fromRect(
                  rect: kotak,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final g in widget.gambar)
                          if (Rect.fromLTWH(
                                x0 + geo.xKolom(g.kolom) + g.dx * z - gx,
                                y0 + geo.yBaris(g.baris) + g.dy * z - gy,
                                g.lebar * z,
                                g.tinggi * z,
                              )
                              case final r when r.overlaps(kotak))
                            Positioned(
                              left: r.left - kotak.left,
                              top: r.top - kotak.top,
                              width: r.width,
                              height: r.height,
                              child: KeyedSubtree(
                                key: kunciGambarGrid(g.kunci),
                                child: g.isi,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );

  TableViewCell _bangunSel(_KonteksGrid k, TableVicinity v) {
    final r = v.row;
    final c = v.column;
    if (r == 0 && c == 0) {
      return TableViewCell(
        child: _Sudut(key: kunciSudutGrid, konteks: k),
      );
    }
    if (r == 0) {
      return TableViewCell(
        child: _KepalaKolom(key: kunciKepalaKolom(c), kolom: c, konteks: k),
      );
    }
    if (c == 0) {
      return TableViewCell(
        child: _KepalaBaris(key: kunciKepalaBaris(r), baris: r, konteks: k),
      );
    }

    final geo = k.geo;
    final bagian = geo.gabunganTampil(r, c);
    if (bagian != null) {
      final penuh = geo.gabunganPenuh(AlamatSel(r, c))!;
      final jangkar = penuh.awal;
      final isiDiSini = bagian.memuat(jangkar.baris, jangkar.kolom);
      return TableViewCell(
        rowMergeStart: bagian.jumlahBaris > 1 ? bagian.barisAwal : null,
        rowMergeSpan: bagian.jumlahBaris > 1 ? bagian.jumlahBaris : null,
        columnMergeStart: bagian.jumlahKolom > 1 ? bagian.kolomAwal : null,
        columnMergeSpan: bagian.jumlahKolom > 1 ? bagian.jumlahKolom : null,
        child: _SelWidget(
          key: isiDiSini
              ? kunciSelGrid(jangkar)
              : ValueKey('sel-bagian-${bagian.awal.a1}'),
          baris: jangkar.baris,
          kolom: jangkar.kolom,
          bagian: bagian,
          gabungan: penuh,
          konteks: k,
        ),
      );
    }

    if (geo.lebar(c) <= 0 || geo.tinggi(r) <= 0) {
      return const TableViewCell(child: SizedBox.shrink());
    }
    return TableViewCell(
      child: _SelWidget(
        key: kunciSelGrid(AlamatSel(r, c)),
        baris: r,
        kolom: c,
        bagian: RentangSel(r, c, r, c),
        konteks: k,
      ),
    );
  }
}
