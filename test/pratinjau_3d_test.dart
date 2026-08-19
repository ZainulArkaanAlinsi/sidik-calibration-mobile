@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/widgets/scene3d/alat_3d.dart';
import 'package:sidik_calibration/widgets/scene3d/mesh3d.dart';
import 'package:sidik_calibration/widgets/scene3d/panggung3d.dart';
import 'package:sidik_calibration/widgets/scene3d/renderer3d.dart';

Future<void> _muatFont() async {
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();
}

void main() {
  setUpAll(_muatFont);

  testWidgets('pratinjau alat 3D', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final alat = <String, Mesh3D>{
      'anak timbangan': Alat3D.anakTimbangan(),
      'jangka sorong': Alat3D.jangkaSorong(),
      'probe suhu': Alat3D.probeSuhu(),
      'gelas + probe pH': Alat3D.gelasProbe(),
      'sertifikat': Alat3D.sertifikat(),
      'lembar kerja': Alat3D.lembarKerja(),
    };

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xFF0E2236),
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              for (final e in alat.entries)
                Column(
                  children: [
                    Expanded(
                      child: Panggung3D(
                        mesh: e.value,
                        kamera: const Kamera3D(jarak: 6.4, pitch: 0.30),
                        garisTepi: 0.6,
                      ),
                    ),
                    Text(e.key, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('pratinjau/alat-3d-v2.png'),
    );
  });
}
