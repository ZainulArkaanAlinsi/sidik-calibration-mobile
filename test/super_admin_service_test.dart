import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/anggota_pelanggan.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/ganti_sandi_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';

/// Service pengelolaan Super Admin lawan kontrak API.
///
/// SUMBER bentuk JSON: `docs/perintah-frontend-super-admin.md` (repo API,
/// branch `feat/super-admin-pengelolaan`) §3.2, §3.3, §4.2-§4.4, dan
/// `docs/perintah-frontend-ganti-sandi-lab.md` §1. Contoh respons di bawah
/// disalin dari dokumen itu, bukan dikarang.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient _klien(Future<http.Response> Function(http.Request) h) =>
    ApiClient(client: MockClient(h), baseUrl: _dasar);

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// §3.2, disalin dari kontrak.
final _kontrakAnggota = <String, dynamic>{
  'data': {
    'customer': {'id': 17, 'nama': 'PT Contoh Makmur'},
    'maks_anggota': 50,
    'jumlah_aktif': 2,
    'pic_admin': {
      'id': 4,
      'nama': 'Rina Master Data',
      'email': 'rina@lab.test',
    },
    'anggota': [
      {
        'id': 41,
        'peran': 'pic_utama',
        'status': 'aktif',
        'bergabung_pada': '2026-11-02T03:10:00+00:00',
        'dinonaktifkan_pada': null,
        'dinonaktifkan_oleh': null,
        'pic_utama_terakhir': true,
        'bisa_dicabut': false,
        'orang': {
          'id': 88,
          'nama': 'Budi Santoso',
          'email': 'budi@contoh.test',
          'telepon': '0812000000',
          'jabatan': 'QC Manager',
        },
      },
      {
        'id': 42,
        'peran': 'staf',
        'status': 'aktif',
        'bergabung_pada': '2026-11-03T07:00:00+00:00',
        'dinonaktifkan_pada': null,
        'dinonaktifkan_oleh': null,
        'pic_utama_terakhir': false,
        'bisa_dicabut': true,
        'orang': {
          'id': 91,
          'nama': 'Sari Dewi',
          'email': 'sari@contoh.test',
          'telepon': null,
          'jabatan': null,
        },
      },
      {
        'id': 40,
        'peran': 'staf',
        'status': 'nonaktif',
        'bergabung_pada': '2026-10-20T01:00:00+00:00',
        'dinonaktifkan_pada': '2026-11-10T09:30:00+00:00',
        'dinonaktifkan_oleh': {'id': 4, 'nama': 'Rina Master Data'},
        'pic_utama_terakhir': false,
        'bisa_dicabut': false,
        'orang': {
          'id': 75,
          'nama': 'Andi Lama',
          'email': 'andi@contoh.test',
          'telepon': null,
          'jabatan': null,
        },
      },
    ],
    'undangan_menunggu': [
      {
        'id': 12,
        'email': 'baru@contoh.test',
        'peran': 'staf',
        'kedaluwarsa_pada': '2026-11-25T08:00:00+00:00',
        'dibuat_pada': '2026-11-18T08:00:00+00:00',
        'diundang_oleh': {'id': 4, 'nama': 'Rina Master Data'},
      },
    ],
  },
};

/// Item `UserResource` (§4.1).
Map<String, dynamic> _akun({
  int id = 21,
  String role = 'teknisi',
  String status = 'aktif',
}) => {
  'id': id,
  'nama': 'Dedi Teknisi',
  'email': 'dedi@lab.test',
  'employee_id': 'SDK-0021',
  'kode_teknisi': 'DT',
  'role': role,
  'status': status,
  'department': null,
  'organization_id': 1,
};

void main() {
  group('Ganti sandi sendiri (POST /me/ganti-sandi)', () {
    GantiSandiService baru(Future<http.Response> Function(http.Request) h) =>
        ApiGantiSandiService(_klien(h));

    test(
      'kirim nama kolom persis kontrak; sukses memuat sesi_dicabut',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'message': 'Sandi berhasil diganti.',
            'data': {'sesi_dicabut': 2},
          });
        });

        final hasil = await s.ganti(
          'tkn-1',
          sandiLama: 'lama-123',
          sandiBaru: 'baru-1234567',
          konfirmasi: 'baru-1234567',
        );

        expect(terkirim.method, 'POST');
        expect(terkirim.url.toString(), '$_dasar/me/ganti-sandi');
        expect(terkirim.headers['Authorization'], 'Bearer tkn-1');
        expect(_badan(terkirim), {
          'sandi_lama': 'lama-123',
          'sandi': 'baru-1234567',
          'sandi_confirmation': 'baru-1234567',
        });
        expect(hasil.sesiDicabut, 2);
      },
    );

    test('data tanpa sesi_dicabut dibaca 0, bukan galat', () async {
      final s = baru((_) async => _json({'message': 'ok'}));
      final hasil = await s.ganti(
        't',
        sandiLama: 'a',
        sandiBaru: 'b',
        konfirmasi: 'b',
      );
      expect(hasil.sesiDicabut, 0);
    });

    // Badan galat disalin dari kontrak §1 "Gagal".
    final galat = <(String, int, Map<String, dynamic>)>[
      (
        '422 sandi_lama_salah',
        422,
        {'kode': 'sandi_lama_salah', 'message': 'Sandi lama tidak cocok.'},
      ),
      (
        '422 sandi baru pendek',
        422,
        {
          'message': 'Sandi baru minimal 10 karakter.',
          'errors': {
            'sandi': ['Sandi baru minimal 10 karakter.'],
          },
        },
      ),
      (
        '429 throttle',
        429,
        {'message': 'Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.'},
      ),
      (
        '403 bukan aplikasi ini',
        403,
        {'kode': 'bukan_aplikasi_ini', 'message': 'Bukan aplikasi ini.'},
      ),
      ('401 tanpa token', 401, {'message': 'Unauthenticated.'}),
    ];

    for (final (nama, status, badan) in galat) {
      test('galat $nama dilempar sebagai ApiException berbadan asli', () async {
        final s = baru((_) async => _json(badan, status));
        await expectLater(
          s.ganti('t', sandiLama: 'a', sandiBaru: 'b', konfirmasi: 'b'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['kode'], 'kode', badan['kode']),
          ),
        );
      });
    }

    test('jaringan putus → KoneksiException (tidak diulang otomatis)', () async {
      var panggilan = 0;
      final s = baru((_) async {
        panggilan++;
        throw const SocketException('putus');
      });
      await expectLater(
        s.ganti('t', sandiLama: 'a', sandiBaru: 'b', konfirmasi: 'b'),
        throwsA(isA<KoneksiException>()),
      );
      // POST tanpa client_request_id tidak diulang: sandi tidak terkirim dua kali.
      expect(panggilan, 1);
    });
  });

  group('Pengguna lab (GET/POST /users…)', () {
    PenggunaSaService baru(Future<http.Response> Function(http.Request) h) =>
        ApiPenggunaSaService(_klien(h));

    test('daftar: query role/status/search/page dan meta paginasi', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'data': [_akun(), _akun(id: 22, role: 'admin')],
          'links': {},
          'meta': {'current_page': 2, 'last_page': 3, 'per_page': 15},
        });
      });

      final hal = await s.daftar(
        'tkn',
        peran: 'admin',
        status: 'aktif',
        cari: ' dedi ',
        halaman: 2,
      );

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/users');
      expect(terkirim.url.queryParameters, {
        'role': 'admin',
        'status': 'aktif',
        'search': 'dedi',
        'page': '2',
      });
      expect(hal.items.map((u) => u.id), [21, 22]);
      expect(hal.items.last.role, UserRole.admin);
      expect(hal.halaman, 2);
      expect(hal.halamanTerakhir, 3);
      expect(hal.adaLagi, isTrue);
    });

    test(
      'daftar tanpa filter: tanpa query; tanpa meta = satu halaman',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'data': [_akun()],
          });
        });

        final hal = await s.daftar('tkn');

        expect(terkirim.url.toString(), '$_dasar/users');
        expect(hal.items, hasLength(1));
        expect(hal.adaLagi, isFalse);
      },
    );

    test(
      'daftar: 422 errors.role (peran tak dikenal) dilempar apa adanya',
      () async {
        final s = baru(
          (_) async => _json({
            'message': 'The selected role is invalid.',
            'errors': {
              'role': ['Peran tidak dikenal.'],
            },
          }, 422),
        );
        await expectLater(
          s.daftar('t', peran: 'super_admin'),
          throwsA(
            isA<ApiException>().having(
              (e) => (e.body['errors'] as Map)['role'],
              'errors.role',
              ['Peran tidak dikenal.'],
            ),
          ),
        );
      },
    );

    test('daftar: baris cacat TIDAK dilewati diam-diam', () async {
      final s = baru(
        (_) async => _json({
          'data': [
            _akun(),
            {'id': 99, 'nama': 'Tanpa email dan role'},
          ],
        }),
      );
      await expectLater(s.daftar('t'), throwsA(isA<TypeError>()));
    });

    test(
      'buatAdmin: body persis kontrak §4.3, tanpa organization_id',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'message': 'Akun admin dibuat.',
            'data': _akun(id: 57, role: 'admin'),
          }, 201);
        });

        final akun = await s.buatAdmin(
          'tkn',
          nama: 'Rina Master Data',
          employeeId: 'SDK-0200',
          email: 'rina@lab.test',
          password: 'sandiawal-min-8',
          department: 'Master Data',
        );

        expect(terkirim.method, 'POST');
        expect(terkirim.url.path, '/api/users');
        expect(_badan(terkirim), {
          'role': 'admin',
          'nama': 'Rina Master Data',
          'email': 'rina@lab.test',
          'employee_id': 'SDK-0200',
          'password': 'sandiawal-min-8',
          'department': 'Master Data',
        });
        expect(_badan(terkirim).containsKey('organization_id'), isFalse);
        expect(akun.id, 57);
        expect(akun.role, UserRole.admin);
      },
    );

    test('buatAdmin: departemen kosong tidak ikut dikirim', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({'data': _akun(role: 'admin')}, 201);
      });
      await s.buatAdmin(
        't',
        nama: 'A',
        employeeId: 'X',
        email: 'a@b.cd',
        password: '12345678',
      );
      expect(_badan(terkirim).containsKey('department'), isFalse);
    });

    final galatBuat = <(String, int, Map<String, dynamic>)>[
      ('403 Master Data', 403, {'message': 'Kamu nggak punya akses ke sini.'}),
      (
        '422 email kembar',
        422,
        {
          'message': 'Email ini sudah terdaftar.',
          'errors': {
            'email': ['Email ini sudah terdaftar.'],
          },
        },
      ),
      (
        '422 ID pegawai kembar',
        422,
        {
          'message': 'ID pegawai ini sudah terdaftar.',
          'errors': {
            'employee_id': ['ID pegawai ini sudah terdaftar.'],
          },
        },
      ),
      ('429 throttle', 429, {'message': 'Kebanyakan percobaan.'}),
    ];
    for (final (nama, status, badan) in galatBuat) {
      test('buatAdmin galat $nama', () async {
        final s = baru((_) async => _json(badan, status));
        await expectLater(
          s.buatAdmin(
            't',
            nama: 'A',
            employeeId: 'X',
            email: 'a@b.cd',
            password: '12345678',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['errors'], 'errors', badan['errors']),
          ),
        );
      });
    }

    test(
      'buatAdmin: jaringan putus → KoneksiException, tidak diulang',
      () async {
        var panggilan = 0;
        final s = baru((_) async {
          panggilan++;
          throw const SocketException('putus');
        });
        await expectLater(
          s.buatAdmin(
            't',
            nama: 'A',
            employeeId: 'X',
            email: 'a@b.cd',
            password: '12345678',
          ),
          throwsA(isA<KoneksiException>()),
        );
        expect(panggilan, 1, reason: 'dua akun kembar bila diulang');
      },
    );

    test('nonaktifkan: POST /users/{id}/nonaktifkan dengan alasan', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'message': 'Akun dinonaktifkan. Seluruh sesinya dicabut.',
          'data': _akun(status: 'nonaktif'),
        });
      });

      final akun = await s.nonaktifkan(
        'tkn',
        21,
        alasan: 'Resign per 15 Nov 2026',
      );

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/users/21/nonaktifkan');
      expect(_badan(terkirim), {'alasan': 'Resign per 15 Nov 2026'});
      expect(akun.status, UserStatus.nonaktif);
    });

    final galatStatus = <(String, int, Map<String, dynamic>, String?)>[
      (
        'sudah_nonaktif',
        422,
        {'kode': 'sudah_nonaktif', 'message': 'Sudah nonaktif.'},
        'sudah_nonaktif',
      ),
      (
        'alasan terlalu pendek',
        422,
        {
          'message': 'Alasan minimal 3 karakter.',
          'errors': {
            'alasan': ['Alasan minimal 3 karakter.'],
          },
        },
        null,
      ),
      (
        '404 akun lain/super admin',
        404,
        {'message': 'Data nggak ketemu.'},
        null,
      ),
      (
        '403 Master Data',
        403,
        {'message': 'Kamu nggak punya akses ke sini.'},
        null,
      ),
    ];
    for (final (nama, status, badan, kode) in galatStatus) {
      test('nonaktifkan galat $nama', () async {
        final s = baru((_) async => _json(badan, status));
        await expectLater(
          s.nonaktifkan('t', 21, alasan: 'xx'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['kode'], 'kode', kode),
          ),
        );
      });
    }

    test('aktifkan: alasan opsional — tanpa alasan, body kosong', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({'message': 'Akun diaktifkan kembali.', 'data': _akun()});
      });

      final akun = await s.aktifkan('tkn', 21);

      expect(terkirim.url.path, '/api/users/21/aktifkan');
      expect(_badan(terkirim), isEmpty);
      expect(akun.status, UserStatus.aktif);

      await s.aktifkan('tkn', 21, alasan: 'Kembali bertugas');
      expect(_badan(terkirim), {'alasan': 'Kembali bertugas'});
    });

    for (final kode in ['sudah_aktif', 'perlu_persetujuan']) {
      test('aktifkan galat $kode', () async {
        final s = baru((_) async => _json({'kode': kode, 'message': 'x'}, 422));
        await expectLater(
          s.aktifkan('t', 21),
          throwsA(
            isA<ApiException>().having((e) => e.body['kode'], 'kode', kode),
          ),
        );
      });
    }

    test(
      'ubah: hanya kolom yang diisi yang dikirim (PUT /users/{id})',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({'data': _akun()});
        });

        await s.ubah('t', 21, nama: 'Baru', department: '');

        expect(terkirim.method, 'PUT');
        expect(terkirim.url.path, '/api/users/21');
        // department '' ikut terkirim (cara mengosongkan); kolom null tidak.
        expect(_badan(terkirim), {'nama': 'Baru', 'department': ''});
      },
    );

    test('setelUlangSandi: body {password}', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({'message': 'ok'});
      });

      await s.setelUlangSandi('t', 21, 'sandi-baru-1');

      expect(terkirim.url.path, '/api/users/21/reset-password');
      expect(_badan(terkirim), {'password': 'sandi-baru-1'});
    });

    test('setujui & tolak: path dan body role.api', () async {
      final dikirim = <http.Request>[];
      final s = baru((r) async {
        dikirim.add(r);
        return _json({'data': _akun()});
      });

      await s.setujui('t', 22, UserRole.admin);
      await s.tolak('t', 22);

      expect(dikirim[0].url.path, '/api/users/22/approve');
      expect(_badan(dikirim[0]), {'role': 'admin'});
      expect(dikirim[1].url.path, '/api/users/22/reject');
    });
  });

  group('Anggota pelanggan (sisi lab)', () {
    AnggotaPelangganService baru(
      Future<http.Response> Function(http.Request) h,
    ) => ApiAnggotaPelangganService(_klien(h));

    test('ambil: parse bentuk kontrak §3.2 sampai ke flag server', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json(_kontrakAnggota);
      });

      final d = await s.ambil('tkn', 17);

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/customers/17/anggota');
      expect(d.customerId, 17);
      expect(d.customerNama, 'PT Contoh Makmur');
      expect(d.maksAnggota, 50);
      expect(d.jumlahAktif, 2);
      expect(d.picAdmin?.nama, 'Rina Master Data');
      expect(d.picAdmin?.email, 'rina@lab.test');

      expect(d.anggota.map((a) => a.id), [41, 42, 40]);
      final pic = d.anggota[0];
      expect(pic.peran, PeranAnggota.picUtama);
      expect(pic.aktif, isTrue);
      expect(pic.picUtamaTerakhir, isTrue);
      expect(pic.bisaDicabut, isFalse);
      expect(pic.orang?.jabatan, 'QC Manager');
      expect(pic.bergabungPada, isNotNull);

      final staf = d.anggota[1];
      expect(staf.peran, PeranAnggota.staf);
      expect(staf.bisaDicabut, isTrue);
      expect(staf.orang?.telepon, isNull);

      final lama = d.anggota[2];
      expect(lama.aktif, isFalse);
      expect(lama.dinonaktifkanOleh?.nama, 'Rina Master Data');
      expect(lama.dinonaktifkanPada, isNotNull);

      expect(d.undanganMenunggu, hasLength(1));
      final u = d.undanganMenunggu.single;
      expect(u.id, 12);
      expect(u.email, 'baru@contoh.test');
      expect(u.diundangOleh?.nama, 'Rina Master Data');
      expect(u.kedaluwarsaPada, isNotNull);
    });

    test('ambil: pic_admin, orang, dinonaktifkan_oleh boleh null', () async {
      final json = jsonDecode(jsonEncode(_kontrakAnggota)) as Map;
      final data = json['data'] as Map;
      data['pic_admin'] = null;
      (data['anggota'] as List)[2]['orang'] = null;
      (data['anggota'] as List)[2]['dinonaktifkan_oleh'] = null;
      final s = baru((_) async => _json(json));

      final d = await s.ambil('t', 17);

      expect(d.picAdmin, isNull);
      expect(d.anggota[2].orang, isNull);
      expect(d.anggota[2].dinonaktifkanOleh, isNull);
    });

    test('ambil: 404 (milik lab lain) dilempar sebagai ApiException', () async {
      final s = baru(
        (_) async => _json({'message': 'Data nggak ketemu.'}, 404),
      );
      await expectLater(
        s.ambil('t', 999),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('ambil: 403 untuk peran tanpa izin', () async {
      final s = baru(
        (_) async => _json({'message': 'Kamu nggak punya akses ke sini.'}, 403),
      );
      await expectLater(
        s.ambil('t', 17),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });

    test(
      'cabut: POST .../anggota/{id}/nonaktifkan dengan alasan apa adanya',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'message': 'Anggota dinonaktifkan. Seluruh sesinya dicabut.',
            'data': {
              'id': 42,
              'peran': 'staf',
              'status': 'nonaktif',
              'bergabung_pada': '2026-11-03T07:00:00+00:00',
              'dinonaktifkan_pada': '2026-11-18T10:15:00+00:00',
              'dinonaktifkan_oleh': {'id': 4, 'nama': 'Rina Master Data'},
              'pic_utama_terakhir': false,
              'bisa_dicabut': false,
              'orang': {
                'id': 91,
                'nama': 'Sari Dewi',
                'email': 'sari@contoh.test',
                'telepon': null,
                'jabatan': null,
              },
            },
          });
        });

        final a = await s.cabut(
          'tkn',
          17,
          42,
          alasan: 'Karyawan sudah pindah perusahaan.',
        );

        expect(terkirim.method, 'POST');
        expect(terkirim.url.path, '/api/customers/17/anggota/42/nonaktifkan');
        expect(_badan(terkirim), {
          'alasan': 'Karyawan sudah pindah perusahaan.',
        });
        expect(a.aktif, isFalse);
        expect(a.bisaDicabut, isFalse);
      },
    );

    final galatCabut = <(String, int, Map<String, dynamic>)>[
      (
        'pic_utama_terakhir',
        422,
        {'kode': 'pic_utama_terakhir', 'message': 'Satu-satunya PIC utama.'},
      ),
      (
        'sudah_nonaktif',
        422,
        {'kode': 'sudah_nonaktif', 'message': 'Sudah nonaktif.'},
      ),
      (
        'alasan kosong',
        422,
        {
          'message': 'Alasan wajib.',
          'errors': {
            'alasan': ['Alasan wajib.'],
          },
        },
      ),
      ('404', 404, {'message': 'Data nggak ketemu.'}),
      ('403', 403, {'message': 'Kamu nggak punya akses ke sini.'}),
      ('429', 429, {'message': 'Kebanyakan percobaan.'}),
    ];
    for (final (nama, status, badan) in galatCabut) {
      test('cabut galat $nama', () async {
        final s = baru((_) async => _json(badan, status));
        await expectLater(
          s.cabut('t', 17, 42, alasan: 'abc'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['kode'], 'kode', badan['kode']),
          ),
        );
      });
    }

    test('cabut: jaringan putus → KoneksiException, tidak diulang', () async {
      var panggilan = 0;
      final s = baru((_) async {
        panggilan++;
        throw const SocketException('putus');
      });
      await expectLater(
        s.cabut('t', 17, 42, alasan: 'abc'),
        throwsA(isA<KoneksiException>()),
      );
      expect(panggilan, 1);
    });

    test('batalkanUndangan: DELETE /customers/{c}/undangan/{u}', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({'message': 'Undangan dibatalkan.'});
      });

      await s.batalkanUndangan('tkn', 17, 12);

      expect(terkirim.method, 'DELETE');
      expect(terkirim.url.path, '/api/customers/17/undangan/12');
    });

    test('batalkanUndangan: undangan perusahaan lain → 404', () async {
      final s = baru(
        (_) async => _json({'message': 'Data nggak ketemu.'}, 404),
      );
      await expectLater(
        s.batalkanUndangan('t', 17, 999),
        throwsA(isA<ApiException>().having((e) => e.status, 's', 404)),
      );
    });

    test('setPicAdmin: user_id selalu terkirim, null = lepas PIC', () async {
      final dikirim = <http.Request>[];
      final s = baru((r) async {
        dikirim.add(r);
        return _json({
          'message': 'PIC admin diperbarui.',
          'data': {'customer_id': 17, 'pic_admin_id': 4},
        });
      });

      await s.setPicAdmin('t', 17, 4);
      await s.setPicAdmin('t', 17, null);

      expect(dikirim[0].method, 'PATCH');
      expect(dikirim[0].url.path, '/api/customers/17/pic-admin');
      expect(_badan(dikirim[0]), {'user_id': 4});
      // `present` di server: kuncinya HARUS ada walau nilainya null.
      expect(_badan(dikirim[1]), {'user_id': null});
    });

    test('setPicAdmin: 422 errors.user_id (bukan admin aktif)', () async {
      final s = baru(
        (_) async => _json({
          'message': 'PIC admin harus admin lab yang masih aktif.',
          'errors': {
            'user_id': ['PIC admin harus admin lab yang masih aktif.'],
          },
        }, 422),
      );
      await expectLater(
        s.setPicAdmin('t', 17, 99),
        throwsA(
          isA<ApiException>().having(
            (e) => (e.body['errors'] as Map)['user_id'],
            'errors.user_id',
            isNotEmpty,
          ),
        ),
      );
    });

    test('daftarPelanggan: search + page; meta paginasi', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'data': [
            {
              'id': 17,
              'nama': 'PT Contoh Makmur',
              'alamat': null,
              'contact_person': null,
              'telepon': null,
              'email': null,
              'jumlah_alat': 3,
            },
          ],
          'meta': {'current_page': 1, 'last_page': 2},
        });
      });

      final hal = await s.daftarPelanggan('t', cari: 'contoh');

      expect(terkirim.url.path, '/api/customers');
      expect(terkirim.url.queryParameters, {'search': 'contoh'});
      expect(hal.items.single.nama, 'PT Contoh Makmur');
      // alamat/kontak null di server → string kosong, bukan crash.
      expect(hal.items.single.contactPerson, '');
      expect(hal.adaLagi, isTrue);
    });
  });
}
