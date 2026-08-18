import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/auth/splash_screen.dart';
import 'package:sidik_calibration/widgets/scene3d/alat_3d.dart';
import 'package:sidik_calibration/widgets/scene3d/mesh3d.dart';
import 'package:sidik_calibration/widgets/scene3d/panggung3d.dart';
import 'package:sidik_calibration/widgets/scene3d/renderer3d.dart';

/// Normal bidang, dihitung persis kayak yang dipakai renderer.
Vek3 _normal(Mesh3D mesh, Segi3 segi) {
  final a = mesh.titik[segi.indeks[0]];
  final b = mesh.titik[segi.indeks[1]];
  final c = mesh.titik[segi.indeks[2]];
  return (b - a).cross(c - a).satuan;
}

void main() {
  group('vektor', () {
    test('vektor nol nggak jadi NaN waktu dinormalisasi', () {
      // NaN yang nyasar ke Path bikin SELURUH frame ilang, bukan cuma satu
      // bidang — dan nggak ada error yang kecetak.
      final s = Vek3.nol.satuan;
      expect(s.x.isNaN || s.y.isNaN || s.z.isNaN, isFalse);
    });

    test('putarY 90 derajat mindahin +X ke -Z', () {
      final p = const Vek3(1, 0, 0).putarY(3.14159265358979 / 2);
      expect(p.x, closeTo(0, 1e-9));
      expect(p.z, closeTo(-1, 1e-9));
    });
  });

  group('arah bidang (winding)', () {
    // Normal yang kebalik = bidangnya gelap terus DAN lolos dari pembuangan
    // sisi belakang, jadi yang kelihatan malah rongga dalam benda. Pernah
    // kejadian pas tabung pertama kali dibikin.
    test('sisi tabung menghadap keluar dari sumbu', () {
      final tabung = Mesh3D.tabung(
        jariBawah: 1,
        jariAtas: 1,
        yBawah: 0,
        yAtas: 2,
        sisi: 8,
        warna: const Color(0xFFFFFFFF),
      );
      // Bidang 0..7 = sisi keliling; dua terakhir tutup atas & bawah.
      for (var i = 0; i < 8; i++) {
        final n = _normal(tabung, tabung.segi[i]);
        final titik = tabung.titik[tabung.segi[i].indeks[0]];
        final keLuar = Vek3(titik.x, 0, titik.z).satuan;
        expect(
          n.dot(keLuar),
          greaterThan(0.9),
          reason: 'sisi ke-$i normalnya nunjuk ke dalam',
        );
      }
    });

    test('tutup atas menghadap ke atas, tutup bawah ke bawah', () {
      final tabung = Mesh3D.tabung(
        jariBawah: 1,
        jariAtas: 1,
        yBawah: 0,
        yAtas: 2,
        sisi: 8,
        warna: const Color(0xFFFFFFFF),
      );
      expect(_normal(tabung, tabung.segi[8]).y, closeTo(1, 1e-9));
      expect(_normal(tabung, tabung.segi[9]).y, closeTo(-1, 1e-9));
    });

    test('sisi depan balok menghadap +Z', () {
      final balok = Mesh3D.balok(
        const Vek3(-1, -1, -1),
        const Vek3(1, 1, 1),
        warna: const Color(0xFFFFFFFF),
      );
      expect(_normal(balok, balok.segi[0]).z, closeTo(1, 1e-9));
    });
  });

  group('rakit mesh', () {
    test('gabung nggeser indeks segi ikut titiknya', () {
      final satu = Mesh3D.balok(
        Vek3.nol,
        const Vek3(1, 1, 1),
        warna: const Color(0xFFFFFFFF),
      );
      final dua = Mesh3D.gabung([satu, satu]);
      expect(dua.titik.length, satu.titik.length * 2);
      expect(dua.segi.length, satu.segi.length * 2);
      // Indeks segi mesh kedua harus nunjuk ke blok titik kedua.
      final akhir = dua.segi.last.indeks;
      for (final i in akhir) {
        expect(i, greaterThanOrEqualTo(satu.titik.length));
        expect(i, lessThan(dua.titik.length));
      }
    });

    test('tiap alat kalibrasi tetap low-poly', () {
      // Batasnya bukan angka keramat: ini yang bikin render tetap murah di HP
      // low-end. Kalau suatu saat butuh model yang lebih detail, pindah ke
      // mesin 3D beneran — jangan cuma naikin angka ini.
      for (final mesh in [
        Alat3D.anakTimbangan(),
        Alat3D.jangkaSorong(),
        Alat3D.probeSuhu(),
        Alat3D.gelasProbe(),
        Alat3D.sertifikat(),
        Alat3D.lembarKerja(),
      ]) {
        expect(mesh.jumlahSegi, lessThan(140));
        expect(mesh.titik, isNotEmpty);
      }
    });
  });

  group('render', () {
    void gambar(Size ukuran, Adegan3D adegan) {
      final rekam = PictureRecorder();
      gambarAdegan(Canvas(rekam), ukuran, adegan);
      rekam.endRecording().dispose();
    }

    test('ukuran kosong nggak bikin error', () {
      gambar(
        Size.zero,
        Adegan3D(objek: [Objek3D(mesh: Alat3D.anakTimbangan())]),
      );
    });

    test('objek di belakang kamera dibuang, bukan digambar kebalik', () {
      // Titik di belakang bidang dekat kalau diproyeksi bakal jadi bayangan
      // cermin di seberang layar. Yang bener: seginya dibuang.
      gambar(
        const Size(200, 200),
        Adegan3D(
          objek: [
            Objek3D(mesh: Alat3D.anakTimbangan(), posisi: const Vek3(0, 0, 40)),
          ],
          kamera: const Kamera3D(jarak: 5),
        ),
      );
    });
  });

  group('gerak berujung', () {
    // Ini penjaga regresi buat kejadian 18 Agt 2026: satu `repeat()` di panel
    // dashboard bikin 72 tes timeout serentak, karena `pumpAndSettle` nunggu
    // sampai nggak ada frame terjadwal dan animasi berulang nggak pernah
    // nyampe situ. Layar mana pun yang gerak terus bakal ketangkep di sini.
    testWidgets('panggung 3D berhenti sendiri', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Panggung3D(mesh: Alat3D.anakTimbangan()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Panggung3D), findsOneWidget);
    });

    testWidgets('splash berhenti sendiri', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SplashScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsOneWidget);
    });
  });
}
