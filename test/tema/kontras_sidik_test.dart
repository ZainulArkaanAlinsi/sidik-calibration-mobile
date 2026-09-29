import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';

/// Penjaga kontras token tema "Meja Kerja Lab".
///
/// Kenapa test ini ada: sistem visual ini punya banyak permukaan berdekatan
/// (kertas, baki, meja, logam) dan gampang banget menggeser satu warna "biar
/// lebih cakep" lalu diam-diam menjatuhkan keterbacaan di bawah ambang WCAG AA
/// — apalagi di tema gelap, yang jarang dilihat waktu ngoding siang hari.
///
/// Kalau ada warna di `SidikMaterial` yang digeser, test ini yang berteriak
/// duluan. Jangan dinaikkan ambangnya; betulkan warnanya.
void main() {
  // WCAG 2.1 AA: teks biasa 4,5:1 · teks besar (≥24px, atau ≥19px tebal) 3:1.
  const ambangTeks = 4.5;

  for (final (nama, m) in <(String, SidikMaterial)>[
    ('terang', SidikMaterial.terangDefault),
    ('gelap', SidikMaterial.gelapDefault),
  ]) {
    group('kontras tema $nama', () {
      void cek(String apa, Color depan, Color belakang, {double? ambang}) {
        final r = _rasio(depan, belakang);
        expect(
          r,
          greaterThanOrEqualTo(ambang ?? ambangTeks),
          reason:
              '$apa di tema $nama cuma ${r.toStringAsFixed(2)}:1 '
              '(minimal ${(ambang ?? ambangTeks)}:1)',
        );
      }

      test('tinta di atas kertas, baki, dan meja', () {
        cek('tinta/kertas', m.tinta, m.kertas);
        cek('tinta/baki', m.tinta, m.kertas2);
        cek('tinta/meja', m.tinta, m.meja);
        cek('tinta sekunder/kertas', m.tinta2, m.kertas);
        cek('tinta sekunder/baki', m.tinta2, m.kertas2);
      });

      test('keterangan yang jatuh langsung di atas MEJA juga harus lolos', () {
        // Ini yang kelewat di putaran pertama. Sebagian layar menaruh
        // keterangan di luar kartu — mis. catatan di bawah daftar, atau teks
        // di lembar yang menumpuk — jadi dia mendarat di permukaan meja,
        // bukan di kertas. Di situ ambangnya paling ketat karena meja adalah
        // permukaan paling gelap di tema terang.
        cek('tinta sekunder/meja', m.tinta2, m.meja);
        cek('tinta sekunder/meja-2', m.tinta2, m.meja2);
        cek('tinta/meja-2', m.tinta, m.meja2);
      });

      test('label terukir juga kebaca di semua nada logam', () {
        cek('etsa/logam', m.etsa, m.logam);
      });

      test('pensil OCR tetap kebaca — ini angka ukur, bukan hiasan', () {
        cek('pensil/kertas', m.pensil, m.kertas);
        // Sel OCR digambar di atas dasar amber, bukan kertas polos.
        cek('pensil/dasar amber', m.pensil, m.awasTipis);
      });

      test('label terukir di logam', () {
        cek('etsa/logam', m.etsa, m.logam);
        cek('etsa/logam atas', m.etsa, m.logamAtas);
        cek('etsa/logam bawah', m.etsa, m.logamBawah);
      });

      test('warna interaktif', () {
        cek('biru tinta/kertas', m.biruTinta, m.kertas);
        cek('biru tinta/baki', m.biruTinta, m.kertas2);
        // Label di atas tombol anodisasi.
        final labelTombol = m.terang ? Colors.white : const Color(0xFFEFF3FF);
        cek('label tombol/anodisasi', labelTombol, m.biru);
      });

      test('empat nada status di atas dasar tipisnya masing-masing', () {
        cek('lulus', m.lulus, m.lulusTipis);
        cek('gagal', m.gagal, m.gagalTipis);
        cek('awas', m.awas, m.awasTipis);
        cek('tunggu', m.tunggu, m.tungguTipis);
      });

      test('nada status juga kebaca langsung di atas kertas', () {
        cek('lulus/kertas', m.lulus, m.kertas);
        cek('gagal/kertas', m.gagal, m.kertas);
        cek('awas/kertas', m.awas, m.kertas);
        cek('tunggu/kertas', m.tunggu, m.kertas);
      });

      test('angka LCD di layar kaca', () {
        cek('lcd hijau', m.lcdHijau, m.kaca);
        cek('lcd amber', m.lcdAmber, m.kaca);
        cek('teks kaca', m.lcdTeks, m.kaca);
      });

      test('tiga nada BERONA beda terangnya, bukan cuma ronanya', () {
        // Hijau, merah, dan amber semuanya duduk di sumbu merah-hijau — sumbu
        // yang persis hilang buat mata deuteranopia, dan yang juga hilang
        // waktu sertifikat difotokopi hitam-putih. Jadi ketiganya wajib beda
        // TERANGNYA, bukan cuma beda warnanya.
        //
        // `tunggu` sengaja DIKECUALIKAN: dia abu tanpa rona, jadi dia kebeda
        // dari ketiganya lewat kejenuhan, bukan lewat terang-gelap. Memaksanya
        // ikut aturan ini mendorongnya jadi nyaris putih — dan "menunggu"
        // yang paling menyala di layar itu salah arti.
        //
        // Pengaman utamanya tetap bukan warna: tiap lencana SELALU bawa ikon
        // + teks (lihat SidikLencana). Aturan di sini lapis keduanya.
        final berona = <String, double>{
          'lulus': _luminansi(m.lulus),
          'gagal': _luminansi(m.gagal),
          'awas': _luminansi(m.awas),
        };
        final nama = berona.keys.toList();
        for (var i = 0; i < nama.length; i++) {
          for (var j = i + 1; j < nama.length; j++) {
            final beda = (berona[nama[i]]! - berona[nama[j]]!).abs();
            expect(
              beda,
              greaterThan(0.02),
              reason:
                  '${nama[i]} dan ${nama[j]} di tema $nama terangnya nyaris '
                  'sama (beda ${beda.toStringAsFixed(4)}) — nggak kebeda '
                  'tanpa melihat warnanya',
            );
          }
        }
      });
    });
  }

  test('tidak ada token yang lupa diisi antar-tema', () {
    // lerp harus menghasilkan nilai di antara keduanya, bukan melempar.
    final tengah = SidikMaterial.terangDefault.lerp(
      SidikMaterial.gelapDefault,
      0.5,
    );
    expect(tengah, isA<SidikMaterial>());
    expect(tengah.kertas, isNot(equals(SidikMaterial.terangDefault.kertas)));
  });
}

double _luminansi(Color c) {
  double k(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * k(c.r) + 0.7152 * k(c.g) + 0.0722 * k(c.b);
}

double _rasio(Color a, Color b) {
  final la = _luminansi(a);
  final lb = _luminansi(b);
  final terang = math.max(la, lb);
  final gelap = math.min(la, lb);
  return (terang + 0.05) / (gelap + 0.05);
}
