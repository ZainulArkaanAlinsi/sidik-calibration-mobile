import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/ocr_awan_provider.dart';
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';

/// Kapan tombol OCR awan BOLEH ditawarkan.
///
/// Aturan: sakelar klien menyala (bawaan MATI), backend sudah menjawab izin, dan
/// `fitur_nonaktif` tidak memuat `ocr_cloud_sel` maupun `pindai_lembar`. Ini
/// hanya menyembunyikan tombol; penegaknya server (`503 fitur_dimatikan`).
void main() {
  group('Izin.fromJson: fitur_nonaktif', () {
    test('dibaca dari data.fitur_nonaktif', () {
      final izin = Izin.fromJson({
        'data': {
          'role': 'teknisi',
          'boleh': ['alat.lihat'],
          'batasan': <String, dynamic>{},
          'fitur_nonaktif': ['pindai_lembar', 'ocr_cloud_sel'],
        },
      });

      expect(izin.fiturNonaktif, {'pindai_lembar', 'ocr_cloud_sel'});
      expect(izin.fiturMati(KodeFitur.pindaiLembar), isTrue);
      expect(izin.fiturMati(KodeFitur.ocrCloudSel), isTrue);
      expect(izin.fiturMati('kirim_email_sertifikat'), isFalse);
    });

    test('[] = semua nyala', () {
      final izin = Izin.fromJson({
        'data': {'role': 'teknisi', 'boleh': ['alat.lihat'], 'fitur_nonaktif': <String>[]},
      });

      expect(izin.fiturNonaktif, isEmpty);
    });

    test('field tidak ada (backend lama) = semua nyala', () {
      final izin = Izin.fromJson({
        'data': {'role': 'teknisi', 'boleh': ['alat.lihat']},
      });

      expect(izin.fiturNonaktif, isEmpty);
      expect(izin.fiturMati(KodeFitur.ocrCloudSel), isFalse);
    });

    test('bentuk cacat tidak melempar; isi bukan teks dibuang', () {
      expect(
        Izin.fromJson({'data': {'boleh': ['x'], 'fitur_nonaktif': 'pindai_lembar'}}).fiturNonaktif,
        isEmpty,
      );
      expect(
        Izin.fromJson({
          'data': {
            'boleh': ['x'],
            'fitur_nonaktif': ['ocr_cloud_sel', 3, null, ''],
          },
        }).fiturNonaktif,
        {'ocr_cloud_sel'},
      );
    });

    test('kode yang tidak dikenal klien tidak mengganggu', () {
      final izin = Izin.fromJson({
        'data': {'boleh': ['x'], 'fitur_nonaktif': ['fitur_masa_depan']},
      });

      expect(izin.fiturMati('fitur_masa_depan'), isTrue);
      expect(izin.fiturMati(KodeFitur.ocrCloudSel), isFalse);
    });

    test('Izin.kosong tidak mematikan apa pun', () {
      expect(Izin.kosong.fiturNonaktif, isEmpty);
    });
  });

  group('sakelar klien', () {
    test('bawaan MATI', () {
      expect(const SakelarOcr().ocrAwanSel, isFalse);
    });

    test('sakelarOcrProvider tanpa --dart-define = mati', () {
      final kontainer = ProviderContainer();
      addTearDown(kontainer.dispose);

      expect(kontainer.read(sakelarOcrProvider).ocrAwanSel, isFalse);
    });
  });

  group('ocrAwanBolehDitawarkan', () {
    const hidup = SakelarOcr(ocrAwanSel: true);

    Izin izin({Set<String> mati = const {}, Set<String> boleh = const {'alat.lihat'}}) =>
        Izin(role: null, boleh: boleh, fiturNonaktif: mati);

    test('semua syarat terpenuhi -> boleh', () {
      expect(ocrAwanBolehDitawarkan(sakelar: hidup, izin: izin()), isTrue);
    });

    test('sakelar klien mati (bawaan) -> tidak, apa pun kata server', () {
      expect(ocrAwanBolehDitawarkan(sakelar: const SakelarOcr(), izin: izin()), isFalse);
    });

    test('ocr_cloud_sel dimatikan Super Admin -> tersembunyi', () {
      expect(
        ocrAwanBolehDitawarkan(sakelar: hidup, izin: izin(mati: {KodeFitur.ocrCloudSel})),
        isFalse,
      );
    });

    test('pindai_lembar dimatikan Super Admin -> tersembunyi', () {
      expect(
        ocrAwanBolehDitawarkan(sakelar: hidup, izin: izin(mati: {KodeFitur.pindaiLembar})),
        isFalse,
      );
    });

    test('fitur lain yang dimatikan tidak menyembunyikan', () {
      expect(
        ocrAwanBolehDitawarkan(sakelar: hidup, izin: izin(mati: {'kirim_email_sertifikat'})),
        isTrue,
      );
    });

    test('izin belum dijawab backend -> gagal tertutup, tidak ditawarkan', () {
      expect(ocrAwanBolehDitawarkan(sakelar: hidup, izin: Izin.kosong), isFalse);
    });
  });

  group('WidgetRef.ocrAwanTersedia', () {
    Future<bool> baca(
      WidgetTester tester, {
      required SakelarOcr sakelar,
      required Izin izin,
    }) async {
      bool? hasil;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sakelarOcrProvider.overrideWithValue(sakelar),
            izinProvider.overrideWith((ref) async => izin),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                hasil = ref.ocrAwanTersedia;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return hasil!;
    }

    testWidgets('sakelar nyala + izin menjawab + fitur nyala -> tersedia', (tester) async {
      expect(
        await baca(
          tester,
          sakelar: const SakelarOcr(ocrAwanSel: true),
          izin: const Izin(role: null, boleh: {'alat.lihat'}),
        ),
        isTrue,
      );
    });

    testWidgets('ocr_cloud_sel mati -> tidak tersedia', (tester) async {
      expect(
        await baca(
          tester,
          sakelar: const SakelarOcr(ocrAwanSel: true),
          izin: const Izin(
            role: null,
            boleh: {'alat.lihat'},
            fiturNonaktif: {KodeFitur.ocrCloudSel},
          ),
        ),
        isFalse,
      );
    });

    testWidgets('bawaan (sakelar mati) -> tidak tersedia walau izin lengkap', (tester) async {
      expect(
        await baca(
          tester,
          sakelar: const SakelarOcr(),
          izin: const Izin(role: null, boleh: {'alat.lihat'}),
        ),
        isFalse,
      );
    });

    testWidgets('selama izin belum sampai -> tidak tersedia', (tester) async {
      bool? hasil;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sakelarOcrProvider.overrideWithValue(const SakelarOcr(ocrAwanSel: true)),
            izinProvider.overrideWith((ref) => Future<Izin>.delayed(
              const Duration(seconds: 5),
              () => const Izin(role: null, boleh: {'alat.lihat'}),
            )),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                hasil = ref.ocrAwanTersedia;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(hasil, isFalse);

      await tester.pump(const Duration(seconds: 6));
      expect(hasil, isTrue, reason: 'ikut nyala begitu izin sampai');
    });
  });
}
