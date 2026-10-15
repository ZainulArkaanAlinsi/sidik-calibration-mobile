import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/navigasi_global.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/kabar_toast.dart';
import 'package:sidik_calibration/models/notification_item.dart';
import 'package:sidik_calibration/providers/kabar_masuk_provider.dart';
import 'package:sidik_calibration/providers/notifikasi_perangkat_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/services/kabar_push.dart';
import 'package:sidik_calibration/services/notifikasi_perangkat.dart';
import 'package:sidik_calibration/widgets/lapisan_kabar_masuk.dart';
import 'package:sidik_calibration/widgets/notification_bell.dart';

class _CatatNavigasi extends PenavigasiKabar {
  final tujuan = <NotifTautan?>[];
  int daftar = 0;

  @override
  void bukaTujuan(NotifTautan? tautan) => tujuan.add(tautan);

  @override
  void bukaDaftar() => daftar++;
}

class _UnreadPalsu extends UnreadCount {
  @override
  Future<int> build() async => 0;

  void setel(int n) => state = AsyncValue.data(n);
}

KabarToast _kabar(String judul, {String? id, NotifTautan? tautan}) =>
    KabarToast(judul: judul, isi: 'isi $judul', tautan: tautan, kunci: id);

Widget _app(
  _CatatNavigasi nav, {
  bool kurangiGerak = false,
  Widget? home,
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [penavigasiKabarProvider.overrideWithValue(nav), ...extra],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: kurangiGerak),
        child: LapisanKabarMasuk(child: child!),
      ),
      home:
          home ??
          Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: SizedBox(
              height: 72,
              child: FilledButton(
                key: const ValueKey('aksi_utama'),
                onPressed: () {},
                child: const Text('Kirim'),
              ),
            ),
          ),
    ),
  );
}

ProviderContainer _wadah(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first));

double _opasitas(WidgetTester t) => t
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('kartu_kabar_masuk')),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('toast kabar masuk', () {
    testWidgets('tampil geser+pudar <=300 ms, hilang sendiri 5 detik', (
      t,
    ) async {
      await t.pumpWidget(_app(_CatatNavigasi()));
      expect(find.text('Lembar masuk'), findsNothing);

      _wadah(
        t,
      ).read(kabarMasukProvider.notifier).tambahkan([_kabar('Lembar masuk')]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_opasitas(t), inInclusiveRange(0.01, 0.99));

      await t.pump(const Duration(milliseconds: 240)); // total 300 ms
      expect(_opasitas(t), 1.0);
      expect(find.text('Lembar masuk'), findsOneWidget);

      await t.pump(const Duration(milliseconds: 4600)); // ~4,9 s
      expect(find.text('Lembar masuk'), findsOneWidget);

      await t.pump(const Duration(milliseconds: 200)); // 5,1 s: mulai keluar
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Lembar masuk'), findsNothing);
    });

    testWidgets('beberapa kabar menumpuk jadi satu n kabar baru', (t) async {
      await t.pumpWidget(_app(_CatatNavigasi()));
      final n = _wadah(t).read(kabarMasukProvider.notifier);

      n.tambahkan([_kabar('A', id: '1')]);
      await t.pump(const Duration(milliseconds: 300));
      n.tambahkan([_kabar('B', id: '2'), _kabar('C', id: '3')]);
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('3 kabar baru'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.byKey(const ValueKey('kartu_kabar_masuk')), findsOneWidget);

      // Kabar baru menyetel ulang hitung mundur: 4 detik kemudian masih ada.
      await t.pump(const Duration(seconds: 4));
      expect(find.text('3 kabar baru'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('3 kabar baru'), findsNothing);
    });

    testWidgets('kabar kembar (push + inbox) dihitung satu', (t) async {
      await t.pumpWidget(_app(_CatatNavigasi()));
      final n = _wadah(t).read(kabarMasukProvider.notifier);

      n.tambahkan([_kabar('A', id: 'x')]);
      n.tambahkan([_kabar('A', id: 'x')]); // id sama
      n.tambahkan([const KabarToast(judul: 'A', isi: 'isi A')]); // tanpa id
      expect(_wadah(t).read(kabarMasukProvider), hasLength(1));

      n.tambahkan([_kabar('A', id: 'y')]); // id lain: kejadian lain
      expect(_wadah(t).read(kabarMasukProvider), hasLength(2));
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('ketukan satu kabar buka tujuan; banyak kabar buka daftar', (
      t,
    ) async {
      final nav = _CatatNavigasi();
      await t.pumpWidget(_app(nav));
      final n = _wadah(t).read(kabarMasukProvider.notifier);
      const tujuan = NotifTautan(tipe: 'calibration', id: 12);

      n.tambahkan([_kabar('A', id: '1', tautan: tujuan)]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('kartu_kabar_masuk')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      expect(nav.tujuan.single?.id, 12);
      expect(nav.tujuan.single?.tipe, 'calibration');
      expect(nav.daftar, 0);
      expect(find.text('A'), findsNothing);

      n.tambahkan([_kabar('B', id: '2'), _kabar('C', id: '3')]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('kartu_kabar_masuk')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      expect(nav.daftar, 1);
      expect(nav.tujuan, hasLength(1));
    });

    testWidgets('kurangi gerak: muncul langsung tanpa animasi', (t) async {
      await t.pumpWidget(_app(_CatatNavigasi(), kurangiGerak: true));
      _wadah(t).read(kabarMasukProvider.notifier).tambahkan([_kabar('A')]);
      await t.pump(); // satu frame saja

      expect(find.text('A'), findsOneWidget);
      expect(_opasitas(t), 1.0);

      await t.pump(const Duration(seconds: 5));
      await t.pump();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('di atas layar dan tidak menutup tombol aksi utama', (t) async {
      await t.pumpWidget(_app(_CatatNavigasi()));
      _wadah(t).read(kabarMasukProvider.notifier).tambahkan([_kabar('A')]);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      final kartu = t.getRect(find.byKey(const ValueKey('kartu_kabar_masuk')));
      final tombol = t.getRect(find.byKey(const ValueKey('aksi_utama')));

      expect(kartu.top, lessThan(100));
      expect(kartu.overlaps(tombol), isFalse);
      await t.pump(const Duration(seconds: 6));
    });
  });

  group('tujuan dan push foreground', () {
    test('bacaTujuan: tipe:id, tipe/id, /tipe/id; sisanya null', () {
      expect(bacaTujuan('calibration:12')?.id, 12);
      expect(bacaTujuan('calibration/12')?.tipe, 'calibration');
      expect(bacaTujuan('/calibration/12')?.id, 12);
      expect(bacaTujuan(''), isNull);
      expect(bacaTujuan(null), isNull);
      expect(bacaTujuan('calibration/abc'), isNull);
    });

    test('Firebase tidak hidup: tanpa langganan, tanpa error', () async {
      var disentuh = false;
      final sumber = FcmSumberKabarPush(
        firebaseHidup: () => false,
        aliran: Stream.fromFuture(
          Future(() {
            disentuh = true;
            return const RemoteMessage();
          }),
        ),
      );

      expect(await sumber.kabar.toList(), isEmpty);
      expect(disentuh, isFalse);
    });

    test('jalur default tanpa initializeApp: kosong, tidak melempar', () async {
      expect(await FcmSumberKabarPush().kabar.toList(), isEmpty);
    });

    test('Firebase hidup: onMessage jadi KabarToast', () async {
      final sumber = FcmSumberKabarPush(
        firebaseHidup: () => true,
        aliran: Stream.fromIterable(const [
          RemoteMessage(
            notification: RemoteNotification(
              title: 'Sertifikat terbit',
              body: 'CAL/1',
            ),
            data: {
              'kategori': 'sertifikat_terbit',
              'tujuan': 'calibration:7',
              'notification_id': 'abc',
            },
          ),
          RemoteMessage(data: {'sinkron': '1'}), // data-only: diabaikan
        ]),
      );

      final hasil = await sumber.kabar.toList();
      expect(hasil, hasLength(1));
      expect(hasil.single.judul, 'Sertifikat terbit');
      expect(hasil.single.kategori, NotifKategori.sertifikatTerbit);
      expect(hasil.single.tautan?.id, 7);
      expect(hasil.single.kunci, 'abc');
    });

    test('TanpaKabarPush tidak memancarkan apa pun', () async {
      expect(await const TanpaKabarPush().kabar.toList(), isEmpty);
    });
  });

  group('PengabarNotifikasi dan toast', () {
    NotificationItem notif(String id) => NotificationItem(
      id: id,
      kategori: NotifKategori.sesiMenungguApproval,
      judul: 'Lembar masuk',
      isi: 'sesi $id',
      dibaca: false,
      dibuatPada: DateTime(2026, 10, 16),
    );

    test('di depan: toast saja; di latar: bilah sistem saja', () async {
      final perangkat = MockNotifikasiPerangkat();
      final toast = <NotificationItem>[];
      var depan = true;
      final pengabar = PengabarNotifikasi(
        perangkat,
        kabarBaru: toast.addAll,
        diLayarDepan: () => depan,
      );

      await pengabar.mulai([]);
      await pengabar.umumkan([notif('a')]);
      expect(toast.map((n) => n.id), ['a']);
      expect(perangkat.ditampilkan, isEmpty);

      depan = false;
      await pengabar.umumkan([notif('b'), notif('a')]);
      expect(perangkat.ditampilkan.map((n) => n.id), ['b']);
      expect(toast, hasLength(1));
    });
  });

  group('lonceng', () {
    Future<_UnreadPalsu> pasang(
      WidgetTester t, {
      bool kurangiGerak = false,
    }) async {
      await t.pumpWidget(
        _app(
          _CatatNavigasi(),
          kurangiGerak: kurangiGerak,
          extra: [unreadCountProvider.overrideWith(_UnreadPalsu.new)],
          home: Scaffold(appBar: AppBar(actions: const [NotificationBell()])),
        ),
      );
      await t.pump();
      return _wadah(t).read(unreadCountProvider.notifier) as _UnreadPalsu;
    }

    double sudut(WidgetTester t) => t
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(NotificationBell),
            matching: find.byType(Transform),
          ),
        )
        .where((w) => w.alignment == Alignment.topCenter)
        .map((w) => w.transform.getRotation().entry(0, 1).abs())
        .first;

    testWidgets('angka naik: lonceng berayun lalu diam', (t) async {
      final un = await pasang(t);
      expect(sudut(t), 0);

      un.setel(1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(sudut(t), greaterThan(0.01));

      await t.pump(const Duration(milliseconds: 700));
      expect(sudut(t), lessThan(0.001));
    });

    testWidgets('angka turun: tidak berayun', (t) async {
      final un = await pasang(t);
      un.setel(2);
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      un.setel(1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(sudut(t), lessThan(0.001));
    });

    testWidgets('kurangi gerak: tidak berayun', (t) async {
      final un = await pasang(t, kurangiGerak: true);
      un.setel(3);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(sudut(t), 0);
    });
  });
}
