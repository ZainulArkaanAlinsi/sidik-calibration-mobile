import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/arsip.dart';
import 'package:sidik_calibration/providers/arsip_provider.dart';
import 'package:sidik_calibration/services/arsip_service.dart';

/// Daftar akar Arsip — dan dua id yang datang dari situ.
///
/// `GET /api/arsip/perusahaan` me-list **FOLDER**, bukan pelanggan. `json['id']`
/// itu id folder; id pelanggannya ada di `json['pelanggan']['id']`. Rute yang
/// membuka arsip satu PT (`/arsip/perusahaan/{customer}/folder`) ngiket ke
/// `Customer`, jadi ngasih id folder ke situ **membuka arsip PT LAIN** yang
/// id-nya kebetulan sama — status 200, nol error, dan yang kelihatan di layar
/// sertifikat milik pelanggan lain.
///
/// Bukan bahaya teoretis: folder akar PT dibikin belakangan dan urutannya nggak
/// ikut urutan pelanggan, jadi dua id itu memang sering beda. Di uji tiga PT,
/// dua di antaranya kebuka arsip PT lain.
void main() {
  Map<String, dynamic> baris({
    required int idFolder,
    int? idPelanggan,
    String? alamat,
  }) => {
    'id': idFolder,
    'nama': 'PT Contoh',
    'jumlah_alat': 3,
    'jumlah_sertifikat': 2,
    if (idPelanggan != null)
      'pelanggan': {
        'id': idPelanggan,
        'nama': 'PT Contoh',
        'alamat': ?alamat,
      },
  };

  group('id folder dan id pelanggan dibedain', () {
    test('id pelanggan dibaca dari `pelanggan.id`, bukan dari `id`', () {
      final p = ArsipPerusahaan.fromJson(baris(idFolder: 3, idPelanggan: 1));

      expect(p.id, 3, reason: '`id` tetap id FOLDER');
      expect(p.pelangganId, 1, reason: '`pelangganId` dari `pelanggan.id`');
    });

    test('folder tanpa pelanggan: `pelangganId` null, bukan jatuh ke id folder', () {
      // `folders.customer_id` boleh kosong. Jatuh ke id folder di situ persis
      // bug yang lagi dijaga — cuma disamarkan jadi "default yang masuk akal".
      final p = ArsipPerusahaan.fromJson(baris(idFolder: 7));

      expect(p.id, 7);
      expect(p.pelangganId, isNull);
    });

    test('alamat dari `pelanggan.alamat`, bukan dari tingkat atas', () {
      // Selama dibaca dari tingkat atas, alamat di kartu PT SELALU kosong:
      // `FolderResource` nggak pernah ngirim kunci `alamat` di situ.
      final p = ArsipPerusahaan.fromJson(
        baris(idFolder: 3, idPelanggan: 1, alamat: 'Jl. Cikarang KM 27'),
      );

      expect(p.alamat, 'Jl. Cikarang KM 27');
    });

    test('alamat yang nggak ada jadi string kosong, bukan bikin baris hilang', () {
      // `parseListAman` nelen lemparan dan MEMBUANG barisnya — kartu PT-nya
      // ilang dari layar tanpa satu pun error.
      final p = ArsipPerusahaan.fromJson(baris(idFolder: 3, idPelanggan: 1));

      expect(p.alamat, '');
      expect(p.nama, 'PT Contoh');
    });
  });

  group('mock-nya ikut membedakan, biar jalur salah nggak kelihatan jalan', () {
    test('id folder != id pelanggan di daftar mock', () async {
      final daftar = await MockArsipService().daftarPerusahaan('token');

      expect(daftar, isNotEmpty);
      for (final p in daftar) {
        expect(
          p.pelangganId,
          isNotNull,
          reason: 'tiap PT di mock harus punya id pelanggan',
        );
        expect(
          p.pelangganId,
          isNot(p.id),
          reason:
              'kalau dua id-nya sama, jalur yang ngirim id folder ke rute '
              'pelanggan kelihatan mulus — dan itu yang bikin bug-nya lolos',
        );
      }
    });
  });

  group('alamat folder yang dipakai buat membuka kartu PT', () {
    // Ini yang beneran nentuin arsip siapa yang kebuka.
    AlamatFolder alamatUntuk(ArsipPerusahaan p) => p.pelangganId == null
        ? AlamatFolder.folder(p.id)
        : AlamatFolder.perusahaan(p.pelangganId!);

    test('PT yang nempel pelanggan dibuka lewat jalur PELANGGAN', () {
      final p = ArsipPerusahaan.fromJson(baris(idFolder: 3, idPelanggan: 1));
      final a = alamatUntuk(p);

      expect(a.lewatPerusahaan, isTrue);
      expect(a.id, 1, reason: 'id PELANGGAN yang dikirim, bukan id folder');
      expect(a.id, isNot(p.id));
    });

    test('folder tanpa pelanggan dibuka sebagai FOLDER biasa', () {
      // Bukan ditebak ke pelanggan. Rute folder-nya ada
      // (`GET /arsip/folders/{id}`), jadi nggak ada yang hilang.
      final p = ArsipPerusahaan.fromJson(baris(idFolder: 7));
      final a = alamatUntuk(p);

      expect(a.lewatPerusahaan, isFalse);
      expect(a.id, 7);
    });
  });
}
