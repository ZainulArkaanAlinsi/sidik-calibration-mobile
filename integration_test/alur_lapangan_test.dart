import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/main.dart' as app;
import 'package:sidik_calibration/screens/admin/antrean_approval_screen.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/auth/onboarding_screen.dart';
import 'package:sidik_calibration/screens/calibration/category_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/dashboard/dashboard_screen.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/screens/equipment/equipment_list_screen.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/screens/settings/customer_list_screen.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/screens/settings/standard_list_screen.dart';
import 'package:sidik_calibration/screens/settings/technician_list_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';

import 'pembantu_e2e.dart';

/// E2E app lapangan: app SUNGGUHAN (`main()`) di emulator melawan server API
/// lokal SUNGGUHAN — SALINAN DB di port 8010, karena alur ini MENULIS (sesi
/// kalibrasi). Jangan arahkan ke server yang dipakai tablet.
///
/// Teknisi: masuk → dashboard → daftar alat → Mulai kalibrasi → pH Meter →
/// pilih alat → isi tabel After adjustment 3 titik × 5 Repeat → simpan draft
/// → buka lagi dari Draf (angka harus kembali) → kirim ke admin → Riwayat →
/// keluar. Admin: masuk → Antrean Approval memuat sesi tadi → Kelola lab
/// (Pelanggan, Standar Acuan, Data Teknisi) → keluar.
///
/// TIDAK diuji di sini (butuh perangkat fisik / layanan luar): kamera & foto
/// tabel (ML Kit), push FCM (build uji tanpa `google-services.json`),
/// pemasangan pembaruan APK. Data acuan tidak punya pintu di app lapangan
/// (hanya di Studio).
///
/// Jalankan lewat `sidik-studio-lokal\uji-e2e.ps1`, atau:
/// ```
/// flutter test integration_test/alur_lapangan_test.dart -d emulator-5554 \
///   --dart-define=API_BASE_URL=http://10.0.2.2:8010/api \
///   --dart-define=E2E_ID=<admin> --dart-define=E2E_ID_TEKNISI=<teknisi> \
///   --dart-define=E2E_SANDI=<sandi fixture lokal>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'alur lapangan: teknisi isi & kirim pH Meter, admin lihat antrean & master',
    (tester) async {
      if (e2eId.isEmpty || e2eIdTeknisi.isEmpty || e2eSandi.isEmpty) {
        fail('E2E_ID / E2E_ID_TEKNISI / E2E_SANDI belum diberikan');
      }
      final c = CatatanE2E('lapangan', tester);

      await c.langkah(tester, 'buka aplikasi', () async {
        await app.main();
        await tunggu(
          tester,
          () => ada(find.byType(LoginScreen)) || ada(find.byType(MainShell)),
          alasan: 'layar login atau shell tampil',
        );
        if (ada(find.byType(MainShell))) await _keluar(tester);
      });

      // ───────────────────────────────────────────────────────── teknisi
      await c.langkah(tester, 'masuk sebagai teknisi', () async {
        await c.potret(tester, 'login');
        await _masuk(tester, e2eIdTeknisi);
      });

      await c.langkah(tester, 'dashboard teknisi', () async {
        await tunggu(
          tester,
          () => ada(find.text('Mulai kalibrasi')),
          alasan: 'dashboard teknisi (tombol Mulai kalibrasi)',
        );
        await jeda(tester, 800);
        _pastikanTanpaPesanGagal('dashboard');
        await c.potret(tester, 'dashboard-teknisi');
      });

      await c.langkah(tester, 'daftar alat', () async {
        await ketuk(tester, find.text('Alat').last);
        await tunggu(
          tester,
          () => ada(
            find.descendant(
              of: find.byType(EquipmentListScreen),
              // Kartu alat privat di layarnya — dicocokkan lewat nama tipe.
              matching: find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_EquipmentCard',
              ),
            ),
          ),
          alasan: 'kartu alat tampil',
        );
        _pastikanTanpaPesanGagal('daftar alat');
        await c.potret(tester, 'daftar-alat');
        await ketuk(tester, find.text('Dashboard').last);
        await tunggu(
          tester,
          () => ada(find.text('Mulai kalibrasi')),
          alasan: 'kembali ke dashboard',
        );
      });

      await c.langkah(tester, 'Mulai kalibrasi → pH Meter', () async {
        await ketuk(tester, find.text('Mulai kalibrasi').first);
        await tunggu(
          tester,
          () => ada(find.text('Instrumen Analitik')),
          alasan: 'daftar kategori',
        );
        _pastikanTanpaPesanGagal('kategori');
        await ketuk(tester, find.text('Instrumen Analitik'));
        await tunggu(
          tester,
          () => ada(find.text('pH Meter')),
          alasan: 'daftar instrumen analitik',
        );
        await ketuk(tester, find.text('pH Meter').first);
        await _tungguLembar(tester);
        await c.potret(tester, 'lembar-ph-kosong');
      });

      await c.langkah(tester, 'pilih alat pH Meter B628755900', () async {
        // Label melayang dropdown sendiri tidak menerima ketukan — yang
        // diketuk kotak dropdown-nya.
        await ketuk(
          tester,
          find.ancestor(
            of: find.text('Pilih alat'),
            matching: find.byWidgetPredicate(
              (w) => w is DropdownButtonFormField,
            ),
          ),
        );
        await jeda(tester, 800);
        await ketuk(tester, find.textContaining('B628755900'));
        await jeda(tester, 1200);
        expect(find.text('pH Meter · B628755900'), findsWidgets);
        _pastikanTanpaPesanGagal('pilih alat');
      });

      await c.langkah(
        tester,
        'isi tabel After adjustment (3 titik × 5)',
        () async {
          await ketuk(tester, find.text('Lanjut ke halaman berikutnya'));
          await tunggu(
            tester,
            () => ada(find.text('Halaman 2 dari 2')),
            alasan: 'halaman 2 lembar kerja',
          );
          await _isiTabelAfter(tester);
          await c.potret(tester, 'lembar-ph-terisi');
        },
      );

      await c.langkah(tester, 'simpan sebagai draft', () async {
        await ketuk(tester, find.text('Simpan sebagai draft'));
        await tunggu(
          tester,
          () =>
              ada(find.text('Tersimpan sebagai draft.')) ||
              ada(find.textContaining('Gagal menyimpan')),
          alasan: 'balasan simpan draft',
          batas: const Duration(seconds: 120),
        );
        if (ada(find.textContaining('Gagal menyimpan'))) {
          throw TestFailure(
            'simpan draft gagal: ${teksTerlihat().join(' | ')}',
          );
        }
        await tunggu(
          tester,
          () => !ada(find.byType(LembarKerjaScreen)),
          alasan: 'lembar ditutup sesudah simpan',
        );
        // Kembali ke shell: tutup pemilih instrumen & kategori.
        await _kembaliKeShell(tester);
      });

      await c.langkah(tester, 'buka draft lagi: angka kembali utuh', () async {
        await ketuk(tester, find.byTooltip('Menu utama').first);
        await jeda(tester, 700);
        await ketuk(tester, find.widgetWithText(ListTile, 'Draf'));
        await tunggu(
          tester,
          () =>
              ada(find.byType(DrafScreen)) &&
              ada(
                find.descendant(
                  of: find.byType(DrafScreen),
                  matching: find.textContaining('pH Meter'),
                ),
              ),
          alasan: 'kartu draft pH Meter di layar Draf',
        );
        _pastikanTanpaPesanGagal('Draf');
        await c.potret(tester, 'draf');
        await ketuk(
          tester,
          // Kartu draf (ber-ikon edit_note); teks "pH Meter" pertama adalah
          // kepala kelompok, bukan kartu yang bisa dibuka.
          find.descendant(
            of: find.byType(DrafScreen),
            matching: find.byIcon(Icons.edit_note),
          ),
        );
        await _tungguLembar(tester);
        // Alat sesi dipulihkan sesudah detail sesi termuat (async) — sebelum
        // perbaikan 13 Okt dropdown ini tetap "Pilih" selamanya.
        await tunggu(
          tester,
          () => ada(find.text('pH Meter · B628755900')),
          alasan: 'alat draft (pH Meter · B628755900) dipulihkan',
          batas: const Duration(seconds: 45),
        );
        await ketuk(tester, find.text('Lanjut ke halaman berikutnya'));
        await tunggu(
          tester,
          () => ada(find.text('Halaman 2 dari 2')),
          alasan: 'halaman 2 draft',
        );
        final kotak = await _kotakTabelAfter(tester);
        final pertama = tester.widget<TextField>(kotak.at(0)).controller?.text;
        final titik7 = tester.widget<TextField>(kotak.at(10)).controller?.text;
        // ignore: avoid_print
        print(
          'E2E|info|lapangan|draft dipulihkan: R1 4=$pertama, R1 7=$titik7',
        );
        expect(_angka(pertama), 4.0, reason: 'R1 titik 4 dari draft');
        expect(_angka(titik7), 7.01, reason: 'R1 titik 7 dari draft');
      });

      await c.langkah(tester, 'kirim ke admin', () async {
        await ketuk(tester, find.text('Kirim ke admin'));
        await jeda(tester, 800);
        // Dialog konfirmasi angka + peringatan (bila ada) — disetujui.
        for (var i = 0; i < 4; i++) {
          final setuju = [
            find.text('Kirim sekarang'),
            find.text('Angkanya emang segitu — kirim'),
          ].where(ada).firstOrNull;
          if (setuju == null) break;
          await c.potret(tester, 'konfirmasi-kirim-$i');
          await ketuk(tester, setuju.last);
          await jeda(tester, 800);
        }
        await tunggu(
          tester,
          () =>
              ada(find.text('Lembar kerja terkirim ke admin.')) ||
              ada(find.textContaining('Gagal menyimpan')) ||
              !ada(find.byType(LembarKerjaScreen)),
          alasan: 'balasan kirim',
          batas: const Duration(seconds: 120),
        );
        if (ada(find.textContaining('Gagal menyimpan'))) {
          throw TestFailure('kirim gagal: ${teksTerlihat().join(' | ')}');
        }
        await tunggu(
          tester,
          () => !ada(find.byType(LembarKerjaScreen)),
          alasan: 'lembar ditutup sesudah kirim',
        );
        // Kembali di layar Draf: drafnya harus keluar dari daftar (status
        // pindah ke menunggu approval).
        await tunggu(
          tester,
          () => ada(find.text('Belum ada draf')),
          alasan: 'layar Draf kosong sesudah draft dikirim',
        );
        await _kembaliKeShell(tester);
      });

      await c.langkah(tester, 'riwayat: sesi terkirim, draft habis', () async {
        await ketuk(tester, find.text('Riwayat').last);
        await jeda(tester, 500);
        final segarkan = find.byTooltip('Segarkan daftar').hitTestable();
        if (ada(segarkan)) await ketuk(tester, segarkan.first);
        await tunggu(
          tester,
          () => ada(
            find.descendant(
              of: find.byType(HistoryScreen),
              matching: find.text('Menunggu approval'),
            ),
          ),
          alasan: 'riwayat memuat sesi menunggu approval',
        );
        _pastikanTanpaPesanGagal('riwayat');
        await c.potret(tester, 'riwayat-teknisi');
        expect(
          find.descendant(
            of: find.byType(HistoryScreen),
            matching: find.text('Draft'),
          ),
          findsNothing,
          reason: 'draft pH Meter sudah terkirim, tidak boleh tinggal Draft',
        );
      });

      await c.langkah(tester, 'teknisi keluar', () async {
        await _keluar(tester);
      });

      // ───────────────────────────────────────────────────────── admin
      await c.langkah(tester, 'masuk sebagai admin', () async {
        await _masuk(tester, e2eId);
        await tunggu(
          tester,
          () => ada(find.byType(DashboardScreen)),
          alasan: 'dashboard admin',
        );
        await jeda(tester, 1500);
        _pastikanTanpaPesanGagal('dashboard admin');
        await c.potret(tester, 'dashboard-admin');
      });

      if (e2eAdminLaci) {
        await c.langkah(tester, 'admin: Kelola lab → data master', () async {
          await _bukaMenu(tester, 'Kelola lab');
          await tunggu(
            tester,
            () => ada(find.byType(KelolaLabScreen)),
            alasan: 'layar Kelola lab',
          );
          await c.potret(tester, 'kelola-lab');
          for (final (judul, tipe) in [
            ('Pelanggan', CustomerListScreen),
            ('Standar Acuan', StandardListScreen),
            ('Data Teknisi', TechnicianListScreen),
          ]) {
            await ketuk(tester, find.text(judul).first);
            await tunggu(
              tester,
              () => ada(find.byType(tipe)),
              alasan: 'layar $judul',
            );
            // Termuat = tidak ada indikator memuat dan ada isi selain judul.
            await tunggu(
              tester,
              () =>
                  !ada(
                    find.descendant(
                      of: find.byType(tipe),
                      matching: find.byWidgetPredicate(
                        (w) => w is ProgressIndicator,
                      ),
                    ),
                  ) &&
                  find
                          .descendant(
                            of: find.byType(tipe),
                            matching: find.byType(Text),
                          )
                          .evaluate()
                          .length >=
                      4,
              alasan: 'isi daftar $judul',
            );
            _pastikanTanpaPesanGagal(judul);
            await c.potret(tester, 'master-$judul');
            await _tutupLayar(tester);
            await tunggu(
              tester,
              () => !ada(find.byType(tipe)),
              alasan: 'kembali dari $judul',
            );
          }
          await _tutupLayar(tester);
        });

        await c.langkah(
          tester,
          'admin: antrean approval memuat sesi pH',
          () async {
            await _bukaMenu(tester, 'Antrean Approval');
            await tunggu(
              tester,
              () => ada(
                find.descendant(
                  of: find.byType(AntreanApprovalScreen),
                  matching: find.textContaining('pH Meter'),
                ),
              ),
              alasan: 'sesi pH Meter di antrean approval',
            );
            _pastikanTanpaPesanGagal('antrean approval');
            await c.potret(tester, 'antrean-approval');
            await _tutupLayar(tester);
          },
        );
      } else {
        // ignore: avoid_print
        print(
          'E2E|lewat|lapangan|admin lewat laci (Kelola lab, Antrean Approval)',
        );
      }

      await c.langkah(tester, 'admin keluar', () async {
        await _keluar(tester);
        await c.potret(tester, 'sesudah-keluar');
      });

      c.selesai();
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

// ─────────────────────────────────────────────────────────────── pembantu

/// Rata-rata After adjustment per titik dari `Master Olah Data_pH for
/// trial_CSV/PERHITUNGAN.csv` baris 37–41 (sertifikat 012-CAL-524) — angka
/// yang sama dengan `test/lembar_kerja_test.dart`, bukan karangan.
const _after = [
  ['4', '4', '4', '4', '4'],
  ['7,01', '7,01', '7', '7', '7'],
  ['10,11', '10,11', '10,11', '10,11', '10,11'],
];
const _suhuAfter = [
  ['22,2', '22,2', '22,1', '22,2', '22,2'],
  ['22,2', '22,2', '22,2', '22,2', '22,2'],
  ['22,1', '22,1', '22,1', '22,1', '22,1'],
];

double? _angka(String? s) => double.tryParse((s ?? '').replaceAll(',', '.'));

void _pastikanTanpaPesanGagal(String langkah) {
  for (final pola in ['Gagal memuat', 'Gagal menyimpan', 'Sesi kamu habis']) {
    final f = find.textContaining(pola);
    if (ada(f)) {
      throw TestFailure(
        '[$langkah] pesan galat tampil: '
        '${(f.evaluate().first.widget as Text).data}',
      );
    }
  }
}

Future<void> _masuk(WidgetTester tester, String id) async {
  final isian = find.descendant(
    of: find.byType(LoginScreen),
    matching: find.byType(TextField),
  );
  await tester.enterText(isian.at(0), id);
  await tester.enterText(isian.at(1), e2eSandi);
  FocusManager.instance.primaryFocus?.unfocus();
  await jeda(tester, 300);
  await ketuk(tester, find.text('MASUK'));
  await tunggu(
    tester,
    () =>
        ada(find.byType(MainShell)) ||
        ada(find.byType(OnboardingScreen)) ||
        (ada(find.byType(LoginScreen)) &&
            ada(find.textContaining('salah')) &&
            !ada(find.byType(CircularProgressIndicator))),
    alasan: 'shell/onboarding sesudah masuk',
    batas: const Duration(seconds: 120),
  );
  if (ada(find.byType(OnboardingScreen))) {
    await ketuk(tester, find.text('Lewati'));
    await tunggu(
      tester,
      () => ada(find.byType(MainShell)),
      alasan: 'shell sesudah melewati onboarding',
    );
  }
  if (!ada(find.byType(MainShell))) {
    throw TestFailure('masuk gagal: ${teksTerlihat().join(' | ')}');
  }
}

/// Profil → Keluar → layar login siap (tombol MASUK).
///
/// Di HP, Profil = carousel geser (`PageView`) dan tombol Keluar ada di
/// bagian TERAKHIR ("Sistem"); di layar lebar satu daftar gulir.
Future<void> _keluar(WidgetTester tester) async {
  await ketuk(tester, find.text('Profil').last);
  await jeda(tester, 800);
  final keluar = find.text('Keluar');
  final carousel = find.descendant(
    of: find.byType(ProfileScreen),
    matching: find.byType(PageView),
  );
  for (var i = 0; i < 6 && !ada(keluar.hitTestable()); i++) {
    if (!ada(carousel)) break;
    await tester.drag(carousel.first, const Offset(-380, 0));
    await jeda(tester, 800);
  }
  if (!ada(keluar.hitTestable())) {
    final gulir = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .hitTestable();
    if (ada(gulir)) {
      await tester.scrollUntilVisible(
        keluar,
        250,
        scrollable: gulir.first,
        maxScrolls: 30,
      );
    }
  }
  await ketuk(tester, keluar);
  await tunggu(
    tester,
    () =>
        ada(find.byType(LoginScreen)) &&
        ada(find.text('MASUK')) &&
        !ada(find.byType(MainShell)),
    alasan: 'layar login sesudah keluar',
    batas: const Duration(seconds: 60),
  );
}

Future<void> _tungguLembar(WidgetTester tester) async {
  await tunggu(
    tester,
    () => ada(find.byType(LembarKerjaScreen)),
    alasan: 'layar lembar kerja',
  );
  // Bentuk formulir datang dari server (php -S satu proses: bisa lambat).
  await tunggu(
    tester,
    () =>
        ada(find.text('Pilih alat')) ||
        ada(find.textContaining('Gagal memuat bentuk')),
    alasan: 'bentuk lembar kerja termuat',
    batas: const Duration(seconds: 120),
  );
  await jeda(tester, 1000);
  _pastikanTanpaPesanGagal('lembar kerja');
}

/// Kotak isian tabel "After adjustment Reading" (urut baris 4 → 7 → 10,01,
/// tiap baris 5 Repeat × [pH, °C]) — sesudah tabelnya digulir ke layar.
Future<Finder> _kotakTabelAfter(WidgetTester tester) async {
  final judul = find.text('After adjustment Reading');
  final gulir = find.descendant(
    of: find.byType(LembarKerjaScreen),
    matching: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  await tester.scrollUntilVisible(
    judul,
    250,
    scrollable: gulir.first,
    maxScrolls: 30,
  );
  await jeda(tester, 400);
  return find.descendant(
    of: find.ancestor(of: judul, matching: find.byType(Column)).first,
    matching: find.byType(TextField),
  );
}

Future<void> _isiTabelAfter(WidgetTester tester) async {
  final kotak = await _kotakTabelAfter(tester);
  final jumlah = kotak.evaluate().length;
  if (jumlah < 30) {
    throw TestFailure('tabel After cuma punya $jumlah kotak (harap 30)');
  }
  for (var titik = 0; titik < 3; titik++) {
    for (var r = 0; r < 5; r++) {
      final sel = titik * 10 + r * 2;
      await tester.ensureVisible(kotak.at(sel));
      await tester.enterText(kotak.at(sel), _after[titik][r]);
      await tester.enterText(kotak.at(sel + 1), _suhuAfter[titik][r]);
    }
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await jeda(tester, 800);
  pastikanTanpaGalat(tester, 'isi tabel After');
}

/// Tutup layar yang ditumpuk di atas shell (AppBar ← / tombol kembali).
Future<void> _tutupLayar(WidgetTester tester) async {
  final kembali = find.byIcon(Icons.arrow_back).hitTestable();
  if (ada(kembali)) {
    await ketuk(tester, kembali.first);
  } else {
    await tester.binding.handlePopRoute();
  }
  await jeda(tester, 700);
}

/// Tutup pemilih instrumen & kategori sampai shell (tab bawah) tampil lagi.
Future<void> _kembaliKeShell(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    final masihTertumpuk =
        ada(find.byType(InstrumentPickerScreen)) ||
        ada(find.byType(CategoryPickerScreen)) ||
        ada(find.byType(DrafScreen));
    if (!masihTertumpuk) break;
    await _tutupLayar(tester);
  }
  await tunggu(
    tester,
    () => ada(find.text('Profil').hitTestable()),
    alasan: 'kembali ke shell',
  );
}

/// Buka butir menu samping (drawer) berjudul [judul].
Future<void> _bukaMenu(WidgetTester tester, String judul) async {
  await ketuk(tester, find.byTooltip('Menu utama').first);
  await jeda(tester, 700);
  final butir = find.widgetWithText(ListTile, judul);
  final drawer = find.descendant(
    of: find.byType(Drawer),
    matching: find.byWidgetPredicate((w) => w is Scrollable),
  );
  if (!ada(butir.hitTestable())) {
    await tester.scrollUntilVisible(
      butir,
      200,
      scrollable: drawer.first,
      maxScrolls: 20,
    );
  }
  await ketuk(tester, butir);
  await jeda(tester, 800);
}
