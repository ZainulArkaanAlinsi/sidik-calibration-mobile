import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/arsip.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart'
    show Keputusan;

/// Parser Arsip diadu ke **payload ASLI server**, bukan ke objek buatan mock.
///
/// ## Kenapa berkas ini ada
///
/// Sampai 27 Agt 2026 `ArsipIsiFolder.fromJson` membaca bentuk yang sama sekali
/// beda dari yang dikirim server: `json['folder']`, `json['subfolder']`, dan
/// `json['data']` sebagai daftar berkas. Nggak satu pun kunci itu ada. Yang
/// paling menentukan: `json['data']` yang sebenarnya OBJEK bikin `as List`
/// ngelempar `TypeError`, jadi **tiap folder yang dibuka lawan server asli
/// gagal** dan layarnya berhenti di pesan error.
///
/// Nggak ada satu pun test yang nangkep itu, dan alasannya bukan kebetulan:
/// seluruh test arsip lewat `MockArsipService`, yang bikin `ArsipIsiFolder`
/// lewat konstruktor. Parser-nya nggak pernah sekali pun dilewati. Mock yang
/// bikin objek jadi, bukan JSON, memang nggak bisa menguji pembacaan JSON.
///
/// `fixtures/arsip_isi_folder.json` itu **rekaman respons sungguhan** dari
/// `GET /api/arsip/folders/{id}` (folder tahun berisi 1 subfolder + 1 lembar
/// kerja, di bawah folder akar PT). Cara memperbaruinya kalau kontraknya
/// berubah: jalankan endpointnya di repo API dan tempel ulang JSON-nya.
void main() {
  Map<String, dynamic> muat([String nama = 'arsip_isi_folder']) => jsonDecode(
    File('test/fixtures/$nama.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('payload asli keparse, bukan ngelempar', () {
    // Bentuk penjagaan yang paling penting di berkas ini: kalau bentuknya
    // berubah lagi, yang merah duluan baris ini — bukan teknisi di lapangan.
    expect(() => ArsipIsiFolder.fromJson(muat()), returnsNormally);
  });

  group('isi folder', () {
    late ArsipIsiFolder isi;

    setUp(() => isi = ArsipIsiFolder.fromJson(muat()));

    test('identitas folder kebaca dari envelope `data`', () {
      expect(isi.folderId, 2);
      expect(isi.namaFolder, '2026');
      expect(isi.namaPerusahaan, 'PT Alfa');
    });

    test('is_root diturunkan dari parent_id, bukan diminta ke server', () {
      // Folder "2026" induknya folder akar PT, jadi dia BUKAN akar.
      expect(isi.isRoot, isFalse);

      // Dan ini yang bikin bedanya kelihatan: server NGGAK PERNAH ngirim kunci
      // `is_root`. Dibaca dari situ, folder akar pun jawabannya `false` —
      // sama dengan folder biasa, jadi nggak ada yang bisa membedakannya.
      final akar = muat('arsip_folder_akar');
      expect(
        (akar['data'] as Map).containsKey('is_root'),
        isFalse,
        reason: 'kalau server mulai ngirim `is_root`, catatan ini perlu diralat',
      );
      expect(ArsipIsiFolder.fromJson(akar).isRoot, isTrue);
    });

    test('subfolder dari `sub_folder`, bukan `subfolder`', () {
      expect(isi.subfolder, hasLength(1));
      expect(isi.subfolder.single.nama, 'Revisi');
    });

    test('berkas dari `file`, dan foldernya nggak kebaca kosong', () {
      expect(isi.berkas, hasLength(1));
      expect(isi.kosong, isFalse);
    });

    test('breadcrumb akar → folder yang dibuka', () {
      // Nggak bisa diturunkan di HP: nama folder induk ada di baris induk yang
      // nggak ikut terkirim. Tanpa ini satu-satunya jalan keluar dari folder
      // dalam itu tombol back beruntun.
      expect(isi.breadcrumb.map((b) => b.nama).toList(), ['PT Alfa', '2026']);
      expect(isi.breadcrumb.first.isRoot, isTrue);
      expect(isi.breadcrumb.last.isRoot, isFalse);
    });
  });

  group('satu baris berkas', () {
    late ArsipBerkas berkas;

    setUp(() => berkas = ArsipIsiFolder.fromJson(muat()).berkas.single);

    test('`id` itu id SESI KALIBRASI, bukan id baris folder_files', () {
      // Yang menentukan sesi mana yang kebuka waktu kartunya dipencet, dan
      // yang dikirim ke `PUT /arsip/berkas/{sesiId}/pindah`.
      //
      // Fixture-nya sengaja dibikin dengan id yang BEDA (berkas 1, sesi 5).
      // Waktu dua-duanya kebetulan sama, jalur yang salah kelihatan jalan
      // mulus — dan itu yang bikin bug begini bertahan.
      final file = (muat()['data'] as Map)['file'] as List;
      final baris = file.single as Map;
      final idBerkas = baris['id'] as int;
      final idSesi = (baris['lembar_kerja'] as Map)['calibration_session_id'] as int;

      expect(idBerkas, isNot(idSesi), reason: 'fixture-nya harus bisa membedakan');
      expect(berkas.id, idSesi);
      expect(berkas.id, isNot(idBerkas));
    });

    test('empat field kartu datang dari blok lembar_kerja', () {
      // Nggak satu pun bisa diturunkan dari baris `folder_files` — di situ cuma
      // ada nama berkas dan penunjuk sesinya. Tanpa keempatnya kartu arsip
      // berhenti menjawab "alat mana, lulus apa nggak".
      expect(berkas.namaAlat, 'Thermocouple Fluke 51-II');
      expect(berkas.namaTeknisi, 'Budi Teknisi');
      expect(berkas.keputusan, Keputusan.pass);
      expect(berkas.tanggalKalibrasi, DateTime.parse('2026-08-26'));
    });

    test('baris tanpa sesi dibuang, bukan dikasih id berkas', () {
      // Sertifikat unggahan & berkas manual nggak punya sesi. Menyimpannya
      // dengan id berkas bikin kartunya kelihatan bisa dipencet lalu membuka
      // sesi yang salah — persis kegagalan yang lagi dicegah.
      final mentah = muat();
      final file = (mentah['data'] as Map)['file'] as List;
      (file.single as Map)['lembar_kerja'] = null;

      final isi = ArsipIsiFolder.fromJson(mentah);

      expect(isi.berkas, isEmpty);
      // Barisnya hilang diam-diam lewat `parseListAman` — itu disengaja, tapi
      // subfoldernya harus tetap utuh, bukan ikut kebuang.
      expect(isi.subfolder, hasLength(1));
    });
  });
}
