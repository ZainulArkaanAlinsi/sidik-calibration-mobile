import '../../models/lembar_kerja.dart';
import 'lembar_kerja_state.dart';

/// Jenis satu butir di dialog "Ringkasan sebelum kirim".
///
/// [menahan] `true` = gerbang yang SUDAH ADA di `LembarKerjaScreen._submit`
/// (alat belum dipilih, suhu, standar belum dicentang, setpoint, jam): kirim
/// tetap ditahan. `false` = peringatan: teknisi boleh "Tetap kirim".
enum JenisButirRingkasan {
  alatBelumDipilih(menahan: true),
  suhuBelumLengkap(menahan: true),
  standarBelumDicentang(menahan: true),
  setPointKosong(menahan: true),
  jamTidakTerbaca(menahan: true),
  identitasKosong(menahan: false),
  ocrPerluDicek(menahan: false);

  const JenisButirRingkasan({required this.menahan});

  final bool menahan;
}

/// Satu butir ringkasan.
class ButirRingkasan {
  const ButirRingkasan({
    required this.jenis,
    this.label = '',
    this.jumlah = 0,
    this.lompat,
  });

  final JenisButirRingkasan jenis;

  /// Teks yang disebut pesan: label kolom (identitas) atau daftar titik/kolom
  /// yang bermasalah (`4,00, 7,00`) — persis yang disebut gerbang aslinya.
  final String label;

  /// Hanya dipakai [JenisButirRingkasan.ocrPerluDicek]: jumlah sel.
  final int jumlah;

  /// Kode sasaran lompat (kode kolom, atau [kodeLompatBagian]); `null` = tidak
  /// ada tempat yang bisa dituju.
  final String? lompat;
}

/// Hasil menyusun ringkasan dari isian saat ini.
class RingkasanSebelumKirim {
  const RingkasanSebelumKirim({
    required this.butir,
    required this.titikTerisi,
    required this.titikTotal,
  });

  final List<ButirRingkasan> butir;

  /// Titik (baris tabel) yang sudah ada pembacaannya, dari [titikTotal].
  /// `titikTotal == 0` = lembar ini tidak punya titik bertabel (grid/matriks).
  final int titikTerisi;
  final int titikTotal;

  List<ButirRingkasan> get wajib => [
    for (final b in butir)
      if (b.jenis.menahan) b,
  ];

  List<ButirRingkasan> get peringatan => [
    for (final b in butir)
      if (!b.jenis.menahan) b,
  ];

  /// Ada gerbang yang menahan kirim.
  bool get menahan => butir.any((b) => b.jenis.menahan);

  /// Ada sesuatu yang perlu ditunjukkan. `false` = kirim langsung seperti
  /// sebelum fitur ini ada — jalur cepat tidak boleh melambat.
  ///
  /// Jumlah titik terisi sengaja TIDAK memicu dialog: lembar setengah jadi
  /// memang boleh dikirim dari lapangan, dan dialog yang muncul tiap kali
  /// cuma melatih jempol menekan lanjut tanpa membaca.
  bool get adaKekurangan => butir.isNotEmpty;
}

/// Sasaran lompat untuk satu bagian lembar (kartu).
String kodeLompatBagian(BagianLembarKerja b) => 'bagian:${b.kode}';

/// Nomor halaman (`BagianLembarKerja.halaman`) tempat [sasaran] digambar, atau
/// `null` kalau tidak ketemu di bentuk ini.
int? halamanSasaranLompat(LembarKerja bentuk, String sasaran) {
  for (final b in bentuk.bagian) {
    if (sasaran == kodeLompatBagian(b)) return b.halaman;
    if (b.field.any((f) => f.kode == sasaran)) return b.halaman;
  }

  return null;
}

/// Menyusun ringkasan dari [s]. Hanya MEMBACA — tidak mengubah isian, tidak
/// menyentuh perhitungan/payload.
///
/// Gerbang (`menahan`) memakai getter yang SAMA dengan yang dipakai
/// `LembarKerjaScreen._submit`, jadi dialog dan gerbang tidak bisa berbeda
/// pendapat. Gerbang di `_submit` tetap ada sebagai jaring terakhir.
RingkasanSebelumKirim susunRingkasanSebelumKirim(LembarKerjaState s) {
  final butir = <ButirRingkasan>[];
  final bentuk = s.bentuk;

  final bagianTabel = bentuk.bagian
      .where((b) => !b.belumBisaDiisi && b.tabel.isNotEmpty)
      .firstOrNull;
  final lompatTabel = bagianTabel == null
      ? null
      : kodeLompatBagian(bagianTabel);

  String daftar(Iterable<TitikState> titik) =>
      titik.map((t) => t.label).join(', ');

  // --- (a) Gerbang yang menahan kirim -------------------------------------

  if (s.alat == null) {
    final kolomAlat = bentuk.bagian
        .expand((b) => b.field)
        .where((f) => f.sumber == SumberField.masterAlat)
        .firstOrNull;
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.alatBelumDipilih,
        lompat: kolomAlat?.kode,
      ),
    );
  }

  final tanpaSuhu = s.titikSuhuBelumLengkap;
  if (tanpaSuhu.isNotEmpty) {
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.suhuBelumLengkap,
        label: daftar(tanpaSuhu),
        lompat: lompatTabel,
      ),
    );
  }

  final yatim = s.titikTerisiTanpaStandar;
  if (yatim.isNotEmpty) {
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.standarBelumDicentang,
        label: daftar(yatim),
        lompat: lompatTabel,
      ),
    );
  }

  final tanpaSetPoint = s.titikTanpaSetPoint;
  if (tanpaSetPoint.isNotEmpty) {
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.setPointKosong,
        label: daftar(tanpaSetPoint),
        lompat: lompatTabel,
      ),
    );
  }

  final jamNgawur = s.jamMatriksNgawur();
  if (jamNgawur.isNotEmpty) {
    final bagianMatriks = s.bagianMatriks;
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.jamTidakTerbaca,
        label: jamNgawur.join(', '),
        lompat: bagianMatriks == null ? null : kodeLompatBagian(bagianMatriks),
      ),
    );
  }

  // --- (b) Identitas yang kosong: peringatan, tidak menahan ---------------

  for (final f in _identitasKosong(s)) {
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.identitasKosong,
        label: f.label,
        lompat: f.kode,
      ),
    );
  }

  // --- (c) Sel hasil pindai dengan vonis kuning/merah ---------------------

  final ocr = _selPindaiPerluDicek(s);
  if (ocr.isNotEmpty) {
    butir.add(
      ButirRingkasan(
        jenis: JenisButirRingkasan.ocrPerluDicek,
        label: daftar(ocr.keys),
        jumlah: ocr.values.fold(0, (a, b) => a + b),
        lompat: lompatTabel,
      ),
    );
  }

  // --- (e) Hitungan titik --------------------------------------------------

  final hitungan = _hitungTitik(s);

  return RingkasanSebelumKirim(
    butir: butir,
    titikTerisi: hitungan.terisi,
    titikTotal: hitungan.total,
  );
}

/// Kolom identitas tercetak (`peranIsianIdentitas`) yang digambar di layar dan
/// masih kosong. Aturan "terisi"-nya sama dengan yang mewarnai kotaknya
/// (`_Readonly`, `_Isian`, `_PilihTanggal`, `_PilihanUmum`).
List<FieldLembarKerja> _identitasKosong(LembarKerjaState s) {
  // Alat belum dipilih: semua identitas kosong karena belum diisi awal dari
  // master alat — itu sudah dilaporkan SEKALI sebagai "alat belum dipilih",
  // dan menderetkan sepuluh kolom di bawahnya cuma menenggelamkan satu hal
  // yang sebenarnya menahan kirim.
  if (s.alat == null) return const [];

  final hasil = <FieldLembarKerja>[];
  final terlihat = <String>{};

  for (final bagian in s.bentuk.bagian) {
    if (bagian.belumBisaDiisi) continue;

    for (final f in bagian.field) {
      if (!s.fieldIdentitas(f) || !s.fieldTampil(f)) continue;
      if (!terlihat.add(f.kode)) continue;

      if (_identitasTerisi(s, f) == false) hasil.add(f);
    }
  }

  return hasil;
}

/// `null` = kolom ini tidak punya kotak isian di layar (tidak diperiksa).
bool? _identitasTerisi(LembarKerjaState s, FieldLembarKerja f) {
  // Otomatis dari alat yang sudah dipilih (nama, merek, tipe, seri, pelanggan).
  if (f.sumber.readOnly) return s.nilaiTurunan(f.kode).trim().isNotEmpty;

  // Selalu punya nilai (bawaan Inlab).
  if (f.kode == 'lokasi') return true;

  if (f.tipe == TipeField.tanggal) return s.tanggal[f.kode] != null;

  final kotak = s.teks[f.kode];
  if (kotak == null) return null;

  final nilai = kotak.text.trim();

  if (f.tipe == TipeField.pilihan && f.pilihan.isNotEmpty) {
    return f.pilihan.any((p) => p.nilai == nilai);
  }

  return nilai.isNotEmpty;
}

/// Titik -> jumlah sel terisi yang ditandai pindai kuning/merah
/// (`LembarKerjaState.selRendahKeyakinan`). Sel yang sudah dikosongkan teknisi
/// tidak dihitung: tidak ada angka yang perlu dicek.
Map<TitikState, int> _selPindaiPerluDicek(LembarKerjaState s) {
  final hasil = <TitikState, int>{};

  for (final kunci in s.selRendahKeyakinan) {
    final bagian = kunci.split('|');
    if (bagian.length != 4) continue;

    final titikUkur = double.tryParse(bagian[0]);
    final index = int.tryParse(bagian[3]);
    if (titikUkur == null || index == null) continue;

    final state = s.titik[titikUkur];
    if (state == null) continue;

    final isi = state.teksKotakJikaAda(bagian[1], bagian[2], index);
    if (isi == null || isi.trim().isEmpty) continue;

    hasil[state] = (hasil[state] ?? 0) + 1;
  }

  // Urut menurut titik, bukan urutan masuk set.
  final urut = hasil.keys.toList()
    ..sort((a, b) => a.titikUkur.compareTo(b.titikUkur));

  return {for (final t in urut) t: hasil[t]!};
}

/// Titik terisi vs total. Blok spesifikasi (bukan titik ukur) dan titik
/// nonaktif tidak dihitung; dua varian satuan untuk botol yang sama
/// (`eksklusifDengan`) dihitung SATU titik.
({int terisi, int total}) _hitungTitik(LembarKerjaState s) {
  final bukanTitik = s.kunciTitikSpesifikasi;
  var terisi = 0;
  var total = 0;

  for (final e in s.titik.entries) {
    if (bukanTitik.contains(e.key)) continue;

    final t = e.value;
    if (s.titikStateNonaktif(t)) continue;

    var ada = t.adaPembacaan;

    final pasangan = t.eksklusifDengan == null
        ? null
        : s.titik[t.eksklusifDengan];
    if (pasangan != null) {
      // Pasangan dihitung sekali, lewat anggota yang nilainya lebih kecil.
      if (t.titikUkur > pasangan.titikUkur) continue;
      ada = ada || pasangan.adaPembacaan;
    }

    total++;
    if (ada) terisi++;
  }

  return (terisi: terisi, total: total);
}
