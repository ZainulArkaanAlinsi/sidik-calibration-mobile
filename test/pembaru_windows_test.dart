import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/pembaru_windows.dart';
import 'package:sidik_calibration/services/versi_service.dart';

/// Aplikasi Windows yang sudah terpasang harus menyusul rilis sendiri.
///
/// Sebelum ini jalur pembaruan cuma kenal APK, jadi laptop lab tertahan di
/// versi yang pertama kali diekstrak. Yang dijaga di sini bukan cuma "bisa
/// mengunduh", tapi juga tiga hal yang kalau salah merusak instalasi atau
/// memutar aplikasi tanpa ujung: zip terpotong tidak dipasang, versi yang
/// pernah gagal tidak dicoba lagi, dan pembaruan yang sudah masuk dibersihkan.
void main() {
  late Directory akar;
  late Directory kerja;
  late File exe;

  const zipIsi = 'PK-isi-zip-palsu-yang-ukurannya-tetap';

  setUp(() async {
    akar = await Directory.systemTemp.createTemp('pembaru_windows_test');
    kerja = Directory('${akar.path}${Platform.pathSeparator}pembaruan');
    final instalasi = await Directory(
      '${akar.path}${Platform.pathSeparator}instalasi',
    ).create();
    exe = await File(
      '${instalasi.path}${Platform.pathSeparator}sidik_calibration.exe',
    ).writeAsString('exe');
  });

  tearDown(() async {
    if (await akar.exists()) await akar.delete(recursive: true);
  });

  http.Client server({
    String versi = '1.0.600',
    int? ukuran,
    List<String>? catatan,
  }) {
    return MockClient((req) async {
      catatan?.add(req.url.path);

      if (req.url.path.endsWith('versi-windows.json')) {
        return http.Response(
          jsonEncode({
            'versi': versi,
            'build': 600,
            'ukuran': ukuran ?? utf8.encode(zipIsi).length,
            'url_unduh': 'sidik-windows.zip',
          }),
          200,
        );
      }

      if (req.url.path.endsWith('sidik-windows.zip')) {
        return http.Response(zipIsi, 200);
      }

      return http.Response('', 404);
    });
  }

  PembaruWindows pembaru({
    required http.Client client,
    String terpasang = '1.0.566',
    List<String>? skripDijalankan,
  }) {
    return PembaruWindows(
      urlManifest: 'https://contoh.web.app/versi-windows.json',
      folderKerja: kerja,
      fileExe: exe,
      versiTerpasang: () async => terpasang,
      client: client,
      pid: 4242,
      jalankanSkrip: (skrip) async => skripDijalankan?.add(skrip),
    );
  }

  File berkas(String nama) =>
      File('${kerja.path}${Platform.pathSeparator}$nama');

  group('langkah 1 — siapkan di latar', () {
    test('rilis lebih baru: zip diunduh dari URL relatif manifest, penanda '
        'ditulis', () async {
      final jalur = <String>[];
      final siap = await pembaru(client: server(catatan: jalur)).siapkan();

      expect(siap, isTrue);
      expect(jalur, ['/versi-windows.json', '/sidik-windows.zip']);
      expect(await berkas('sidik-windows-1.0.600.zip').readAsString(), zipIsi);

      final penanda = jsonDecode(await berkas('siap.json').readAsString());
      expect(penanda['versi'], '1.0.600');
    });

    test('sudah versi terbaru: tidak mengunduh apa-apa', () async {
      final jalur = <String>[];
      final siap = await pembaru(
        client: server(versi: '1.0.566', catatan: jalur),
      ).siapkan();

      expect(siap, isFalse);
      expect(jalur, ['/versi-windows.json']);
      expect(await berkas('siap.json').exists(), isFalse);
    });

    test('perbandingan ANGKA per ruas: 1.0.1000 lebih baru dari 1.0.999',
        () async {
      final siap = await pembaru(
        client: server(versi: '1.0.1000'),
        terpasang: '1.0.999',
      ).siapkan();

      expect(siap, isTrue);
    });

    test('unduhan terpotong (ukuran beda dari manifest) TIDAK ditandai siap',
        () async {
      final siap = await pembaru(client: server(ukuran: 999999)).siapkan();

      expect(siap, isFalse);
      expect(await berkas('siap.json').exists(), isFalse);
      expect(await berkas('sidik-windows-1.0.600.zip').exists(), isFalse);
      expect(await berkas('sidik-windows-1.0.600.zip.part').exists(), isFalse);
    });

    test('versi yang pernah gagal dipasang dilewati — tidak berputar',
        () async {
      await kerja.create(recursive: true);
      await berkas('gagal.txt').writeAsString('1.0.600\r\n');

      final jalur = <String>[];
      final siap = await pembaru(client: server(catatan: jalur)).siapkan();

      expect(siap, isFalse);
      expect(jalur, isNot(contains('/sidik-windows.zip')));
    });

    test('manifest tidak terjangkau: diam, tidak melempar', () async {
      final mati = MockClient((_) async => throw const SocketException('x'));

      expect(await pembaru(client: mati).siapkan(), isFalse);
    });
  });

  group('langkah 2 — terapkan waktu dibuka', () {
    test('penanda + zip ada dan lebih baru: skrip ditulis lalu dijalankan',
        () async {
      await pembaru(client: server()).siapkan();

      final dijalankan = <String>[];
      final diterapkan = await pembaru(
        client: server(),
        skripDijalankan: dijalankan,
      ).terapkanKalauSiap();

      expect(diterapkan, isTrue);
      expect(dijalankan.single, endsWith('pasang.cmd'));

      final skrip = await File(dijalankan.single).readAsString();
      expect(skrip, contains('PID eq 4242'),
          reason: 'menunggu proses ini mati sebelum menimpa DLL');
      expect(skrip, contains(exe.parent.path));
      expect(skrip, contains('sidik-windows-1.0.600.zip'));
    });

    test('tanpa penanda: tidak menjalankan apa pun', () async {
      final dijalankan = <String>[];
      final diterapkan = await pembaru(
        client: server(),
        skripDijalankan: dijalankan,
      ).terapkanKalauSiap();

      expect(diterapkan, isFalse);
      expect(dijalankan, isEmpty);
    });

    test('pembukaan pertama SESUDAH pembaruan berhasil: penanda sisa '
        'dibersihkan, tidak memasang ulang', () async {
      await pembaru(client: server()).siapkan();

      final dijalankan = <String>[];
      final diterapkan = await pembaru(
        client: server(),
        terpasang: '1.0.600',
        skripDijalankan: dijalankan,
      ).terapkanKalauSiap();

      expect(diterapkan, isFalse);
      expect(dijalankan, isEmpty);
      expect(await berkas('siap.json').exists(), isFalse);
      expect(await berkas('sidik-windows-1.0.600.zip').exists(), isFalse);
    });
  });

  group('isi pasang.cmd', () {
    final skrip = PembaruWindows.susunSkrip(
      pid: 77,
      zip: r'C:\data\pembaruan\sidik-windows-1.0.600.zip',
      folderKerja: r'C:\data\pembaruan',
      folderInstalasi: r'C:\SIDIK',
      exe: r'C:\SIDIK\sidik_calibration.exe',
      versi: '1.0.600',
    );

    test('ekstrak ke folder sementara SEBELUM menyalin ke instalasi', () {
      final ekstrak = skrip.indexOf('tar.exe');
      final salin = skrip.indexOf('Robocopy.exe');

      expect(ekstrak, greaterThan(0));
      expect(salin, greaterThan(ekstrak),
          reason: 'zip rusak harus berhenti sebelum folder instalasi tersentuh');
      expect(
        skrip,
        contains(
          r'if not exist "C:\data\pembaruan\ekstrak\sidik_calibration.exe" goto gagal',
        ),
      );
    });

    test('jalur gagal mencabut penanda dan mencatat versinya', () {
      final gagal = skrip.substring(skrip.indexOf(':gagal'));

      expect(gagal, contains(r'del /q "C:\data\pembaruan\siap.json"'));
      expect(gagal, contains(r'>>"C:\data\pembaruan\gagal.txt" echo 1.0.600'));
      expect(gagal, contains(r'start "" "C:\SIDIK\sidik_calibration.exe"'),
          reason: 'gagal pun aplikasinya tetap dinyalakan lagi');
    });

    test('baris CRLF — cmd.exe salah membaca label goto di berkas LF-saja', () {
      expect(skrip, contains('\r\n'));
      expect(skrip.replaceAll('\r\n', ''), isNot(contains('\n')));
    });
  });

  group('jalur APK tidak berlaku di desktop', () {
    test('updateTersediaProvider null waktu jalurApkProvider false, walau '
        'rilis APK lebih baru dan WAJIB', () async {
      final c = ProviderContainer(
        overrides: [
          jalurApkProvider.overrideWithValue(false),
          versiServiceProvider.overrideWithValue(
            MockVersiService(
              terpasang: '1.0.536',
              terbaru: const VersiAplikasi(
                versi: '1.0.566',
                urlUnduh: 'https://contoh/sidik.apk',
                wajib: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(await c.read(updateTersediaProvider.future), isNull);
      expect(c.read(kirimTertahanRilisWajibProvider), isFalse,
          reason: 'laptop yang tertinggal dari APK tidak boleh tertahan kirim');
    });
  });
}
