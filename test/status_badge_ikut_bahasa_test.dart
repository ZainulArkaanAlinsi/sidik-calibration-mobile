import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/widgets/status_badge.dart';

/// Ketiga belas status di `StatusBadge` ikut bahasa yang sedang berlaku.
///
/// ## Kenapa berkas ini ada
///
/// `StatusBadge.fromApi` mengeja ketiga belas labelnya keras-keras, padahal
/// LIMA di antaranya sudah punya kunci l10n dan sudah dipakai layar lain:
///
/// ```
/// history_screen.dart:280            label: l10n.historyStatusMenungguApproval
/// calibration_detail_screen.dart:110 label: l10n.historyStatusMenungguApproval
/// certificate_screen.dart:610        label: l10n.historyStatusFail
/// alur_kerja_screen.dart:340         l10n.historyStatusMenungguApproval
/// status_badge.dart:71               label: 'Menunggu approval'   ← keras
/// ```
///
/// Jadi bukan sekadar "belum dilokalkan". Yang terjadi lebih buruk dan lebih
/// sulit dilihat: **status yang SAMA tampil dua bahasa di aplikasi yang sama.**
/// Pengguna locale Inggris membaca "Pending approval" di daftar Riwayat, lalu
/// "Menunggu approval" di daftar Alat, untuk sesi yang sama.
///
/// Tidak ada yang error waktu itu terjadi — sama seperti seluruh temuan audit
/// di PR sebelahnya. Yang berubah cuma satu kata di layar yang jarang dibuka
/// bersamaan.
///
/// ## Yang dijaga di sini
///
/// 1. Tiap kode status punya kata-katanya di KEDUA locale — tidak ada yang
///    diam-diam jatuh ke kode mentahnya.
/// 2. Yang lima itu memakai **string yang sama persis** dengan yang dipakai
///    layar lain. Ini yang menahan drift-nya kembali: kunci baru yang isinya
///    sama bakal lolos test bahasa biasa, tapi merah di sini.
/// 3. Nada & ikonnya TIDAK ikut bahasa. Itu bagian yang dipertaruhkan buat
///    teknisi yang buta warna, dan dia tidak boleh bergantung pada locale.
void main() {
  late AppLocalizations id;
  late AppLocalizations en;

  setUpAll(() async {
    id = await AppLocalizations.delegate.load(const Locale('id'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Ketiga belas kode yang dikenali `fromApi`, apa adanya dari
  /// `docs/kontrak-api.md`.
  const semuaKode = [
    'PASS',
    'FAIL',
    'aktif',
    'overdue',
    'nonaktif',
    'draft',
    'menunggu_approval',
    'disetujui',
    'perlu_revisi',
    'baru',
    'diproses',
    'selesai',
    'dibatalkan',
  ];

  /// `PASS` dan `FAIL` sengaja dikecualikan dari pemeriksaan "label != kode".
  ///
  /// Labelnya memang **"PASS"** dan **"FAIL"** — sama persis dengan kodenya, di
  /// kedua bahasa — karena keduanya tercetak apa adanya di sertifikat.
  ///
  /// Jadi buat dua kode ini "label == kode" bukan tanda jatuh ke fallback, dan
  /// tidak ada test kotak-hitam yang bisa membedakan keduanya: cabang yang
  /// benar dan cabang `_ => value` sama-sama memulangkan string yang sama.
  /// Memaksa keduanya berbeda berarti menerjemahkan istilah yang tidak boleh
  /// diterjemahkan.
  ///
  /// Yang menjaga dua kode ini test berikutnya — diadu langsung ke
  /// `l10n.historyStatusPass`/`Fail`. Itu pemeriksaan yang memang bisa
  /// membedakan: kalau cabangnya hilang, hasilnya tetap "PASS" tapi bukan lagi
  /// nilai yang dibaca dari ARB.
  const labelnyaMemangSamaDenganKode = {'PASS', 'FAIL'};

  group('semua status punya kata-katanya', () {
    test('nggak ada yang jatuh ke kode mentah, di dua-dua bahasa', () {
      for (final kode in semuaKode) {
        for (final (nama, l10n) in [('id', id), ('en', en)]) {
          final label = StatusBadge.labelApi(kode, l10n);

          expect(
            label,
            isNotEmpty,
            reason: 'Status `$kode` labelnya kosong di locale $nama.',
          );

          if (labelnyaMemangSamaDenganKode.contains(kode)) continue;

          expect(
            label,
            isNot(kode),
            reason:
                'Status `$kode` jatuh ke kode mentahnya di locale $nama — '
                'berarti dia belum punya cabang di `labelApi`.',
          );
        }
      }
    });

    /// INTI-nya. Bukan "sudah diterjemahkan", tapi "diterjemahkan ke string
    /// YANG SAMA dengan yang dipakai layar lain".
    ///
    /// Kunci baru yang isinya kebetulan sama akan lolos test bahasa biasa dan
    /// merah di sini — dan itu memang yang diinginkan: dua kunci untuk satu
    /// status berarti dua terjemahan yang bisa bergeser sendiri-sendiri nanti.
    test('lima status berbagi kunci yang sama dengan layar lain', () {
      for (final l10n in [id, en]) {
        expect(StatusBadge.labelApi('PASS', l10n), l10n.historyStatusPass);
        expect(StatusBadge.labelApi('FAIL', l10n), l10n.historyStatusFail);
        expect(StatusBadge.labelApi('draft', l10n), l10n.historyStatusDraft);
        expect(
          StatusBadge.labelApi('menunggu_approval', l10n),
          l10n.historyStatusMenungguApproval,
        );
        expect(
          StatusBadge.labelApi('perlu_revisi', l10n),
          l10n.historyStatusPerluRevisi,
        );
      }
    });

    /// Bukti bahwa bahasanya benar-benar berpindah, bukan cuma "ada kuncinya".
    ///
    /// `PASS`/`FAIL`/`Draft` sengaja TIDAK diadu di sini: ketiganya memang sama
    /// di dua bahasa, dan memaksanya berbeda berarti menerjemahkan istilah yang
    /// tercetak apa adanya di sertifikat.
    test('locale Inggris beneran ngasih kata Inggris', () {
      expect(StatusBadge.labelApi('menunggu_approval', en), 'Pending approval');
      expect(StatusBadge.labelApi('menunggu_approval', id), 'Menunggu approval');

      expect(StatusBadge.labelApi('overdue', en), 'Overdue');
      expect(StatusBadge.labelApi('overdue', id), 'Jatuh tempo');

      expect(StatusBadge.labelApi('dibatalkan', en), 'Cancelled');
      expect(StatusBadge.labelApi('dibatalkan', id), 'Dibatalkan');
    });

    /// JANGAN kebablasan: status baru dari backend tetap tampil apa adanya.
    ///
    /// Menerjemahkannya mustahil, dan menyembunyikannya lebih buruk — kalau
    /// backend menambah status, yang benar itu kelihatan di layar, bukan jadi
    /// pil kosong.
    test('status yang belum dikenal tetap tampil apa adanya', () {
      for (final l10n in [id, en]) {
        expect(StatusBadge.labelApi('status_yang_belum_ada', l10n), 'status_yang_belum_ada');
      }
    });
  });

  /// Nada & ikon sengaja dipisah dari bahasanya, dan pemisahan itu yang diuji
  /// di sini — bukan nilai satu per satu (itu sudah dijaga
  /// `badge_status_order_test.dart`).
  group('arti visualnya nggak ikut bahasa', () {
    test('nada & ikon sama persis di dua locale', () {
      for (final kode in semuaKode) {
        final arti = StatusBadge.artiApi(kode);

        expect(
          StatusBadge.fromApi(kode).tone,
          arti.nada,
          reason: 'Nada `$kode` bergeser dari `artiApi`.',
        );
        expect(StatusBadge.fromApi(kode).icon, arti.ikon);
      }
    });

    /// `artiApi` tidak menerima `AppLocalizations` sama sekali — itu penjagaan
    /// struktural, bukan kebetulan. Kalau suatu hari ada yang menyelipkan
    /// bahasa ke dalamnya, badge buta-warna jadi bergantung pada locale.
    test('tiap kode punya nada, dan yang dikenal nggak ada yang neutral tanpa ikon', () {
      for (final kode in semuaKode) {
        final arti = StatusBadge.artiApi(kode);

        expect(
          arti.ikon,
          isNotNull,
          reason:
              'Status `$kode` nggak punya ikon — warna doang nggak cukup buat '
              'teknisi yang buta warna.',
        );
      }

      // Yang TIDAK dikenal memang tidak punya ikon, dan itu benar: ikon
      // karangan buat status yang tidak dimengerti lebih menyesatkan daripada
      // pil polos.
      expect(StatusBadge.artiApi('status_yang_belum_ada').ikon, isNull);
      expect(
        StatusBadge.artiApi('status_yang_belum_ada').nada,
        BadgeTone.neutral,
      );
    });
  });

  /// Konstruktor eksplisit — jalur yang **nol test**-nya sampai PR ini, dan
  /// yang bikin empat golden merah.
  ///
  /// Waktu labelnya dipindah ke l10n, ketiga getter-nya ditulis dengan `??`:
  ///
  /// ```dart
  /// IconData? get icon => _icon ?? artiApi(_kodeApi!).ikon;
  /// ```
  ///
  /// Buat `StatusBadge.fromApi` itu benar. Buat konstruktor eksplisit `icon`
  /// memang BOLEH null — tiga pemanggil tidak mengirimnya — dan di situ `??`
  /// membaca "tidak ada ikon" sebagai "berarti pakai jalur kode API", lalu
  /// `_kodeApi!` meledak di tengah `build()`.
  ///
  /// Yang mahal bukan bug-nya, tapi bagaimana dia muncul: `flutter analyze`
  /// diam (tipenya sah), `flutter build web` hijau (dia cuma mengompilasi),
  /// dan yang merah cuma golden — sebagai `RenderErrorBox` 100000px di
  /// `profile_screen`, layar yang tidak disentuh PR ini sama sekali. Butuh
  /// pembacaan jejak layout buat sampai ke `status_badge.dart`.
  ///
  /// Jadi yang dijaga di sini bukan "labelnya benar", tapi **kedua konstruktor
  /// itu dua jalur, dan yang menentukan jalurnya kode API — bukan null-nya
  /// masing-masing field.**
  group('konstruktor eksplisit', () {
    /// Persis bentuk `profile_screen.dart:1385`, `history_screen.dart:266` dan
    /// `calibration_detail_screen.dart:96`: label + nada, tanpa ikon.
    test('tanpa ikon: kebaca null, bukan meledak', () {
      const badge = StatusBadge(label: 'Aktif', tone: BadgeTone.success);

      expect(badge.icon, isNull);
      expect(badge.tone, BadgeTone.success);
      expect(badge.labelUntuk(id), 'Aktif');
      expect(badge.labelUntuk(en), 'Aktif');
    });

    test('dengan ikon: ikonnya kepakai apa adanya', () {
      const badge = StatusBadge(
        label: 'Selesai',
        tone: BadgeTone.info,
        icon: Icons.task_alt,
      );

      expect(badge.icon, Icons.task_alt);
      expect(badge.tone, BadgeTone.info);
    });

    /// Labelnya eksplisit, jadi dia TIDAK boleh ikut bahasa — pemanggilnya
    /// sudah menerjemahkan sendiri (`l10n.historyStatusFail` dan kawan-kawan).
    /// Kalau suatu saat `labelUntuk` mulai melirik `_kodeApi` duluan, yang
    /// tercetak jadi kode mentah dan test ini yang merah.
    test('label eksplisit nggak ikut ditimpa bahasa', () {
      const badge = StatusBadge(label: 'Tidak lolos', tone: BadgeTone.danger);

      expect(badge.labelUntuk(id), 'Tidak lolos');
      expect(badge.labelUntuk(en), 'Tidak lolos');
    });

    /// Yang benar-benar diadu golden: badge tanpa ikon harus **ter-render**,
    /// bukan cuma getter-nya tidak melempar. `pumpWidget` menelan exception
    /// dari `build()` dan menggantinya dengan `ErrorWidget`, jadi tanpa
    /// `takeException()` test ini bisa hijau sambil layarnya merah.
    testWidgets('tanpa ikon: ke-render, bukan kotak error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: StatusBadge(label: 'Aktif', tone: BadgeTone.success),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

}
