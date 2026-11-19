import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'pembaca_halaman.dart' show TeksTerbaca;

/// Identitas alat dan pemilik yang TERTULIS di kertas lembar kerja, dibaca dari
/// teks seluruh halaman (ML Kit sehalaman, tanpa citra tambahan) lewat
/// jangkar LABEL CETAK: "Nama Alat", "Merk", "Type/Model", "Serial Number/LPI",
/// "Owner", "Address", "Calibration Date", dan variasi Indonesia/Inggrisnya.
///
/// Layout-agnostik: tidak ada peta sel baru. Nilai = teks di KANAN label pada
/// baris yang sama, berhenti di label berikutnya atau jarak kosong yang besar.
/// Semua hasil hanya USULAN (kuning di lembar, dikonfirmasi teknisi); yang tidak
/// yakin dikosongkan, tidak ditebak.
class IdentitasKertas {
  const IdentitasKertas({
    this.namaAlat,
    this.merk,
    this.model,
    this.seri,
    this.idAlat,
    this.pemilik,
    this.alamat,
    this.lokasi,
    this.tanggalKalibrasi,
    this.tanggalTerima,
  });

  /// Tidak ada satu pun yang terbaca.
  static const kosong = IdentitasKertas();

  final String? namaAlat;
  final String? merk;
  final String? model;

  /// Nomor seri APA ADANYA seperti terbaca (hanya dirapikan spasinya). Untuk
  /// pencocokan pakai [kunciSeri]; untuk tampilan pakai nilai ini.
  final String? seri;
  final String? idAlat;
  final String? pemilik;
  final String? alamat;
  final String? lokasi;
  final DateTime? tanggalKalibrasi;
  final DateTime? tanggalTerima;

  bool get adaIsi =>
      namaAlat != null ||
      merk != null ||
      model != null ||
      seri != null ||
      idAlat != null ||
      pemilik != null ||
      alamat != null ||
      lokasi != null ||
      tanggalKalibrasi != null ||
      tanggalTerima != null;

  IdentitasKertas salin({
    String? namaAlat,
    String? merk,
    String? model,
    String? seri,
    String? idAlat,
    String? pemilik,
    String? alamat,
  }) => IdentitasKertas(
    namaAlat: namaAlat ?? this.namaAlat,
    merk: merk ?? this.merk,
    model: model ?? this.model,
    seri: seri ?? this.seri,
    idAlat: idAlat ?? this.idAlat,
    pemilik: pemilik ?? this.pemilik,
    alamat: alamat ?? this.alamat,
    lokasi: lokasi,
    tanggalKalibrasi: tanggalKalibrasi,
    tanggalTerima: tanggalTerima,
  );

  @override
  String toString() =>
      'IdentitasKertas(namaAlat: $namaAlat, merk: $merk, model: $model, '
      'seri: $seri, idAlat: $idAlat, pemilik: $pemilik, alamat: $alamat, '
      'lokasi: $lokasi, kal: $tanggalKalibrasi, terima: $tanggalTerima)';
}

// ---------------------------------------------------------------------------
// Seri: kunci pencocokan
// ---------------------------------------------------------------------------

/// Kunci pencocokan nomor seri PERSIS: huruf besar, hanya huruf dan angka.
/// Tidak mengubah apa pun untuk tampilan.
String kunciSeri(String seri) =>
    seri.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Kunci pencocokan MIRIP: [kunciSeri] dengan huruf O dianggap angka 0 dan huruf
/// I dianggap angka 1 (salah baca yang paling umum di tulisan tangan). HANYA
/// untuk membandingkan; nilai yang ditampilkan tidak pernah diubah.
String kunciSeriLonggar(String seri) =>
    kunciSeri(seri).replaceAll('O', '0').replaceAll('I', '1');

/// Jarak edit (Levenshtein) dua teks.
int jarakEdit(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var sebelum = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final kini = List<int>.filled(b.length + 1, 0);
    kini[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final ganti = sebelum[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      kini[j] = math.min(math.min(sebelum[j] + 1, kini[j - 1] + 1), ganti);
    }
    sebelum = kini;
  }

  return sebelum[b.length];
}

/// Dua nomor seri MIRIP (bukan persis)? Jarak edit pada kunci longgar paling
/// banyak 1 untuk seri pendek (< 6 karakter) dan 2 untuk yang lebih panjang;
/// seri 3 karakter atau kurang tidak pernah dianggap mirip (terlalu longgar).
bool seriMirip(String a, String b) {
  final x = kunciSeriLonggar(a);
  final y = kunciSeriLonggar(b);
  if (x.length < 4 || y.length < 4) return false;

  final panjang = math.min(x.length, y.length);
  final batas = panjang < 6 ? 1 : 2;

  return jarakEdit(x, y) <= batas;
}

// ---------------------------------------------------------------------------
// Tanggal
// ---------------------------------------------------------------------------

const _bulan = <String, int>{
  'jan': 1,
  'januari': 1,
  'january': 1,
  'feb': 2,
  'februari': 2,
  'february': 2,
  'mar': 3,
  'maret': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'mei': 5,
  'may': 5,
  'jun': 6,
  'juni': 6,
  'june': 6,
  'jul': 7,
  'juli': 7,
  'july': 7,
  'agu': 8,
  'agt': 8,
  'agus': 8,
  'agustus': 8,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'okt': 10,
  'oktober': 10,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'nopember': 11,
  'november': 11,
  'des': 12,
  'desember': 12,
  'dec': 12,
  'december': 12,
};

/// Angka dari token yang salah baca huruf (O -> 0, l/I -> 1) tapi selebihnya
/// angka. `null` bila ada karakter lain.
int? _angkaToleran(String t) {
  if (t.isEmpty || t.length > 4) return null;
  final b = t.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[lI|]'), '1');

  return RegExp(r'^\d+$').hasMatch(b) ? int.parse(b) : null;
}

/// Tanggal dari tulisan di kertas: `12/11/2026`, `12-11-26`, `12.11.2026`,
/// `12 Nov 2026`, `12 November 2026`, `12-Nov-26` (bulan Indonesia atau Inggris).
/// Urutan angka selalu hari-bulan-tahun. Tahun dua digit = 20xx.
///
/// `null` bila tidak terbaca, tidak sah (31 Februari, bulan 13), tahun di luar
/// 2000-2099, atau LEBIH dari dua hari sesudah [sekarang] (jam HP yang meleset
/// diberi toleransi; tanggal kalibrasi di masa depan hampir pasti salah baca).
/// Tidak menebak: ragu = `null`.
DateTime? parseTanggalKertas(String teks, {DateTime? sekarang}) {
  final t = teks.trim();
  if (t.isEmpty) return null;

  int? hari;
  int? bulan;
  int? tahun;

  // 1) d/m/y dengan pemisah / - . atau spasi di antara angka. Karakter yang
  // sering salah baca (O, o, l, I, |) diterima di posisi angka; nilainya
  // dipulihkan di [_angkaToleran].
  const d = '[0-9OolI|]';
  final angka = RegExp(
    '^($d{1,2})'
    r'\s*[/\-.]\s*'
    '($d{1,2})'
    r'\s*[/\-.]\s*'
    '($d{2,4})\$',
  ).firstMatch(t);
  if (angka != null) {
    hari = _angkaToleran(angka.group(1)!);
    bulan = _angkaToleran(angka.group(2)!);
    tahun = _angkaToleran(angka.group(3)!);
  } else {
    // 2) d Bulan y.
    final nama = RegExp(
      '^($d{1,2})'
      r'[\s\-./]*([A-Za-z]{3,10})\.?[\s\-./,]*'
      '($d{2,4})\$',
    ).firstMatch(t);
    if (nama != null) {
      hari = _angkaToleran(nama.group(1)!);
      bulan = _bulan[nama.group(2)!.toLowerCase()];
      tahun = _angkaToleran(nama.group(3)!);
    }
  }

  if (hari == null || bulan == null || tahun == null) return null;
  if (tahun < 100) tahun += 2000;
  if (tahun < 2000 || tahun > 2099) return null;
  if (bulan < 1 || bulan > 12 || hari < 1 || hari > 31) return null;

  final hasil = DateTime(tahun, bulan, hari);
  // `DateTime` menggulung 31 Februari ke Maret; tolak yang tergulung.
  if (hasil.month != bulan || hasil.day != hari) return null;

  if (sekarang != null) {
    final batas = DateTime(
      sekarang.year,
      sekarang.month,
      sekarang.day,
    ).add(const Duration(days: 2));
    if (hasil.isAfter(batas)) return null;
  }

  return hasil;
}

// ---------------------------------------------------------------------------
// Label
// ---------------------------------------------------------------------------

enum _Bidang {
  namaAlat,
  namaUmum,
  merk,
  model,
  seri,
  idAlat,
  pemilik,
  alamat,
  lokasi,
  tglKalibrasi,
  tglTerima,
}

final _labelBidang = <_Bidang, RegExp>{
  _Bidang.namaAlat: RegExp(
    r'^(nama\s*(alat|instrumen|instrument|peralatan|equipment)|'
    r'(equipment|instrument|device)\s*name)$',
  ),
  _Bidang.namaUmum: RegExp(r'^(name|nama)$'),
  _Bidang.merk: RegExp(
    r'^(merk|merek|brand|make|manufactur(e|er|ing)|'
    r'(merk|merek|brand)/(manufactur(e|er|ing)|type|model|tipe))$',
  ),
  _Bidang.model: RegExp(
    r'^(type/model|model/type|tipe/model|model|tipe|type)$',
  ),
  _Bidang.seri: RegExp(
    r'^(serial(\s*(number|no|num))?(/lpi)?|(no|nomor)\s*seri|'
    r'(no|nomor)\s*serial|seri|s/n|sn)$',
  ),
  _Bidang.idAlat: RegExp(
    r'^(id\s*alat|(no|nomor)\s*(id|identifikasi)|equipment\s*id|asset\s*id)$',
  ),
  _Bidang.pemilik: RegExp(
    r'^(owner|pemilik|customer|pelanggan|client|company|perusahaan|'
    r'(nama|name)\s*(cust|customer|pelanggan|pemilik|owner|perusahaan))$',
  ),
  _Bidang.alamat: RegExp(
    r'^(address|alamat(\s*(cust|customer|pelanggan))?|(cust|customer)\s*address)$',
  ),
  _Bidang.lokasi: RegExp(
    r'^(calibration\s*loc(ation)?|lokasi(\s*kalibrasi)?|location|'
    r'tempat\s*kalibrasi)$',
  ),
  _Bidang.tglKalibrasi: RegExp(
    r'^(calibration\s*date|(tgl|tanggal)\s*kalibrasi|tgl\s*kal|'
    r'date\s*of\s*calibration)$',
  ),
  _Bidang.tglTerima: RegExp(
    r'^(received\s*date|(tgl|tanggal)\s*(diterima|terima|penerimaan)|'
    r'date\s*received)$',
  ),
};

/// Label cetak yang BUKAN bidang yang dibaca, tetapi mengakhiri nilai di
/// sebelahnya (kolom lain di baris yang sama).
final _labelPenghenti = RegExp(
  r'^(range(/resolution)?|rentang(\s*ukur)?|capacity|kapasitas(\s*alat)?|'
  r'resolution|resolusi(\s*alat)?|method|metode(\s*kalibrasi)?|'
  r'calibration\s*(method|metode|result|data)|thermohygro(\s*used)?|'
  r'suhu(\s*ruang(an)?)?|kelembapan|kelembaban|env\.?(\s*condition)?|'
  r'environment(\s*cond)?|standard(\s*name)?|usage\s*check|'
  r'tipe\s*thermocouple|nilai\s*e.*|kelas|equipment|equipment\s*identity.*|'
  r'owner|identitas.*|data\s*customer|satuan|unit|lokasi\s*kalibrasi)$',
);

/// Pilihan cetak yang sering duduk di area nilai dan BUKAN tulisan teknisi:
/// Thermohygro (TH-2) dan kata Insitu/Inlab. Dibuang per elemen.
bool _pilihanCetak(String t, {bool lokasi = false}) {
  final x = t.trim().toLowerCase();

  return RegExp(r'^th-?\d+$').hasMatch(x) ||
      (!lokasi &&
          const {
            'insitu',
            'inlab',
            'insitu:',
            'inlab:',
            'in-situ',
            'in-lab',
          }.contains(x));
}

/// Seluruh nilai hanya titik-titik isian, tanda baca, atau SATU satuan cetak
/// ("pH", "oC", "%RH", ...): bukan tulisan teknisi. Satuan di dalam nilai yang
/// lebih panjang ("pH Meter") tidak dibuang.
bool _bukanNilai(String t) {
  final x = t.trim().toLowerCase();
  if (x.isEmpty) return true;
  if (RegExp(r'^[\s.\-_:;,()\[\]/\|…·•]+$').hasMatch(x)) return true;

  return const {
    'ph',
    'oc',
    '°c',
    'c',
    '%rh',
    'rh',
    'mm',
    'cm',
    'm',
    'g',
    'mg',
    'kg',
    'ml',
    'l',
    'ntu',
    'hpa',
    'bar',
    'psi',
    'rpm',
    'hz',
    'v',
    'a',
  }.contains(x);
}

String _normalLabel(String s) {
  var t = s.toLowerCase().trim();
  t = t.replaceAll(RegExp(r'\s*/\s*'), '/');
  t = t.replaceAll(RegExp(r'^\d+\s*[.)]\s*'), '');
  // Titik di tengah singkatan ("Tgl.", "No.", "Cust.", "Loc.") bukan bagian label.
  t = t.replaceAll('.', ' ');
  t = t.replaceAll(RegExp(r'[\s:]+$'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t;
}

// ---------------------------------------------------------------------------
// Pembaca
// ---------------------------------------------------------------------------

class _El {
  _El(this.teks, this.kotak, this.keyakinan);

  final String teks;
  final Rect kotak;
  final double? keyakinan;
}

class _Baris {
  _Baris(this.y, this.el);

  final double y;
  final List<_El> el;
}

class _Cocok {
  _Cocok(this.bidang, this.baris, this.akhirLabel, this.y);

  final _Bidang bidang;
  final int baris;

  /// Indeks elemen TERAKHIR label (termasuk titik dua yang berdiri sendiri).
  final int akhirLabel;
  final double y;
}

/// Elemen yang terbaca bergabung "Name: Mettler" menjadi dua elemen supaya
/// label dan nilainya bisa dipisah. Hanya bila bagian kirinya memang label.
List<_El> _pecahTitikDua(List<_El> asal) {
  final hasil = <_El>[];
  for (final e in asal) {
    final i = e.teks.indexOf(':');
    if (i <= 0 || i >= e.teks.length - 1) {
      hasil.add(e);
      continue;
    }
    final kiri = e.teks.substring(0, i);
    final kanan = e.teks.substring(i + 1).trim();
    final n = _normalLabel(kiri);
    final label =
        _labelBidang.values.any((r) => r.hasMatch(n)) ||
        _labelPenghenti.hasMatch(n);
    if (!label || kanan.isEmpty) {
      hasil.add(e);
      continue;
    }
    final lebar = e.kotak.width;
    final batas = e.kotak.left + lebar * (i + 1) / e.teks.length;
    hasil
      ..add(
        _El(
          '$kiri:',
          Rect.fromLTRB(e.kotak.left, e.kotak.top, batas, e.kotak.bottom),
          e.keyakinan,
        ),
      )
      ..add(
        _El(
          kanan,
          Rect.fromLTRB(batas, e.kotak.top, e.kotak.right, e.kotak.bottom),
          e.keyakinan,
        ),
      );
  }

  return hasil;
}

double _median(List<double> d) {
  final u = [...d]..sort();

  return u[u.length ~/ 2];
}

/// Membaca identitas kertas dari [terbaca] (elemen teks seluruh halaman, tegak,
/// berikut kotaknya). [sekarang] membatasi tanggal masa depan
/// ([parseTanggalKertas]); `null` = tanpa batas itu.
///
/// Tidak pernah melempar: teks tak terduga menghasilkan bidang kosong.
IdentitasKertas bacaIdentitasKertas(
  List<TeksTerbaca> terbaca, {
  DateTime? sekarang,
}) {
  final awal = [
    for (final t in terbaca)
      if (t.teks.trim().isNotEmpty) _El(t.teks.trim(), t.kotak, t.keyakinan),
  ];
  if (awal.length < 3) return IdentitasKertas.kosong;

  final elemen = _pecahTitikDua(awal);
  final h = _median([for (final e in elemen) e.kotak.height]);
  if (h <= 0) return IdentitasKertas.kosong;

  // ---- baris: elemen yang segaris (pusat vertikal berdekatan) ----------------
  final urut = [...elemen]
    ..sort((a, b) => a.kotak.center.dy.compareTo(b.kotak.center.dy));
  final baris = <_Baris>[];
  for (final e in urut) {
    if (baris.isNotEmpty &&
        (e.kotak.center.dy - baris.last.y).abs() <= h * 0.6) {
      baris.last.el.add(e);
    } else {
      baris.add(_Baris(e.kotak.center.dy, [e]));
    }
  }
  for (final b in baris) {
    b.el.sort((a, c) => a.kotak.left.compareTo(c.kotak.left));
  }

  final jedaKolom = h * 2.2;
  final jarakNilaiMaks = h * 22;

  // ---- label: hanya di AWAL sel (elemen pertama baris, atau sesudah jeda) ----
  bool awalSel(_Baris b, int i) =>
      i == 0 || b.el[i].kotak.left - b.el[i - 1].kotak.right > jedaKolom;

  /// Label terpanjang (1-6 elemen) yang dimulai di [i], atau `null`.
  ({_Bidang? bidang, bool penghenti, int akhir})? labelDi(_Baris b, int i) {
    for (var n = math.min(6, b.el.length - i); n >= 1; n--) {
      final teks = [for (var k = i; k < i + n; k++) b.el[k].teks].join(' ');
      final norm = _normalLabel(teks);
      if (norm.isEmpty) continue;

      for (final e in _labelBidang.entries) {
        if (e.value.hasMatch(norm)) {
          return (bidang: e.key, penghenti: false, akhir: i + n - 1);
        }
      }
      if (_labelPenghenti.hasMatch(norm)) {
        return (bidang: null, penghenti: true, akhir: i + n - 1);
      }
    }

    return null;
  }

  // Judul bagian "OWNER" yang berdiri sendiri (tanpa titik dua dan tanpa nilai
  // di sebelahnya) = batas atas-bawah untuk label "Name" yang dipakai dua kali
  // (alat, lalu pemilik). Bukan label nilai.
  double? yJudulOwner;
  final judulOwner = <(int, int)>{};
  for (var r = 0; r < baris.length; r++) {
    final b = baris[r];
    for (var i = 0; i < b.el.length; i++) {
      if (!awalSel(b, i)) continue;
      if (_normalLabel(b.el[i].teks) == 'owner' &&
          !b.el[i].teks.contains(':') &&
          (i == b.el.length - 1 ||
              (b.el[i + 1].teks != ':' &&
                  b.el[i + 1].kotak.left - b.el[i].kotak.right > jedaKolom))) {
        yJudulOwner ??= b.y;
        judulOwner.add((r, i));
      }
    }
  }

  final cocok = <_Cocok>[];
  for (var r = 0; r < baris.length; r++) {
    final b = baris[r];
    for (var i = 0; i < b.el.length; i++) {
      if (!awalSel(b, i)) continue;
      if (judulOwner.contains((r, i))) continue;
      final l = labelDi(b, i);
      if (l == null || l.bidang == null) continue;
      cocok.add(_Cocok(l.bidang!, r, l.akhir, b.y));
    }
  }
  if (cocok.isEmpty) return IdentitasKertas.kosong;

  // ---- nilai di kanan label ---------------------------------------------------
  /// Elemen nilai di kanan label [c], dan kotak elemen pertamanya.
  ({List<_El> el, int barisAkhir})? nilaiDi(_Cocok c, {required bool panjang}) {
    final b = baris[c.baris];
    var i = c.akhirLabel + 1;
    // Titik dua berdiri sendiri sesudah label.
    if (i < b.el.length && b.el[i].teks == ':') i++;

    final hasil = <_El>[];
    final tepiLabel = b.el[c.akhirLabel].kotak.right;
    while (i < b.el.length) {
      final e = b.el[i];
      var teks = e.teks;
      // Awalan ":" menempel pada nilai (":Mettler").
      if (hasil.isEmpty && teks.startsWith(':')) {
        teks = teks.substring(1).trim();
        if (teks.isEmpty) {
          i++;
          continue;
        }
      }

      // Label lain (bidang atau penghenti) di awal sel mengakhiri nilai.
      if (awalSel(b, i) || hasil.isEmpty) {
        final l = labelDi(b, i);
        if (l != null) break;
      }

      if (hasil.isEmpty) {
        if (e.kotak.left - tepiLabel > jarakNilaiMaks) break;
      } else if (e.kotak.left - hasil.last.kotak.right > jedaKolom) {
        break;
      }

      hasil.add(_El(teks, e.kotak, e.keyakinan));
      i++;
    }

    var barisAkhir = c.baris;

    // Alamat bisa turun ke baris di bawahnya: hanya teks yang berada di bawah
    // nilai pertama, tanpa label.
    if (panjang && hasil.isNotEmpty) {
      final kiri = hasil.first.kotak.left - h;
      for (var r = c.baris + 1; r < math.min(baris.length, c.baris + 3); r++) {
        final bb = baris[r];
        if (bb.y - baris[barisAkhir].y > h * 2.4) break;

        // Baris yang punya label di sebelah kiri nilai pertama adalah baris
        // berlabel lain (bukan lanjutan alamat).
        var barisBerlabel = false;
        for (var k = 0; k < bb.el.length; k++) {
          if (bb.el[k].kotak.left >= hasil.first.kotak.left) break;
          if (awalSel(bb, k) && labelDi(bb, k) != null) {
            barisBerlabel = true;
            break;
          }
        }
        if (barisBerlabel) break;

        final lanjut = <_El>[];
        for (var k = 0; k < bb.el.length; k++) {
          final e = bb.el[k];
          if (e.kotak.left < kiri) continue;
          if (awalSel(bb, k) && labelDi(bb, k) != null) break;
          if (lanjut.isNotEmpty &&
              e.kotak.left - lanjut.last.kotak.right > jedaKolom) {
            break;
          }
          if (lanjut.isEmpty &&
              e.kotak.left - hasil.first.kotak.left > jarakNilaiMaks) {
            break;
          }
          lanjut.add(e);
        }
        if (lanjut.isEmpty ||
            lanjut.every((e) => _pilihanCetak(e.teks) || _bukanNilai(e.teks))) {
          break;
        }

        hasil.addAll(lanjut);
        barisAkhir = r;
      }
    }

    return hasil.isEmpty ? null : (el: hasil, barisAkhir: barisAkhir);
  }

  /// Teks nilai yang sudah dibersihkan, atau `null` (kosong / noise cetak /
  /// keyakinan pengenal rendah).
  String? teksNilai(List<_El> el, {int maks = 80, bool lokasi = false}) {
    final bersih = [
      for (final e in el)
        // "Inlab"/"Insitu" adalah pilihan cetak di area Thermohygro, tetapi
        // jawaban yang sah untuk lokasi kalibrasi.
        if (!_pilihanCetak(e.teks, lokasi: lokasi)) e,
    ];
    if (bersih.isEmpty) return null;

    // Pengenal yang MEMBERI keyakinan dan yakinnya rendah = tidak yakin.
    for (final e in bersih) {
      final k = e.keyakinan;
      if (k != null && k < 0.35) return null;
    }

    var t = bersih.map((e) => e.teks).join(' ').replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAll(RegExp(r'^[:\s]+'), '').trim();
    if (t.length > maks) t = t.substring(0, maks).trim();
    if (_bukanNilai(t) || !RegExp(r'[A-Za-z0-9]').hasMatch(t)) return null;

    return t;
  }

  String? namaAlat;
  String? merk;
  String? model;
  String? seri;
  String? idAlat;
  String? pemilik;
  String? alamat;
  String? lokasi;
  DateTime? tglKal;
  DateTime? tglTerima;

  final namaUmum = <_Cocok>[];

  for (final c in cocok) {
    if (c.bidang == _Bidang.namaUmum) {
      namaUmum.add(c);
      continue;
    }

    final nilai = nilaiDi(c, panjang: c.bidang == _Bidang.alamat);
    if (nilai == null) continue;

    switch (c.bidang) {
      case _Bidang.namaAlat:
        namaAlat ??= teksNilai(nilai.el);
      case _Bidang.merk:
        merk ??= teksNilai(nilai.el);
      case _Bidang.model:
        model ??= teksNilai(nilai.el);
      case _Bidang.seri:
        final t = teksNilai(nilai.el, maks: 60);
        // Seri tanpa satu angka pun dan kurang dari 3 karakter bukan seri.
        if (seri == null &&
            t != null &&
            RegExp(r'\d').hasMatch(t) &&
            kunciSeri(t).length >= 3) {
          seri = t;
        }
      case _Bidang.idAlat:
        idAlat ??= teksNilai(nilai.el, maks: 40);
      case _Bidang.pemilik:
        pemilik ??= teksNilai(nilai.el);
      case _Bidang.alamat:
        alamat ??= teksNilai(nilai.el, maks: 160);
      case _Bidang.lokasi:
        lokasi ??= teksNilai(nilai.el, maks: 80, lokasi: true);
      case _Bidang.tglKalibrasi:
        final t = teksNilai(nilai.el, maks: 30);
        if (t != null) tglKal ??= parseTanggalKertas(t, sekarang: sekarang);
      case _Bidang.tglTerima:
        final t = teksNilai(nilai.el, maks: 30);
        if (t != null) tglTerima ??= parseTanggalKertas(t, sekarang: sekarang);
      case _Bidang.namaUmum:
        break;
    }
  }

  // "Name" bernomor yang dipakai dua kali: di bawah judul OWNER = pemilik,
  // selain itu nama alat. Tanpa judul OWNER: yang pertama alat, yang kedua
  // pemilik.
  for (var n = 0; n < namaUmum.length; n++) {
    final c = namaUmum[n];
    final nilai = nilaiDi(c, panjang: false);
    final t = nilai == null ? null : teksNilai(nilai.el);
    final milikPemilik = yJudulOwner != null ? c.y > yJudulOwner : n >= 1;

    if (milikPemilik) {
      if (t != null) pemilik ??= t;
    } else if (t != null) {
      namaAlat ??= t;
    }
  }

  return IdentitasKertas(
    namaAlat: namaAlat,
    merk: merk,
    model: model,
    seri: seri,
    idAlat: idAlat,
    pemilik: pemilik,
    alamat: alamat,
    lokasi: lokasi,
    tanggalKalibrasi: tglKal,
    tanggalTerima: tglTerima,
  );
}
