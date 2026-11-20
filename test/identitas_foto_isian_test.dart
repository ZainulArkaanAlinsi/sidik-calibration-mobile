import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/pindai/identitas_foto_isian.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;

/// Identitas kertas masuk ke kotak lembar sebagai SARAN lewat mekanisme "dari
/// foto" yang sudah ada: ikut gerbang wajib-cek, tidak menimpa ketikan teknisi,
/// bidang kosong tetap kosong, dan keputusan manusia melepas tandanya.
LembarKerjaState _isian() => LembarKerjaState(
  bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
  clientRequestId: 'uuid-uji',
  tanggalKalibrasiAwal: DateTime(2026, 11, 15),
);

const _id = IdentitasKertas(
  merk: 'Mettler',
  model: 'Five Easy',
  seri: 'B628755900',
  pemilik: 'PT Tirta Contoh Mandiri',
  alamat: 'Jl. Contoh Primer A-10',
);

void main() {
  group('terapkanIdentitasKertas', () {
    test('mengisi kotak lembar, menandainya "dari foto" dan WAJIB dicek', () {
      final i = _isian();

      final n = i.terapkanIdentitasKertas(_id);

      expect(n, 5);
      expect(i.teks['alat_merk']!.text, 'Mettler');
      expect(i.teks['alat_serial_number']!.text, 'B628755900');
      expect(i.teks['pemilik_nama']!.text, 'PT Tirta Contoh Mandiri');
      expect(i.isianDariFoto, containsAll(['alat_merk', 'alat_serial_number']));
      expect(i.adaIsianDariFoto, isTrue);
      expect(i.adaBacaanKamera, isTrue, reason: 'input_method ocr');

      // Ikut gerbang wajib-cek: status "perlu dicek" sampai teknisi bertindak.
      final perlu = i
          .daftarSelCek()
          .where((s) => s.kunci.startsWith('isian|'))
          .toList();
      expect(perlu.map((s) => s.kunci), contains('isian|alat_serial_number'));
      expect(
        i.jumlahPerluCek,
        greaterThanOrEqualTo(5),
        reason: 'tombol Kirim ditahan sampai dicek',
      );
    });

    test('kotak yang SUDAH berisi (ketikan teknisi) tidak pernah ditimpa', () {
      final i = _isian();
      i.teks['alat_merk']!.text = 'Ketikan teknisi';

      i.terapkanIdentitasKertas(_id);

      expect(i.teks['alat_merk']!.text, 'Ketikan teknisi');
      expect(i.isianDariFoto, isNot(contains('alat_merk')));
      expect(i.teks['alat_model']!.text, 'Five Easy');
    });

    test('bidang kosong di kertas = kotak tetap kosong, tidak ditandai', () {
      final i = _isian();

      final n = i.terapkanIdentitasKertas(
        const IdentitasKertas(seri: 'SN-1234'),
      );

      expect(n, 1);
      expect(i.teks['alat_merk']!.text, isEmpty);
      expect(i.isianDariFoto, {'alat_serial_number'});
    });

    test(
      'identitas kosong: tidak ada yang berubah, tidak ada bacaan kamera',
      () {
        final i = _isian();

        expect(i.terapkanIdentitasKertas(IdentitasKertas.kosong), 0);
        expect(i.adaIsianDariFoto, isFalse);
        expect(i.adaBacaanKamera, isFalse);
      },
    );

    test(
      'kode yang tidak punya kotak di lembar ini dilewati (tanpa galat)',
      () {
        final i = _isian();
        // Lembar lain tidak memuat kolom merk: kotaknya tidak ada.
        i.teks.remove('alat_merk');

        final n = i.terapkanIdentitasKertas(_id);

        expect(n, 4, reason: 'model, seri, pemilik, alamat');
        expect(i.isianDariFoto, isNot(contains('alat_merk')));
      },
    );
  });

  group('keputusan teknisi melepas tanda saran', () {
    test('tetapkanIdentitasOlehTeknisi: nilai baru, tanda dari-foto lepas', () {
      final i = _isian();
      i.terapkanIdentitasKertas(_id);

      i.tetapkanIdentitasOlehTeknisi('alat_merk', 'Mettler Toledo');

      expect(i.teks['alat_merk']!.text, 'Mettler Toledo');
      expect(i.isianDariFoto, isNot(contains('alat_merk')));
      expect(
        i.daftarSelCek().map((s) => s.kunci),
        isNot(contains('isian|alat_merk')),
      );
    });

    test(
      'identitasMasihSaran: benar hanya bila tanda ada dan isi belum berubah',
      () {
        final i = _isian();
        i.terapkanIdentitasKertas(_id);

        expect(i.identitasMasihSaran('alat_merk', 'Mettler'), isTrue);
        i.teks['alat_merk']!.text = 'Mettler Toledo';
        expect(i.identitasMasihSaran('alat_merk', 'Mettler'), isFalse);
        expect(i.identitasMasihSaran('alat_model_tidak_ada', 'x'), isFalse);
      },
    );
  });

  group('draf lokal: identitas kertas tanpa alat bertahan di HP', () {
    test('salinan HP membawa saran kuning (belum dicek) dan alat tetap null, '
        'jadi draf "alat belum dibuat" tidak kehilangan apa pun', () {
      final i = _isian();
      i.terapkanIdentitasKertas(_id);
      final salinan = i.salinanLokal();

      final baru = _isian();
      baru.pulihkanSalinanLokal(salinan);

      expect(
        baru.alat,
        isNull,
        reason: 'belum ada alat: gerbang kirim menahan',
      );
      expect(baru.teks['alat_serial_number']!.text, 'B628755900');
      expect(baru.teks['pemilik_nama']!.text, 'PT Tirta Contoh Mandiri');
      expect(
        baru.isianDariFoto,
        containsAll(['alat_serial_number', 'pemilik_nama']),
      );
      // Masih WAJIB dicek: dipulihkan tidak berarti sudah dikonfirmasi.
      expect(baru.jumlahPerluCek, i.jumlahPerluCek);
      expect(baru.jumlahPerluCek, greaterThan(0));
    });

    test(
      'yang sudah dikonfirmasi teknisi tetap terkonfirmasi sesudah pulih',
      () {
        final i = _isian();
        i.terapkanIdentitasKertas(_id);
        i.konfirmasiSelCek('isian|alat_serial_number');
        final sebelum = i.jumlahPerluCek;

        final baru = _isian();
        baru.pulihkanSalinanLokal(i.salinanLokal());

        expect(baru.jumlahPerluCek, sebelum);
      },
    );
  });
}
