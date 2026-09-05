import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/skema_dokumen.dart';
import 'package:sidik_calibration/services/analisis_dokumen.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Skema dokumen — bentuk lembar yang lahir dari ISI dokumennya, bukan dari
/// daftar field yang ditulis manusia.
///
/// Berkas ini menjaga satu hal di atas segalanya: **nggak ada nama alat dan
/// nggak ada daftar field tetap di jalur ini.** Begitu ada, jalur generiknya
/// mati dan yang tersisa parser dengan nama lain.
void main() {
  const analisis = AnalisisDokumen();
  const pembuat = PembuatSkema();

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 12, 20),
    keyakinan: keyakinan,
  );

  SkemaDokumen dariOcr(List<TeksTerbaca> ocr, {String? judul}) {
    // Lewat `bacaDokumen`, bukan memanggil dua pendeteksinya sendiri-sendiri:
    // di situ aturan "titik dua menang atas tabel" berdiri, dan test yang
    // melewatinya nggak lagi menguji jalur yang beneran dipakai aplikasi.
    final d = analisis.bacaDokumen(ocr);
    return pembuat.susun(pasangan: d.pasangan, tabel: d.tabel, judul: judul);
  }

  group('kolom lahir dari dokumen', () {
    test('label→nilai jadi kolom skema', () {
      final s = dariOcr([
        kata('Nama', 100, 100),
        kata('Alat', 160, 100),
        kata(':', 240, 100),
        kata('Tohnichi', 270, 100),
      ]);

      expect(s.kolom, hasLength(1));
      expect(s.kolom.single.label, 'Nama Alat');
      expect(s.kolom.single.nilai, 'Tohnichi');
      expect(s.kolom.single.jenis, JenisIsi.teks);
    });

    test('angka dikenali sebagai angka, bukan teks', () {
      final s = dariOcr([
        kata('Suhu', 100, 100),
        kata(':', 160, 100),
        kata('25,4', 190, 100),
      ]);

      expect(s.kolom.single.jenis, JenisIsi.angka);
    });

    test('kolom yang belum diisi punya jenisnya SENDIRI, bukan teks kosong', () {
      final s = dariOcr([kata('Serial', 100, 100), kata('Number:', 170, 100)]);

      expect(
        s.kolom.single.jenis,
        JenisIsi.kosong,
        reason: '"Kertasnya minta diisi" beda artinya dari "kebaca sebagai '
            'teks kosong" — dan yang membacanya teknisi, bukan mesin.',
      );
    });
  });

  group('satuan diambil dari dokumen, bukan dari daftar alat', () {
    test('satuan yang nempel di ekor angka dipisah', () {
      final s = dariOcr([
        kata('Suhu', 100, 100),
        kata(':', 160, 100),
        kata('25,4', 190, 100),
        kata('°C', 250, 100),
      ]);

      expect(s.kolom.single.nilai, '25,4');
      expect(s.kolom.single.satuan, '°C');
      expect(s.kolom.single.jenis, JenisIsi.angka);
    });

    test('teks yang KEBETULAN berakhir huruf satuan nggak dipotong', () {
      final s = dariOcr([
        kata('Pelanggan', 100, 100),
        kata(':', 220, 100),
        kata('PT', 250, 100),
        kata('Gracia', 290, 100),
        kata('m', 380, 100),
      ]);

      expect(
        s.kolom.single.satuan,
        isNull,
        reason: 'Yang dipisah cuma kalau sisanya beneran angka. `PT Gracia m` '
            'nggak boleh kehilangan `m`-nya cuma karena `m` kebetulan satuan '
            'panjang.',
      );
      expect(s.kolom.single.nilai, contains('m'));
    });

    test('satuan di luar daftar tetap lolos, nilainya nggak ditolak', () {
      final s = dariOcr([
        kata('Torsi', 100, 100),
        kata(':', 170, 100),
        kata('200', 200, 100),
        kata('kgf·cm', 250, 100),
      ]);

      expect(
        s.kolom, hasLength(1),
        reason: 'Daftar satuan BUKAN batas kemampuan sistem. Lembar yang '
            'satuannya asing tetap kebaca, satuannya saja yang nggak dipisah.',
      );
    });
  });

  group('vonis ikut aturan yang sama dengan jalur foto tabel', () {
    test('tulisan tangan tetap nggak pernah hijau', () {
      final s = dariOcr([
        kata('Suhu', 100, 100, keyakinan: 0.99),
        kata(':', 160, 100, keyakinan: 0.99),
        kata('25,4', 190, 100, keyakinan: 0.99),
      ]);

      expect(
        s.kolom.single.vonis,
        VonisFoto.kuning,
        reason: 'Jalur generik nggak boleh lebih longgar cuma karena '
            'dokumennya belum dikenal — justru di sini yang lebih perlu '
            'diperiksa.',
      );
    });

    test('keyakinan tak dilaporkan tetap jadi tidakDiketahui', () {
      final s = dariOcr([
        kata('Suhu', 100, 100),
        kata(':', 160, 100),
        kata('25,4', 190, 100),
      ]);

      expect(s.kolom.single.vonis, VonisFoto.tidakDiketahui);
    });
  });

  group('peringatan', () {
    test('label kembar DILAPORKAN, bukan dibuang diam-diam', () {
      final s = dariOcr([
        kata('Merk', 100, 100),
        kata(':', 160, 100),
        kata('Fluke', 190, 100),
        kata('Merk', 100, 160),
        kata(':', 160, 160),
        kata('Tohnichi', 190, 160),
      ]);

      expect(
        s.kolom,
        hasLength(2),
        reason: 'Yang dibuang menghilangkan satu isian dari layar tanpa ada '
            'yang tahu. Lebih baik dua-duanya muncul dan teknisi yang milih.',
      );
      expect(s.peringatan.single, contains('Merk'));
    });

    test('foto yang nggak menghasilkan apa-apa bilang begitu', () {
      final s = dariOcr([kata('coret', 100, 100)]);

      expect(s.kolom, isEmpty);
      expect(s.tabel, isEmpty);
      expect(s.peringatan, isNotEmpty);
    });
  });

  group('satuan yang beda cuma di huruf besar-kecil', () {
    test('Nm (newton-meter) NGGAK jadi nm (nanometer)', () {
      final s = dariOcr([
        kata('Torsi', 100, 100),
        kata(':', 170, 100),
        kata('200', 200, 100),
        kata('Nm', 250, 100),
      ]);

      expect(
        s.kolom.single.satuan,
        'Nm',
        reason: 'Nm newton-meter, nm nanometer. Torsi yang pulang bersatuan '
            'panjang gelombang: angkanya bener, satuannya masuk akal dibaca '
            'sekilas, dan salahnya cuma ketahuan kalau ada yang merhatiin '
            'huruf pertamanya.',
      );
    });

    test('nm kecil tetap nm', () {
      final s = dariOcr([
        kata('Panjang', 100, 100),
        kata('gelombang:', 200, 100),
        kata('546', 350, 100),
        kata('nm', 400, 100),
      ]);

      expect(s.kolom.single.satuan, 'nm');
    });

    test('ejaan teknisi dipertahankan, bukan dirapikan diam-diam', () {
      final s = dariOcr([
        kata('Tekanan', 100, 100),
        kata(':', 200, 100),
        kata('10', 230, 100),
        kata('MPA', 270, 100),
      ]);

      expect(
        s.kolom.single.satuan,
        'MPA',
        reason: 'Yang dijawab berkas ini "ada satuannya", bukan "satuannya '
            'harus ditulis begini".',
      );
    });
  });

  test('deretan label:nilai NGGAK ikut jadi tabel — titik dua menang', () {
    // Secara BENTUK, dua baris `label : nilai` nggak bisa dibedakan dari tabel
    // dua kolom: sama-sama beberapa baris berturut-turut dengan kepingan di
    // posisi mendatar yang mirip. Diklaim dua-duanya, isinya muncul dobel di
    // layar review — teknisi mengisinya dua kali, atau lebih buruk: mengisi
    // salah satunya lalu mengira sudah selesai.
    final s = dariOcr([
      kata('Merk', 100, 100),
      kata(':', 200, 100),
      kata('Fluke', 240, 100),
      kata('Tipe', 100, 140),
      kata(':', 200, 140),
      kata('87V', 240, 140),
    ]);

    expect(s.kolom, hasLength(2));
    expect(
      s.tabel,
      isEmpty,
      reason: 'Tabel dikenali dari keteraturan posisi — bisa kebetulan. '
          'Pasangan dikenali dari tanda baca yang memang dicetak untuk itu. '
          'Yang buktinya lebih kuat yang menang.',
    );
  });

  test('LEMBAR BARU: skema lahir utuh tanpa satu pun parser', () {
    // Torque wrench — bukan lembar mana pun yang dikenal aplikasi ini.
    // Nggak ada profil, geometri, maupun daftar field.
    final s = dariOcr(judul: 'Torque Wrench Calibration', [
      kata('Nama', 100, 100),
      kata('Alat', 160, 100),
      kata(':', 240, 100),
      kata('Tohnichi', 270, 100),
      kata('Kapasitas', 100, 140),
      kata(':', 220, 140),
      kata('200', 250, 140),
      kata('Nm', 300, 140),
      // Tabel tanpa garis, kepala + dua baris data.
      kata('No', 100, 220),
      kata('Target', 300, 220),
      kata('Hasil', 500, 220),
      kata('1', 100, 260),
      kata('50', 300, 260),
      kata('49,8', 500, 260),
      kata('2', 100, 300),
      kata('100', 300, 300),
      kata('99,5', 500, 300),
    ]);

    expect(s.judul, 'Torque Wrench Calibration');

    expect({for (final k in s.kolom) k.label: k.nilai}, {
      'Nama Alat': 'Tohnichi',
      'Kapasitas': '200',
    });
    expect(s.kolom.firstWhere((k) => k.label == 'Kapasitas').satuan, 'Nm');

    expect(s.tabel, hasLength(1));
    expect(s.tabel.single.kepala, ['No', 'Target', 'Hasil']);
    expect(s.tabel.single.baris, [
      ['1', '50', '49,8'],
      ['2', '100', '99,5'],
    ]);

    expect(
      s.peringatan,
      isEmpty,
      reason: 'Lembar yang kebaca utuh nggak boleh menakut-nakuti teknisi '
          'dengan peringatan yang nggak ada isinya.',
    );
  });
}
