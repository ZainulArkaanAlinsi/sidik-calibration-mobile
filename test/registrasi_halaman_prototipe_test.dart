// Geometri 26 foto prototipe 12 Nov 2026 (`geometri_prototipe.json`: homografi
// sebenarnya + kotak sel 12 formulir FM-CAL), difoto ulang dengan pembangkit
// Dart. Pembanding ke hasil prototipe Python (di luar repo; angkanya dikutip
// di komentar uji).
//
// Batas jujur: foto sintetis, bukan foto nyata.
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/registrasi_halaman/registrasi_halaman.dart';

import 'support/registrasi_halaman_uji.dart';
import 'support/ukur_registrasi_halaman.dart';

void main() {
  test('geometri 26 foto prototipe (12 formulir FM-CAL)', () {
    final foto = muatPrototipe();
    expect(foto, hasLength(26));

    final ukuran = <UkuranFoto>[];
    for (var n = 0; n < foto.length; n++) {
      final f = fotoPrototipe(foto[n], n, 0.16);
      final h = registrasiHalaman(f.foto, halamanPt: f.halamanPt, skala: 0.5);
      ukuran.add(ukurHasil(foto[n]['berkas'] as String, f, h));
    }

    final ringkasan = RingkasanUkur('prototipe26', ukuran);
    laporUkur(ringkasan);

    // Prototipe Python (garis kuadrat-terkecil, lebar 640; di luar repo):
    // 26/26, galat maks 0,36%, 99,5% sel IoU ≥ 0,7. Port Dart terukur 0,16%
    // (12 Nov 2026); ambang 0,25% menyisakan ruang untuk beda platform tetapi
    // cukup rapat untuk menangkap regresi kecil.
    expect(ringkasan.ok.length, 26, reason: '${ringkasan.alasanGagal}');
    expect(ringkasan.galatMaksPctFoto, lessThanOrEqualTo(0.25));
    expect(ringkasan.fraksiSelIou07, greaterThanOrEqualTo(0.995));
    expect(ringkasan.fraksiSelGeser025, 0);
  });

  test('lebar kerja 1280: penutupan garis mencegah kunci ke bingkai dalam', () {
    // Prototipe Python (di luar repo) melaporkan 1280 px menurunkan deteksi (garis tabel dan
    // bingkai memecah mask halaman) dan dua foto salah sudut ~9,5% diagonal.
    // Di sini tiga foto yang pada 1280 px tanpa penutupan ditolak.
    final foto = muatPrototipe();
    const indeks = [3, 4, 9]; // sin_0505_2, sin_0506_1, sin_0508_2
    const opsi1280 = OpsiRegistrasiHalaman(lebarKerja: 1280);
    const tanpaPenutup = OpsiRegistrasiHalaman(
      lebarKerja: 1280,
      penutupRadius: 0,
    );

    for (final n in indeks) {
      final f = fotoPrototipe(foto[n], n, 0.32);
      final nama = foto[n]['berkas'] as String;

      final dengan = deteksiSudutHalaman(f.foto, opsi: opsi1280);
      expect(dengan, isA<DeteksiHalamanBerhasil>(), reason: '$nama: $dengan');
      expect(
        ukurSudut(
          nama,
          f,
          (dengan as DeteksiHalamanBerhasil).sudut,
        ).galatSudutPctFoto,
        lessThanOrEqualTo(0.25),
        reason: nama,
      );

      // Tanpa penutupan: boleh ditolak, TIDAK boleh salah diam-diam. Kunci ke
      // bingkai dalam (galat ~3% diagonal) dulu lolos semua pemeriksaan.
      final tanpa = deteksiSudutHalaman(f.foto, opsi: tanpaPenutup);
      if (tanpa is DeteksiHalamanBerhasil) {
        expect(
          ukurSudut(nama, f, tanpa.sudut).galatSudutPctFoto,
          lessThanOrEqualTo(0.25),
          reason: '$nama tanpa penutupan: salah diam-diam',
        );
      }
    }
  });
}
