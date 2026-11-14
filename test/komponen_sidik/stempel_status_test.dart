// StatusTampil (satu pemetaan status, id dan en dari ARB) dan Stempel (persegi
// sudut 4, ikon + kata).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';
import 'package:sidik_calibration/widgets/sidik/stempel.dart';

import '../support/komponen_uji.dart';

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Kode status yang BENAR-BENAR dipakai app, diturunkan dari model, bukan
/// ditulis tangan: semua nilai enum status sesi, alat, akun, dan label dokumen
/// sertifikat.
Map<String, String> _kodeDariEnum() {
  final kode = <String, String>{};
  for (final v in CalibrationStatus.values) {
    final k = _snake(v.name);
    if (CalibrationStatusJson.fromJson(k) != v) {
      throw StateError('kode turunan $k bukan kode API untuk ${v.name}');
    }
    kode[k] = 'CalibrationStatus.${v.name}';
  }
  for (final v in EquipmentStatus.values) {
    kode[v.rawValue] = 'EquipmentStatus.${v.name}';
  }
  for (final v in UserStatus.values) {
    if (UserStatus.fromApi(v.name) != v) {
      throw StateError('kode ${v.name} bukan kode API UserStatus');
    }
    kode[v.name] = 'UserStatus.${v.name}';
  }
  for (final v in StatusDokumen.values) {
    kode[v.kode] = 'StatusDokumen.${v.name}';
  }
  return kode;
}

/// Kode yang dipakai dua sistem yang digantikan (`StatusBadge`, `StatusSidik`),
/// dibaca dari sumbernya: status sertifikat teknis, standar acuan, order, dan
/// vonis tidak punya enum, tetapi sudah ditulis di dua berkas itu.
Map<String, String> _kodeDariSistemLama() {
  final kode = <String, String>{};
  final pola = RegExp(r"(?:case\s+)?'([A-Za-z_]+)'\s*(?:=>|:)");
  for (final berkas in [
    'lib/widgets/status_badge.dart',
    'lib/widgets/sidik/sidik_status.dart',
  ]) {
    final sumber = File(berkas)
        .readAsStringSync()
        .split(RegExp(r'\r?\n'))
        .where((b) => !b.trimLeft().startsWith('//'))
        .join('\n');
    for (final m in pola.allMatches(sumber)) {
      kode.putIfAbsent(m[1]!, () => berkas);
    }
  }
  return kode;
}

void main() {
  setUpAll(muatFontUji);

  final id = l10nUji('id');
  final en = l10nUji('en');

  group('StatusTampil: satu sumber kata, nada, dan ikon', () {
    final semua = {..._kodeDariSistemLama(), ..._kodeDariEnum()};

    test('daftar kode berasal dari model dan tidak kosong', () {
      expect(_kodeDariEnum().length, greaterThanOrEqualTo(10));
      expect(_kodeDariSistemLama().length, greaterThanOrEqualTo(15));
      for (final k in [
        'draft',
        'menunggu_approval',
        'perlu_revisi',
        'disetujui',
        'overdue',
        'berlaku',
        'digantikan',
        'belum_terbit',
        'dibatalkan',
        'ditarik',
        'pending',
        'terbit',
        'expired',
        'PASS',
        'FAIL',
      ]) {
        expect(semua.keys, contains(k), reason: '$k tidak terbaca dari sumber');
      }
    });

    test('SEMUA kode yang dipakai app dipetakan (bukan jatuh ke default)', () {
      final tak = <String>[];
      for (final e in semua.entries) {
        final s = StatusTampil.dariKode(e.key);
        if (s.kata == null) tak.add('${e.key} (${e.value})');
      }
      expect(
        tak,
        isEmpty,
        reason:
            'kode tak terpetakan di StatusTampil.dariKode: tambahkan ke '
            'pemetaan, kata ARB `stempel*` id+en, dan ikon',
      );
    });

    test('tiap kode: kata id dan en ada, tanpa istilah terlarang', () {
      for (final k in semua.keys) {
        final s = StatusTampil.dariKode(k);
        for (final (bahasa, l) in [('id', id), ('en', en)]) {
          final kata = s.label(l);
          expect(kata.trim(), isNotEmpty, reason: '$k/$bahasa');
          expect(kata, isNot(contains('–')), reason: '$k/$bahasa default');
          final kecil = kata.toLowerCase();
          expect(kecil, isNot(contains('daluwarsa')), reason: '$k/$bahasa');
          expect(kecil, isNot(contains('adaluarsa')), reason: '$k/$bahasa');
          expect(kecil, isNot(contains('jatuh tempo')), reason: '$k/$bahasa');
        }
      }
    });

    test(
      'SETIAP KataStatus punya kata id dan en yang berbeda dan terpakai',
      () {
        final dipakai = <KataStatus>{
          for (final k in semua.keys) ?StatusTampil.dariKode(k).kata,
          for (final h in [-1, 0, 31]) ?StatusTampil.jadwal(h).kata,
          ?StatusTampil.dariKode('disetujui', keputusan: 'PASS').kata,
          ?StatusTampil.dariKode('disetujui', keputusan: 'FAIL').kata,
        };
        for (final kata in KataStatus.values) {
          final s = StatusTampil(kata, NadaStempel.netral, Icons.circle);
          final kataId = s.label(id);
          final kataEn = s.label(en);
          expect(kataId, isNotEmpty, reason: '$kata id');
          expect(kataEn, isNotEmpty, reason: '$kata en');
          if (kata != KataStatus.pass && kata != KataStatus.fail) {
            expect(
              kataEn,
              isNot(kataId),
              reason: '$kata en belum diterjemahkan',
            );
          }
          expect(
            dipakai,
            contains(kata),
            reason: '$kata tak dipakai kode mana pun',
          );
          for (final x in [kataId, kataEn]) {
            expect(
              x.toLowerCase(),
              isNot(contains('daluwarsa')),
              reason: '$kata',
            );
          }
        }
      },
    );

    test('PASS dan FAIL satu-satunya kata berkapital penuh (id)', () {
      final kapital = {
        for (final k in semua.keys)
          if (StatusTampil.dariKode(k).label(id) ==
              StatusTampil.dariKode(k).label(id).toUpperCase())
            StatusTampil.dariKode(k).label(id),
      };
      expect(kapital, {'PASS', 'FAIL'});
    });

    test('ikon yang sama selalu bernada sama (ikon + kata, bukan warna)', () {
      final nadaPerIkon = <IconData, NadaStempel>{};
      for (final k in semua.keys) {
        final s = StatusTampil.dariKode(k);
        final dulu = nadaPerIkon.putIfAbsent(s.ikon, () => s.nada);
        expect(dulu, s.nada, reason: '$k memakai ikon milik nada lain');
      }
    });

    test('kata baku brief (id) dan padanannya (en)', () {
      String l(String k, {String? keputusan}) =>
          StatusTampil.dariKode(k, keputusan: keputusan).label(id);
      expect(l('draft'), 'Draf');
      expect(l('menunggu_approval'), 'Menunggu');
      expect(l('perlu_revisi'), 'Perlu revisi');
      expect(l('disetujui'), 'Disetujui');
      expect(l('disetujui', keputusan: 'PASS'), 'PASS');
      expect(l('disetujui', keputusan: 'FAIL'), 'FAIL');
      expect(l('valid'), 'Berlaku');
      expect(l('warning'), 'Segera');
      expect(l('overdue'), 'Lewat jadwal');
      expect(l('expired'), 'Masa berlaku berakhir');
      expect(l('digantikan'), 'Digantikan revisi');
      expect(l('belum_terbit'), 'Belum terbit');
      expect(StatusTampil.dariKode('overdue').label(en), 'Overdue');
      expect(StatusTampil.dariKode('draft').label(en), 'Draft');
      expect(StatusTampil.dariKode('expired').label(en), 'Validity ended');
    });

    test(
      'label dokumen sertifikat: berlaku hijau, digantikan dan belum terbit netral',
      () {
        // "Berlaku" = sertifikat masih sah: kata dan nada yang sama dengan jadwal
        // "Berlaku" (lulus). Digantikan revisi dan belum terbit bukan kegagalan
        // dan bukan peringatan: netral (bergaris tepi).
        expect(StatusTampil.dariKode('berlaku').nada, NadaStempel.lulus);
        expect(
          StatusTampil.dariKode('berlaku'),
          StatusTampil.dariKode('valid'),
        );
        expect(StatusTampil.dariKode('digantikan').nada, NadaStempel.netral);
        expect(StatusTampil.dariKode('belum_terbit').nada, NadaStempel.netral);
        expect(StatusTampil.dariKode('dibatalkan').nada, NadaStempel.gagal);
        expect(StatusTampil.dariKode('ditarik').nada, NadaStempel.awas);
      },
    );

    test('nada: lulus, gagal, awas, tunggu, netral menurut arti', () {
      NadaStempel n(String k) => StatusTampil.dariKode(k).nada;
      expect(n('PASS'), NadaStempel.lulus);
      expect(n('FAIL'), NadaStempel.gagal);
      expect(n('overdue'), NadaStempel.gagal);
      expect(n('expired'), NadaStempel.gagal);
      expect(n('perlu_revisi'), NadaStempel.awas);
      expect(n('warning'), NadaStempel.awas);
      expect(n('menunggu_approval'), NadaStempel.tunggu);
      expect(n('draft'), NadaStempel.netral);
    });

    test('ikon "Baru" terbaca (bukan huruf NEW kecil)', () {
      expect(
        StatusTampil.dariKode('baru').ikon,
        isNot(Icons.fiber_new_outlined),
      );
    });

    test('jadwal: batas Segera 30 hari, lewat jadwal di bawah 0', () {
      expect(StatusTampil.jadwal(-1).label(id), 'Lewat jadwal');
      expect(StatusTampil.jadwal(-200).label(id), 'Lewat jadwal');
      expect(StatusTampil.jadwal(0).label(id), 'Segera');
      expect(StatusTampil.jadwal(1).label(id), 'Segera');
      expect(StatusTampil.jadwal(30).label(id), 'Segera');
      expect(StatusTampil.jadwal(31).label(id), 'Berlaku');
      expect(StatusTampil.jadwal(400).label(id), 'Berlaku');
      expect(StatusTampil.batasSegeraHari, 30);
    });

    test(
      'jadwal tanpa tanggal (hari null): lewat jadwal, tanpa menebak hari',
      () {
        expect(StatusTampil.jadwal(null).label(id), 'Lewat jadwal');
        expect(StatusTampil.jadwal(null).nada, NadaStempel.gagal);
      },
    );

    test('kode asing tampil apa adanya, bukan disembunyikan', () {
      final s = StatusTampil.dariKode('status_baru_dari_server');
      expect(s.label(id), 'status_baru_dari_server');
      expect(s.label(en), 'status_baru_dari_server');
      expect(s.kata, isNull);
      expect(s.nada, NadaStempel.netral);
      expect(StatusTampil.dariKode(null).label(id), '–');
    });

    test('warna nada mengikuti token tema (terang dan gelap)', () {
      for (final m in [
        SidikMaterial.terangDefault,
        SidikMaterial.gelapDefault,
      ]) {
        StatusTampil dari(NadaStempel n) =>
            StatusTampil(KataStatus.draf, n, Icons.circle);
        expect(dari(NadaStempel.lulus).warna(m), (m.lulus, m.lulusTipis));
        expect(dari(NadaStempel.gagal).warna(m), (m.gagal, m.gagalTipis));
        expect(dari(NadaStempel.awas).warna(m), (m.awas, m.awasTipis));
        expect(dari(NadaStempel.tunggu).warna(m), (m.tunggu, m.tungguTipis));
        expect(dari(NadaStempel.netral).warna(m).$1, m.tinta2);
      }
    });
  });

  group('Stempel', () {
    for (final gelap in [false, true]) {
      final tema = gelap ? 'gelap' : 'terang';
      testWidgets('ikon + kata, sudut 4, tinta + latar tipis ($tema)', (
        tester,
      ) async {
        final m = gelap
            ? SidikMaterial.gelapDefault
            : SidikMaterial.terangDefault;
        for (final k in ['PASS', 'FAIL', 'perlu_revisi', 'menunggu_approval']) {
          final s = StatusTampil.dariKode(k);
          await tester.pumpWidget(
            aplikasiUji(Center(child: Stempel(s)), gelap: gelap),
          );
          await tester.pumpAndSettle();
          final kata = s.label(id);
          expect(find.text(kata), findsOneWidget, reason: k);
          expect(find.byIcon(s.ikon), findsOneWidget, reason: k);
          final (tinta, latar) = s.warna(m);
          final dekor =
              tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byType(Stempel),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect(dekor.color, latar, reason: k);
          expect(
            dekor.borderRadius,
            BorderRadius.circular(BentukLab.stempel),
            reason: k,
          );
          expect(tester.widget<Icon>(find.byIcon(s.ikon)).color, tinta);
          expect(tester.widget<Text>(find.text(kata)).style?.color, tinta);
        }
      });
    }

    testWidgets('bahasa: Indonesia dan English dari ARB, bukan teks tetap', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      for (final (bahasa, l) in [('id', id), ('en', en)]) {
        for (final k in ['overdue', 'expired', 'digantikan', 'draft']) {
          final s = StatusTampil.dariKode(k);
          await tester.pumpWidget(
            aplikasiUji(Center(child: Stempel(s)), bahasa: bahasa),
          );
          final kata = s.label(l);
          expect(find.text(kata), findsOneWidget, reason: '$k/$bahasa');
          expect(
            find.bySemanticsLabel(l.stempelSemantik(kata)),
            findsOneWidget,
            reason: '$k/$bahasa',
          );
        }
      }
      await tester.pumpWidget(
        aplikasiUji(
          Center(child: Stempel(StatusTampil.dariKode('overdue'))),
          bahasa: 'en',
        ),
      );
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Lewat jadwal'), findsNothing);
      expect(find.bySemanticsLabel('Status: Overdue'), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('tidak hanya warna: tiap kode punya ikon DAN kata terbaca', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      for (final k in {..._kodeDariSistemLama(), ..._kodeDariEnum()}.keys) {
        final s = StatusTampil.dariKode(k);
        await tester.pumpWidget(aplikasiUji(Center(child: Stempel(s))));
        expect(find.byType(Icon), findsOneWidget, reason: k);
        expect(find.text(s.label(id)), findsOneWidget, reason: k);
        expect(
          find.bySemanticsLabel('Status: ${s.label(id)}'),
          findsOneWidget,
          reason: k,
        );
      }
      semantik.dispose();
    });

    testWidgets('netral (draf) bergaris tepi tanpa isi; tenang tanpa latar', (
      tester,
    ) async {
      final m = SidikMaterial.terangDefault;
      BoxDecoration dekorasi() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(Stempel),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      await tester.pumpWidget(
        aplikasiUji(Center(child: Stempel(StatusTampil.dariKode('draft')))),
      );
      expect(dekorasi().color, Colors.transparent);
      expect(dekorasi().border, isNotNull);
      expect((dekorasi().border! as Border).top.color, m.garisTegas);

      await tester.pumpWidget(
        aplikasiUji(
          Center(child: Stempel(StatusTampil.dariKode('PASS'), tenang: true)),
        ),
      );
      expect(dekorasi().color, isNull);
      expect(dekorasi().border, isNull);
      final tanpaBantalan = tester.getSize(find.byType(Stempel));
      await tester.pumpWidget(
        aplikasiUji(Center(child: Stempel(StatusTampil.dariKode('PASS')))),
      );
      expect(
        tester.getSize(find.byType(Stempel)).width,
        greaterThan(tanpaBantalan.width),
      );
    });

    testWidgets(
      'bukan tombol: tanpa aksi ketuk; pembaca layar "Status: kata"',
      (tester) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(Center(child: Stempel(StatusTampil.dariKode('overdue')))),
        );
        final node = tester.getSemantics(find.byType(Stempel));
        final data = node.getSemanticsData();
        expect(data.label, 'Status: Lewat jadwal');
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        semantik.dispose();
      },
    );

    for (final (gelap, bahasa) in [
      (false, 'id'),
      (true, 'id'),
      (false, 'en'),
    ]) {
      testWidgets('kata panjang membungkus di 160 dp, huruf 1,3x, tanpa luapan '
          '(${gelap ? 'gelap' : 'terang'}, $bahasa)', (tester) async {
        layarUji(tester, lebar: 320, tinggi: 640);
        await tester.pumpWidget(
          aplikasiUji(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 160,
                child: Stempel(StatusTampil.dariKode('expired')),
              ),
            ),
            gelap: gelap,
            skala: 1.3,
            bahasa: bahasa,
          ),
        );
        expect(tester.takeException(), isNull);
        final kata = StatusTampil.dariKode(
          'expired',
        ).label(bahasa == 'id' ? id : en);
        final teks = tester.renderObject<RenderParagraph>(find.text(kata));
        if (bahasa == 'id') {
          expect(barisTeks(teks).length, greaterThan(1), reason: 'membungkus');
        }
        expect(
          tester.getSize(find.byType(Stempel)).width,
          lessThanOrEqualTo(160),
        );
      });
    }

    testWidgets('ikon ikut skala huruf supaya sebaris dengan teks', (
      tester,
    ) async {
      final s = StatusTampil.dariKode('PASS');
      await tester.pumpWidget(aplikasiUji(Center(child: Stempel(s))));
      final satu = tester.getSize(find.byIcon(s.ikon)).width;
      await tester.pumpWidget(
        aplikasiUji(Center(child: Stempel(s)), skala: 1.3),
      );
      final besar = tester.getSize(find.byIcon(s.ikon)).width;
      expect(besar, closeTo(satu * 1.3, 0.01));
    });

    testWidgets('teks 13 sp berat 700 (huruf stempel), minimum 12 sp', (
      tester,
    ) async {
      final s = StatusTampil.dariKode('PASS');
      await tester.pumpWidget(aplikasiUji(Center(child: Stempel(s))));
      final gaya = tester.widget<Text>(find.text('PASS')).style!;
      expect(gaya.fontSize, 13);
      expect(gaya.fontWeight, FontWeight.w700);
      expect(gaya.fontSize, greaterThanOrEqualTo(12));
    });
  });
}
