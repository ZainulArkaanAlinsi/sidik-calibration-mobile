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
/// **Yang nggak bisa dijamin kelas ini, dan jadi kewajiban pemanggil:** tiga
/// masukannya datang dari luar, jadi tipe-tipenya nggak bisa menegakkan klaim
/// di atas.
///
///  - `lembar` — isi dengan jenis alatnya (`viscometer`, `ph`), JANGAN nama
///    pelanggan, nomor sertifikat, atau nomor seri;
///  - `fieldId` — datang dari `PotonganSel.kotak`, dan itu kode kolom
///    (`pembacaan`, `suhu`), bukan tulisan bebas;
///  - `potongan` — HARUS berasal dari `HasilPetaTabel.kotakSel`, yang kotaknya
///    diturunkan dari jangkar baris & kolom sehingga cuma memuat sel
///    pengukuran. Potongan dari sumber lain bisa saja memuat kop surat atau
///    kolom identitas, dan simpanan ini nggak punya cara memeriksanya.
///
/// Ditulis di sini karena review menunjuknya dengan benar: sampai integrasinya
/// ada, yang menjaga klaim de-identifikasi itu disiplin pemanggil, bukan tipe.
///
/// ## Kenapa dibatasi
///
/// Simpanan yang tumbuh tanpa batas itu HP teknisi yang penuh diam-diam, dan
/// citra pelanggan yang menumpuk makin lama makin banyak kalau perangkatnya
/// hilang. [maksimum] menjaga dua-duanya. Yang paling tua dibuang duluan.
class SimpananContohSel {
  SimpananContohSel(this.folder, {this.maksimum = 5000});

  /// Folder tempat PNG dan indeksnya ditulis. Disuntik dari luar supaya bisa
  /// diuji tanpa perangkat — `path_provider` nggak jalan di test.
  final Directory folder;

  /// Batas jumlah contoh yang disimpan. Lewat dari ini, yang paling tua
  /// dibuang.
  final int maksimum;

  static const _namaIndeks = 'indeks.jsonl';

  /// Antrean tulis — tiap operasi menunggu yang sebelumnya selesai.
  ///
  /// Kenapa perlu, padahal syaratnya sudah ditulis di docblock: menulis satu
  /// contoh itu urutan `buat folder → pilih nama → tulis PNG → tambah baris
  /// indeks → pangkas`, dan pemangkasan MENULIS ULANG seluruh indeks. Dua
  /// panggilan yang jalan bersamaan membaca indeks yang sama, lalu yang
  /// menulis belakangan menimpa baris yang baru saja ditambahkan yang lain.
  /// Contoh latihnya hilang, PNG-nya jadi yatim, dan nggak ada yang merah.
  ///
  /// Sempat cuma didokumentasikan, dengan alasan "kunci bikin kelihatan aman
  /// padahal pemanggil masih bisa salah pakai". Itu keliru, dan review
  /// membantahnya dengan benar: `Future.wait` atas sel-sel satu foto itu
  /// bentuk pemakaian yang WAJAR — justru yang paling mungkin ditulis PR
  /// penyambungan nanti — dan dokumentasi cuma menjaga selama yang menulis
  /// membacanya duluan. Yang nggak bisa dijaga antrean ini cuma satu hal, dan
  /// itu yang pantas didokumentasikan: dua instance yang menunjuk folder yang
  /// sama.
  Future<void> _antre = Future<void>.value();

  File get _indeks => File('${folder.path}/$_namaIndeks');

  /// Jalankan [kerja] sesudah semua yang sudah antre selesai.
  Future<T> _berurutan<T>(Future<T> Function() kerja) {
    final hasil = _antre.then((_) => kerja());

    // Kegagalan satu tulisan NGGAK boleh mematikan antreannya: `_antre` yang
    // membawa error bikin tiap panggilan berikutnya ikut gagal, dan satu
    // berkas yang nggak bisa ditulis berubah jadi seluruh simpanan mati.
    _antre = hasil.then((_) {}, onError: (_) {});

    return hasil;
  }

  /// Simpan satu potongan berikut angka yang diketik teknisi.
  ///
  /// [label] WAJIB berisi. Contoh tanpa label nggak bisa dipakai melatih apa
  /// pun, dan menyimpannya cuma menggelembungkan hitungan dengan sampah yang
  /// kelihatan seperti data.
  ///
  /// Balikin `null` kalau labelnya kosong — ditolak, bukan disimpan diam-diam.
  ///
  /// Aman dipanggil bersamaan — `Future.wait` atas sel-sel satu foto nggak
  /// akan menghilangkan contoh, karena tulisannya diantrekan lewat [_antre].
  ///
  /// **Yang tetap harus dijaga pemanggil: satu folder cuma boleh dipegang
  /// SATU [SimpananContohSel] yang hidup.** Antreannya per-instance, jadi dua
  /// instance yang menunjuk folder sama tetap bisa saling menimpa indeksnya.
  /// Sediakan satu instance bersama lewat provider, jangan bikin baru tiap
  /// kali menyimpan.
  Future<ContohSel?> simpan({
    required PotonganSel potongan,
    required String label,
    required String lembar,
    String? bacaanOcr,
    DateTime? waktu,
  }) {
    // Diperiksa SEBELUM antre: nggak menyentuh berkas apa pun, jadi nggak ada
    // gunanya menahan antrean buat menolaknya.
    if (label.trim().isEmpty) return Future.value(null);

    return _berurutan(
      () => _simpanSatu(
        potongan: potongan,
        label: label,
        lembar: lembar,
        bacaanOcr: bacaanOcr,
        waktu: waktu,
      ),
    );
  }

  Future<ContohSel?> _simpanSatu({
    required PotonganSel potongan,
    required String label,
    required String lembar,
    String? bacaanOcr,
    DateTime? waktu,
  }) async {
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
  ///
  /// Ikut diantrekan supaya nggak pernah membaca indeks yang lagi ditulis
  /// ulang [_pangkas] — di tengah penulisan ulang, indeksnya bisa kebaca
  /// separuh.
  Future<IsiSimpanan> baca() => _berurutan(_bacaLangsung);

  /// Isi [baca] tanpa antre.
  ///
  /// Dipakai dari DALAM operasi yang sudah mengantre ([_pangkas]). Memanggil
  /// [baca] dari sana bikin dia menunggu operasi yang sedang menjalankannya
  /// sendiri — antreannya mengunci diri dan nggak pernah selesai.
  Future<IsiSimpanan> _bacaLangsung() async {
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
  Future<void> kosongkan() => _berurutan(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

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
    final isi = await _bacaLangsung();

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
