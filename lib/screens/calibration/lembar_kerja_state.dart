import 'package:flutter/widgets.dart';

import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/lembar_kerja.dart';
import '../../models/lembar_kerja_submission.dart';
import '../../services/worksheet_vision.dart';

/// Angka di lembar kerja diketik teknisi lapangan, yang kadang pakai koma
/// (`22,2`) karena itu yang dipakai di formulir kertasnya. Dua-duanya
/// diterima; yang dikirim ke backend selalu titik.
double? parseAngka(String teks) =>
    double.tryParse(teks.trim().replaceAll(',', '.'));

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
  }) : _kotak = {};

  final double titikUkur;
  final String label;
  final int jumlahPengulangan;
  final String satuan;

  /// Standar buffer khusus titik ini (buffer 4/7/10 beda-beda).
  int? standardId;

  /// Kunci: `tahap|kolom|indexPengulangan`.
  final Map<String, TextEditingController> _kotak;

  TextEditingController kotak(String tahap, String kolom, int index) =>
      _kotak.putIfAbsent('$tahap|$kolom|$index', TextEditingController.new);

  /// Sudah ada isian apa pun di baris ini?
  bool get adaIsian =>
      _kotak.values.any((c) => c.text.trim().isNotEmpty) || standardId != null;

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
    DateTime? tanggalKalibrasiAwal,
  }) {
    // Tanggal kalibrasi dikasih nilai awal HARI INI, bukan dibiarin kosong.
    // Ini satu-satunya kolom yang backend tolak kalau kosong waktu dikirim ke
    // admin (`required` di luar draft) — dan bikin teknisi kena 422 gara-gara
    // kolom yang jawabannya hampir selalu "hari ini" itu cuma bikin kesel.
    // Masih bisa dikosongin manual kalau dia mau nyimpen draft.
    tanggal['tanggal_kalibrasi'] = tanggalKalibrasiAwal ?? DateTime.now();

    for (final bagian in bentuk.bagian) {
      for (final f in bagian.field) {
        if (f.turunan) continue;
        if (f.tipe == TipeField.teks ||
            f.tipe == TipeField.teksPanjang ||
            f.tipe == TipeField.angka) {
          teks.putIfAbsent(f.kode, TextEditingController.new);
        }
      }

      for (final t in bagian.tabel) {
        for (final b in t.baris) {
          titik.putIfAbsent(
            b.titikUkur,
            () => TitikState(
              titikUkur: b.titikUkur,
              label: b.label,
              jumlahPengulangan: t.pengulangan.length,
              satuan: bentuk.satuan,
            ),
          );
        }
      }
    }
  }

  final LembarKerja bentuk;
  final String clientRequestId;

  EquipmentLookup? alat;
  LokasiKalibrasi lokasi = LokasiKalibrasi.lab;
  int? roomId;
  int? standardId;

  /// Kolom administratif — cuma kebentuk kalau backend ngirimin bagiannya
  /// (yaitu waktu yang login admin).
  int? calibrationMethodId;
  int? thermohygroStandardId;

  final Map<String, TextEditingController> teks = {};
  final Map<String, DateTime?> tanggal = {};

  /// Keyed by nilai larutan standar (4.00 / 7.00 / 10.01).
  final Map<double, TitikState> titik = {};

  /// Sel yang diisi AI dengan **keyakinan rendah** — ditandai di layar biar
  /// teknisi ngecek angka itu saja, bukan seluruh tabel (spec vision §4.1).
  /// Kuncinya [kunciSel]. Dibersihin kalau selnya diisi ulang dengan keyakinan
  /// bagus di foto berikutnya.
  final Set<String> selRendahKeyakinan = {};

  /// Kunci satu sel tabel — sama persis dengan yang dibangun widget tabel biar
  /// penandaan keyakinan-rendah nyambung ke kotak yang benar.
  static String kunciSel(double titikUkur, String tahap, String kolom, int index) =>
      '$titikUkur|$tahap|$kolom|$index';

  final Map<int, UsageCheckState> usageCheck = {};

  UsageCheckState usage(int standardId) => usageCheck.putIfAbsent(
    standardId,
    () => UsageCheckState(standardId: standardId),
  );

  double? angka(String kode) {
    final c = teks[kode];
    return c == null ? null : parseAngka(c.text);
  }

  String? kalimat(String kode) {
    final t = teks[kode]?.text.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Ada yang udah diketik sama sekali? Dipakai buat konfirmasi waktu teknisi
  /// nekan back — bukan buat nahan tombol kirim.
  bool get adaIsian =>
      alat != null ||
      roomId != null ||
      standardId != null ||
      teks.values.any((c) => c.text.trim().isNotEmpty) ||
      titik.values.any((t) => t.adaIsian) ||
      usageCheck.values.any((u) => u.adaIsian);

  /// Susun payload. **Nggak ada validasi di sini** — apa pun kondisinya, isian
  /// yang ada dikirim apa adanya. Yang nahan sertifikat terbit itu pemeriksaan
  /// admin, bukan formulirnya.
  LembarKerjaSubmission toSubmission({required bool draft}) {
    // Baris yang sama sekali belum disentuh tetap ikut dikirim: backend nyimpen
    // titiknya mentah (nggak dihitung) dan itu yang bikin lembar kerja setengah
    // jadi tetap kebaca utuh sama admin — kolom mana yang kosong kelihatan,
    // bukan ilang dari tabel.
    final measurements = titik.values.map((t) => t.toSubmission()).toList()
      ..sort((a, b) => a.titikUkur.compareTo(b.titikUkur));

    return LembarKerjaSubmission(
      equipmentId: alat!.id,
      clientRequestId: clientRequestId,
      simpanSebagaiDraft: draft,
      standardId: standardId,
      roomId: roomId,
      lokasi: lokasi,
      tanggalKalibrasi: tanggal['tanggal_kalibrasi'],
      tanggalTerima: tanggal['tanggal_terima'],
      suhuAwal: angka('suhu_awal'),
      suhuAkhir: angka('suhu_akhir'),
      kelembabanAwal: angka('kelembaban_awal'),
      kelembabanAkhir: angka('kelembaban_akhir'),
      catatanTeknisi: kalimat('catatan_teknisi'),
      standarDicek: usageCheck.values
          .where((u) => u.adaIsian)
          .map((u) => u.toSubmission())
          .toList(),
      measurements: measurements,
    );
  }

  /// Titik diurut naik (4 / 7 / 10,01) — urutan yang sama dipakai parser OCR
  /// waktu misahin kolom, dan urutan yang dikirim ke backend.
  List<TitikState> get titikUrut =>
      titik.values.toList()..sort((a, b) => a.titikUkur.compareTo(b.titikUkur));

  /// Berapa sel yang bisa diisi satu tabel — buat pesan "x dari y sel".
  /// Dua kolom per pengulangan: pH & °C.
  int get selPerTabel =>
      titikUrut.fold(0, (jumlah, t) => jumlah + t.jumlahPengulangan * 2);

  /// Tempelin hasil baca tabel worksheet ke kolom satu tahap. Balikin jumlah
  /// sel yang beneran keisi.
  ///
  /// **Cuma sel kosong yang diisi.** Ini aturan intinya: teknisi boleh foto
  /// ulang berkali-kali buat nambal yang kurang, dan angka yang udah dia
  /// betulin manual nggak boleh keganti sama hasil foto berikutnya. Aturan
  /// per-selnya ada di [GabungTabel.nilaiBaru], bukan di sini — biar bisa
  /// diuji tanpa kamera.
  ///
  /// Bentuk [hasil]: `baris[pengulangan].ph[titik]` — **baris itu Repeat 1..5**,
  /// isinya satu angka per larutan standar. Gampang kebalik, makanya nama
  /// variabelnya ditulis panjang di bawah.
  int terapkanHasilEkstraksi(HasilEkstraksiTabel hasil, {required String tahap}) {
    final urut = titikUrut;
    var terisi = 0;

    for (var pengulangan = 0; pengulangan < hasil.baris.length; pengulangan++) {
      final baris = hasil.baris[pengulangan];

      for (var t = 0; t < urut.length; t++) {
        final state = urut[t];
        if (pengulangan >= state.jumlahPengulangan) continue;

        terisi += _isiSel(
          state,
          tahap,
          'pembacaan',
          pengulangan,
          t < baris.ph.length ? baris.ph[t] : null,
          baris.keyakinanPh(t),
        );
        terisi += _isiSel(
          state,
          tahap,
          'suhu',
          pengulangan,
          t < baris.suhu.length ? baris.suhu[t] : null,
          baris.keyakinanSuhu(t),
        );
      }
    }

    return terisi;
  }

  int _isiSel(
    TitikState state,
    String tahap,
    String kolom,
    int index,
    double? nilai,
    TingkatKeyakinan keyakinan,
  ) {
    final kotak = state.kotak(tahap, kolom, index);
    final baru = GabungTabel.nilaiBaru(kotak.text, nilai);
    if (baru == null) return 0;

    kotak.text = baru;

    // Sel yang keyakinannya rendah ditandai; kalau foto ulang mengisinya dengan
    // keyakinan bagus, tandanya dilepas.
    final kunci = kunciSel(state.titikUkur, tahap, kolom, index);
    if (keyakinan.perluDicek) {
      selRendahKeyakinan.add(kunci);
    } else {
      selRendahKeyakinan.remove(kunci);
    }
    return 1;
  }

  /// Isi kolom yang ditandai `sumber: otomatis` di formulir. Kode-nya bertitik
  /// (`equipment.merk`), jadi nggak pernah jadi kunci payload — murni tampilan.
  String nilaiTurunan(String kode, {String? namaTeknisi, String? namaReviewer}) {
    return switch (kode) {
      'equipment.nama_alat' => alat?.namaAlat ?? '',
      'equipment.range_resolusi' => alat?.rangeResolusi ?? '',
      'equipment.model' => alat?.model ?? '',
      'equipment.serial_number' => alat?.serialNumber ?? '',
      'equipment.merk' => alat?.merk ?? '',
      'customer.nama' => alat?.pelangganNama ?? '',
      'customer.alamat' => alat?.pelangganAlamat ?? '',
      'teknisi.nama' => namaTeknisi ?? '',
      // "Checked by" sengaja kosong sampai admin nyetujuin — biar nggak ada
      // yang bisa ngaku-ngaku udah diperiksa.
      'reviewer.nama' => namaReviewer ?? '',
      _ => '',
    };
  }

  void dispose() {
    for (final c in teks.values) {
      c.dispose();
    }
    for (final t in titik.values) {
      t.dispose();
    }
    for (final u in usageCheck.values) {
      u.dispose();
    }
  }
}
