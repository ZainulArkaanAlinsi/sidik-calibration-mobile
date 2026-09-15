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
      expect(dijalankan.single, endsWith('pasang.ps1'));

      final skrip = await File(dijalankan.single).readAsString();
      expect(skrip, contains('Get-Process -Id 4242'),
          reason: 'menunggu proses ini mati sebelum menimpa DLL');
      expect(skrip, contains(exe.parent.path));
      expect(skrip, contains('sidik-windows-1.0.600.zip'));
    });

    test('skrip yang pernah dijalankan tapi aplikasinya masih versi lama: '
        'TIDAK dijalankan lagi, versinya dicatat gagal', () async {
      // 15 Sep 2026: skrip macet dan tiap pembukaan aplikasi menyalakannya
      // lagi — jendela konsol menumpuk. Pembukaan KEDUA harus berhenti.
      await pembaru(client: server()).siapkan();

      final pertama = <String>[];
      expect(
        await pembaru(client: server(), skripDijalankan: pertama)
            .terapkanKalauSiap(),
        isTrue,
      );

      // Aplikasi dibuka lagi, masih 1.0.566 — skrip tadi tidak sampai selesai.
      final kedua = <String>[];
      expect(
        await pembaru(client: server(), skripDijalankan: kedua)
            .terapkanKalauSiap(),
        isFalse,
      );

      expect(kedua, isEmpty);
      expect(await berkas('siap.json').exists(), isFalse);
      expect(await berkas('gagal.txt').readAsString(), contains('1.0.600'));

      // Dan versi itu tidak diunduh-pasang ulang.
      expect(await pembaru(client: server()).siapkan(), isFalse);
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

  group('isi pasang.ps1', () {
    final skrip = PembaruWindows.susunSkrip(
      pid: 77,
      zip: r'C:\data\pembaruan\sidik-windows-1.0.600.zip',
      folderKerja: r'C:\data\pembaruan',
      folderInstalasi: r"C:\Lab O'Neil\SIDIK",
      exe: r"C:\Lab O'Neil\SIDIK\sidik_calibration.exe",
      versi: '1.0.600',
    );

    test('ekstrak ke folder sementara SEBELUM menyalin ke instalasi', () {
      final ekstrak = skrip.indexOf('Expand-Archive');
      final salin = skrip.indexOf('Copy-Item');

      expect(ekstrak, greaterThan(0));
      expect(salin, greaterThan(ekstrak),
          reason: 'zip rusak harus berhenti sebelum folder instalasi tersentuh');
      expect(skrip, contains('isi zip tidak lengkap'));
    });

    test('tidak memanggil program konsol apa pun — penyebab jendela & macet',
        () {
      for (final dilarang in ['find.exe', 'tasklist', 'tar.exe', 'Robocopy', 'cmd.exe', 'PING']) {
        expect(skrip, isNot(contains(dilarang)), reason: dilarang);
      }
    });

    test('penungguan proses punya batas waktu, tidak menunggu selamanya', () {
      expect(skrip, contains('WaitForExit(120000)'));
    });

    test('jalur gagal mencabut penanda dan mencatat versinya', () {
      final gagal = skrip.substring(skrip.indexOf('} catch {'));

      expect(gagal, contains(r"Remove-Item -LiteralPath 'C:\data\pembaruan\siap.json'"));
      expect(gagal, contains(r"Add-Content -LiteralPath 'C:\data\pembaruan\gagal.txt' -Value '1.0.600'"));
      expect(gagal, contains('Start-Process'),
          reason: 'gagal pun aplikasinya tetap dinyalakan lagi');
    });

    test('kutip tunggal di jalur digandakan — tidak memutus literal', () {
      expect(skrip, contains(r"'C:\Lab O''Neil\SIDIK\sidik_calibration.exe'"));
    });
  });

  group('dijalankan SUNGGUHAN, persis cara aplikasi', () {
    // Versi batch lolos semua test di atas DAN lolos uji manual lewat
    // PowerShell, lalu macet di laptop nyata karena aplikasi menjalankannya
    // dengan `Process.start(detached)`. Test ini memakai jalur yang sama.
    test('menunggu proses mati, menimpa instalasi, membersihkan penanda',
        () async {
      final paket = await Directory('${akar.path}\\paket\\data').create(recursive: true);
      await File('${paket.parent.path}\\sidik_calibration.exe').writeAsString('BARU');
      await File('${paket.parent.path}\\data.txt').writeAsString('BARU');
      await File('${paket.path}\\aset.txt').writeAsString('aset-baru');
      await File('${exe.parent.path}\\data.txt').writeAsString('LAMA');
      await kerja.create(recursive: true);

      final zip = '${kerja.path}\\sidik-windows-1.0.600.zip';
      final kompres = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        "Compress-Archive -Path '${paket.parent.path}\\*' -DestinationPath '$zip'",
      ]);
      expect(kompres.exitCode, 0, reason: '${kompres.stderr}');
      await File('${kerja.path}\\siap.json').writeAsString('{}');

      // "Aplikasi" yang masih hidup ~3 detik.
      final aplikasi = await Process.start(
        'powershell.exe',
        ['-NoProfile', '-Command', 'Start-Sleep -Seconds 3'],
      );

      final skrip = File('${kerja.path}\\pasang.ps1');
      await skrip.writeAsString(
        PembaruWindows.susunSkrip(
          pid: aplikasi.pid,
          zip: zip,
          folderKerja: kerja.path,
          folderInstalasi: exe.parent.path,
          // Exe yang dinyalakan lagi di akhir sengaja TIDAK ADA, supaya test
          // tidak membuka program apa pun. Start-Process-nya gagal sesudah
          // penyalinan selesai, dan itu tidak boleh membatalkan hasil salin.
          exe: '${akar.path}\\tidak-ada\\tidak-ada.exe',
          versi: '1.0.600',
        ).replaceAll(
          // Pengecekan kelengkapan zip tetap mencari exe yang ada di paket.
          "'tidak-ada.exe'",
          "'sidik_calibration.exe'",
        ),
      );

      final mulai = DateTime.now();
      await PembaruWindows.jalankanTerlepasUntukTest(skrip.path);

      // Tunggu hasilnya: penanda hilang = skrip sampai ke ujung.
      final penanda = File('${kerja.path}\\siap.json');
      for (var i = 0; i < 60 && await penanda.exists(); i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      expect(await penanda.exists(), isFalse, reason: 'skrip tidak selesai dalam 60 s');
      expect(await aplikasi.exitCode, 0);
      expect(DateTime.now().difference(mulai).inSeconds, greaterThanOrEqualTo(2),
          reason: 'harus menunggu "aplikasi" mati dulu');
      expect(await File('${exe.parent.path}\\data.txt').readAsString(), 'BARU');
      expect(await File('${exe.parent.path}\\data\\aset.txt').readAsString(), 'aset-baru');
      expect(await File(zip).exists(), isFalse);
    }, skip: !Platform.isWindows, timeout: const Timeout(Duration(minutes: 2)));
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
