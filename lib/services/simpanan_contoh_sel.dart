import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import 'potong_sel_foto.dart';

/// Satu contoh latih: potongan sel berikut angka yang BENAR menurut teknisi.
typedef ContohSel = ({
  /// Nama berkas PNG-nya di dalam folder simpanan.
  String berkas,

  /// Angka yang akhirnya diketik teknisi — inilah target latihnya.
  String label,

  /// Yang dibaca OCR sekarang. Boleh kosong (nggak kebaca), dan boleh BEDA
  /// dari [label] — yang beda justru contoh paling berharga.
  String? bacaanOcr,

  /// Jenis lembar/alatnya, buat menyeimbangkan data. Angka suhu dan angka
  /// viskositas beda rentang dan beda cara ditulis.
  String lembar,

  /// Kolom apa di dalam Repeat (`pembacaan`, `suhu`, …).
  String fieldId,

  DateTime waktu,
});

/// Hasil membaca simpanan, berikut baris indeks yang RUSAK.
///
/// Yang rusak dihitung, bukan dilewat diam-diam. Menelan baris rusak itu pola
/// kegagalan yang sudah pernah menggigit repo ini: indeks yang menyusut
/// sendiri kelihatan seperti data yang memang segitu.
typedef IsiSimpanan = ({List<ContohSel> contoh, int barisRusak});

/// Simpanan contoh latih di dalam HP — bahan model pengenal angka sendiri.
///
/// ## Kenapa labelnya gratis
///
/// Teknisi TETAP mengetik angkanya sekarang, apa pun yang dibaca OCR. Jadi
/// tiap sesi kalibrasi otomatis menghasilkan pasangan (potongan citra, angka
/// benar) — persis bentuk data latih, tanpa ada yang perlu duduk melabeli
/// ribuan gambar. Itu sebabnya proyek ini masuk akal padahal nggak punya
/// dataset sama sekali di awal.
///
/// Yang paling berharga justru yang OCR-nya SALAH atau kosong: di situlah
/// model sekarang gagal, dan di situ pula yang perlu dipelajari. Makanya
/// [ContohSel.bacaanOcr] ikut disimpan, bukan cuma labelnya.
///
/// ## Privasi
///
/// **Nggak ada yang keluar dari HP.** Kelas ini cuma menulis ke folder privat
/// aplikasi. Ekspor keluar perangkat butuh keputusan eksplisit pemilik lab dan
/// belum dibangun sama sekali — lihat
/// `.claude/skills/sidik-fe-ocr-privasi-audit`.
///
/// Yang disimpan pun sengaja **nggak bisa ditelusuri balik ke pelanggan**:
/// nggak ada id sesi, nama pelanggan, nomor sertifikat, maupun nomor seri alat
/// di sini. Potongannya sendiri cuma memuat sel pengukuran di dalam tabel —
/// [PetaTabelFoto] menurunkan kotaknya dari jangkar baris & kolom, jadi kop
/// surat dan kolom identitas nggak pernah ikut terpotong.
///
/// Itu keputusan yang disengaja, bukan kelalaian mencatat: kalau nanti pemilik
/// lab mengizinkan potongan diekspor buat pelatihan, yang keluar sudah berupa
/// coretan angka tanpa konteks — bukan lembar kerja pelanggan.
///
/// ## Kenapa dibatasi
///
/// Simpanan yang tumbuh tanpa batas itu HP teknisi yang penuh diam-diam, dan
/// citra pelanggan yang menumpuk makin lama makin banyak kalau perangkatnya
/// hilang. [maksimum] menjaga dua-duanya. Yang paling tua dibuang duluan.
class SimpananContohSel {
  const SimpananContohSel(this.folder, {this.maksimum = 5000});

  /// Folder tempat PNG dan indeksnya ditulis. Disuntik dari luar supaya bisa
  /// diuji tanpa perangkat — `path_provider` nggak jalan di test.
  final Directory folder;

  /// Batas jumlah contoh yang disimpan. Lewat dari ini, yang paling tua
  /// dibuang.
  final int maksimum;

  static const _namaIndeks = 'indeks.jsonl';

  File get _indeks => File('${folder.path}/$_namaIndeks');

  /// Simpan satu potongan berikut angka yang diketik teknisi.
  ///
  /// [label] WAJIB berisi. Contoh tanpa label nggak bisa dipakai melatih apa
  /// pun, dan menyimpannya cuma menggelembungkan hitungan dengan sampah yang
  /// kelihatan seperti data.
  ///
  /// Balikin `null` kalau labelnya kosong — ditolak, bukan disimpan diam-diam.
  ///
  /// ## WAJIB dipanggil BERURUTAN, satu per satu
  ///
  /// `await` tiap panggilan sebelum memanggil lagi. **Jangan** `Future.wait`
  /// atas sekumpulan sel sekaligus.
  ///
  /// Alasannya: [_pangkas] membaca indeks, menghitung yang lebih, lalu
  /// menulis ULANG seluruh indeks. Dua panggilan yang jalan bersamaan
  /// membaca indeks yang sama, lalu yang menulis belakangan menimpa baris
  /// yang baru saja ditambahkan yang lain — contoh latihnya hilang, PNG-nya
  /// jadi yatim, dan nggak ada yang merah.
  ///
  /// Sengaja NGGAK dikunci di dalam sini: satu foto menghasilkan puluhan sel
  /// yang memang wajar ditulis berurutan, dan kunci di kelas ini cuma bikin
  /// kelihatan aman padahal pemanggil masih bisa salah pakai. Yang menjaga
  /// syarat ini pemanggilnya, dan syaratnya ditulis di sini supaya nggak
  /// ketemu belakangan lewat data yang hilang.
  Future<ContohSel?> simpan({
    required PotonganSel potongan,
    required String label,
    required String lembar,
    String? bacaanOcr,
    DateTime? waktu,
  }) async {
    if (label.trim().isEmpty) return null;

    await folder.create(recursive: true);

    final saat = waktu ?? DateTime.now();
    final nama = await _namaBerkasBaru(saat);

    await File(
      '${folder.path}/$nama',
    ).writeAsBytes(img.encodePng(potongan.potongan));

    final contoh = (
      berkas: nama,
      label: label.trim(),
      bacaanOcr: bacaanOcr,
      lembar: lembar,
      fieldId: potongan.kotak.fieldId,
      waktu: saat,
    );

    await _indeks.writeAsString(
      '${jsonEncode(_keJson(contoh))}\n',
      mode: FileMode.append,
    );

    await _pangkas();

    return contoh;
  }

  /// Semua contoh yang tersimpan, urut dari yang paling tua.
  Future<IsiSimpanan> baca() async {
    if (!await _indeks.exists()) {
      return (contoh: const <ContohSel>[], barisRusak: 0);
    }

    final contoh = <ContohSel>[];
    var rusak = 0;

    for (final baris in await _indeks.readAsLines()) {
      if (baris.trim().isEmpty) continue;

      final satu = _dariJson(baris);

      if (satu == null) {
        rusak++;
        continue;
      }

      contoh.add(satu);
    }

    return (contoh: contoh, barisRusak: rusak);
  }

  /// Buang seluruh simpanan — berkas PNG berikut indeksnya.
  Future<void> kosongkan() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  /// Nama berkas yang dijamin belum dipakai.
  ///
  /// Stempel waktu saja nggak cukup: dua sel dari foto yang sama disimpan
  /// dalam milidetik yang sama, dan yang kedua bakal menimpa yang pertama —
  /// contoh latih hilang tanpa ada yang tahu.
  Future<String> _namaBerkasBaru(DateTime saat) async {
    final dasar = saat.microsecondsSinceEpoch;

    for (var i = 0; ; i++) {
      final nama = i == 0 ? 'sel_$dasar.png' : 'sel_${dasar}_$i.png';

      if (!await File('${folder.path}/$nama').exists()) return nama;
    }
  }

  /// Buang yang paling tua sampai jumlahnya kembali di bawah [maksimum].
  Future<void> _pangkas() async {
    final isi = await baca();

    final lebih = isi.contoh.length - maksimum;
    if (lebih <= 0) return;

    final dibuang = isi.contoh.take(lebih);

    for (final c in dibuang) {
      final berkas = File('${folder.path}/${c.berkas}');
      if (await berkas.exists()) await berkas.delete();
    }

    // Indeksnya ditulis ULANG, bukan ditambahi penanda hapus: indeks yang
    // menyimpan baris buat berkas yang sudah nggak ada bikin `baca()`
    // memulangkan contoh yang citranya hilang, dan itu baru meledak jauh di
    // tahap latih.
    await _indeks.writeAsString(
      isi.contoh.skip(lebih).map((c) => jsonEncode(_keJson(c))).join('\n') +
          (isi.contoh.length > lebih ? '\n' : ''),
    );
  }

  Map<String, Object?> _keJson(ContohSel c) => {
    'berkas': c.berkas,
    'label': c.label,
    'bacaan_ocr': c.bacaanOcr,
    'lembar': c.lembar,
    'field_id': c.fieldId,
    'waktu': c.waktu.toIso8601String(),
  };

  /// Balikin `null` kalau barisnya nggak bisa dibaca — pemanggil yang
  /// menghitungnya, biar yang rusak nggak hilang diam-diam.
  ContohSel? _dariJson(String baris) {
    try {
      final j = jsonDecode(baris);
      if (j is! Map<String, Object?>) return null;

      final berkas = j['berkas'];
      final label = j['label'];
      final lembar = j['lembar'];
      final fieldId = j['field_id'];
      final waktu = DateTime.tryParse('${j['waktu']}');

      if (berkas is! String ||
          label is! String ||
          lembar is! String ||
          fieldId is! String ||
          waktu == null) {
        return null;
      }

      final ocr = j['bacaan_ocr'];

      return (
        berkas: berkas,
        label: label,
        bacaanOcr: ocr is String ? ocr : null,
        lembar: lembar,
        fieldId: fieldId,
        waktu: waktu,
      );
    } on FormatException {
      return null;
    }
  }
}
