import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/models/pratinjau_hitung.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Pratinjau hitung saat mengetik (lag lembar kerja): satu permintaan terbang
/// pada satu waktu; isian yang berubah selagi menunggu CUMA menyisakan yang
/// terbaru (dulu tiap ketukan menembakkan permintaan paralel yang jawabannya
/// toh dibuang). Payload tidak berubah sedikit pun.
class _LayananLambat extends MockLembarKerjaService {
  final menunggu = <Completer<PratinjauHitung>>[];
  final dikirim = <String>[];

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) {
    dikirim.add(isian.clientRequestId);
    final c = Completer<PratinjauHitung>();
    menunggu.add(c);
    return c.future;
  }
}

LembarKerjaSubmission _isian(String id) => LembarKerjaSubmission(
  equipmentId: 1,
  clientRequestId: id,
  simpanSebagaiDraft: true,
);

const _hasil = PratinjauHitung(titik: [], belumDihitung: []);

void main() {
  late ProviderContainer container;
  late _LayananLambat layanan;

  setUp(() {
    layanan = _LayananLambat();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('t')),
        lembarKerjaServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(container.dispose);
  });

  test('lima ketukan beruntun = SATU permintaan terbang, lalu satu yang '
      'terbaru', () async {
    final ctl = container.read(pratinjauProvider.notifier);

    final selesai = ctl.hitung(_isian('a'));
    await Future<void>.delayed(Duration.zero);
    for (final id in ['b', 'c', 'd', 'e']) {
      unawaited(ctl.hitung(_isian(id)));
    }
    await Future<void>.delayed(Duration.zero);

    // Selagi 'a' belum dijawab, tidak ada permintaan paralel.
    expect(layanan.dikirim, ['a']);
    expect(container.read(pratinjauProvider).menghitung, isTrue);

    layanan.menunggu[0].complete(_hasil);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Yang menyusul HANYA isian terbaru ('e'); b, c, d dilewati.
    expect(layanan.dikirim, ['a', 'e']);

    layanan.menunggu[1].complete(_hasil);
    await selesai;
    expect(container.read(pratinjauProvider).menghitung, isFalse);
    expect(container.read(pratinjauProvider).hasil, isNotNull);
  });

  test('batalkan: jawaban yang masih di jalan dibuang & antrean kosong', () async {
    final ctl = container.read(pratinjauProvider.notifier);

    final selesai = ctl.hitung(_isian('a'));
    await Future<void>.delayed(Duration.zero);
    unawaited(ctl.hitung(_isian('b')));

    ctl.batalkan();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(pratinjauProvider).menghitung,
      isFalse,
      reason: 'lembar ditutup: indikator tidak boleh menggantung',
    );

    layanan.menunggu[0].complete(_hasil);
    await selesai;

    expect(layanan.dikirim, ['a'], reason: 'isian menunggu ikut dibuang');
    expect(
      container.read(pratinjauProvider).hasil,
      isNull,
      reason: 'jawaban lama dari lembar yang sudah ditutup tidak dipasang',
    );
  });
}
