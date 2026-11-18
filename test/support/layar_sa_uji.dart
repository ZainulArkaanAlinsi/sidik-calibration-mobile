// Katalog keadaan layar pengelolaan Super Admin buat uji responsif dan
// harness PNG: tiap entri = satu layar dalam satu keadaan (memuat, daftar,
// kosong, galat, dialog konfirmasi) beserta data tiruannya.
//
// Data sengaja memuat kasus buruk: nama/email/perusahaan SANGAT panjang,
// departemen/telepon/jabatan kosong, PIC admin kosong, nama anggota kosong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/alat_pelanggan.dart';
import 'package:sidik_calibration/models/anggota_pelanggan.dart';
import 'package:sidik_calibration/models/customer.dart';
import 'package:sidik_calibration/models/pindah_alat.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/screens/super_admin/ganti_sandi_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_detail_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_sa_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengelolaan_super_admin_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_form_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pindahkan_alat_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pratinjau_pindah_alat_screen.dart';
import 'package:sidik_calibration/screens/super_admin/riwayat_sertifikat_alat_screen.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/riwayat_alat_service.dart';

import 'super_admin_uji.dart';

class KeadaanSa {
  const KeadaanSa(
    this.nama,
    this.layar,
    this.lapisan, {
    this.sesudah,
    this.menahan = false,
    this.tinggiBesar = true,
  });

  final String nama;
  final Widget Function() layar;
  final LapisanUjiSa Function() lapisan;

  /// Interaksi sesudah layar tampil (buka dialog, kirim formulir kosong).
  final Future<void> Function(WidgetTester tester)? sesudah;

  /// Interaksi [sesudah] dijalankan di permukaan SANGAT tinggi, lalu layar
  /// dikembalikan ke ukuran uji: di layar 320 dp daftar malas tidak membangun
  /// tombol yang jauh di bawah, dan menggulir ke sana di tes rapuh. Hasil
  /// akhirnya (dialog terbuka, galat tampil) tetap DIRENDER di ukuran uji.
  /// `false` untuk keadaan yang justru menguji posisi gulir.
  final bool tinggiBesar;

  /// Keadaan "memuat": layanan menunda jawaban; tes menunggu sesudahnya
  /// supaya tidak ada pewaktu yang menggantung.
  final bool menahan;
}

const _jedaMemuat = Duration(seconds: 5);

/// Pengguna buruk: nama/email super panjang, tanpa departemen, tanpa ID.
final penggunaBurukSa = <User>[
  const User(
    id: 31,
    nama: namaSangatPanjang,
    email: emailSangatPanjang,
    employeeId: 'SDK-0031-DENGAN-NOMOR-PEGAWAI-YANG-JUGA-PANJANG-SEKALI',
    role: UserRole.admin,
    status: UserStatus.aktif,
    organizationId: 1,
    department:
        'Departemen Pengendalian Mutu dan Pengembangan Metode Kalibrasi Lanjutan',
  ),
  const User(
    id: 32,
    nama: 'Tanpa Departemen',
    email: 'tanpa@lab.test',
    employeeId: '',
    role: UserRole.viewer,
    status: UserStatus.nonaktif,
    organizationId: null,
  ),
  const User(
    id: 33,
    nama: namaSangatPanjang,
    email: emailSangatPanjang,
    employeeId: 'SDK-0033',
    role: UserRole.teknisi,
    status: UserStatus.pending,
    organizationId: 1,
  ),
];

final _pelangganBuruk = <Customer>[
  const Customer(
    id: 17,
    nama:
        'PT Perusahaan Kalibrasi Industri Nusantara Sejahtera Makmur Abadi '
        'Sentosa Jaya Raya Tbk Cabang Surabaya Timur',
    alamat: '',
    contactPerson: namaSangatPanjang,
    telepon: '0812345678901234',
    email: '',
    jumlahAlat: 1234,
    alatCount: 1234,
    sertifikatCount: 98765,
    anggotaAktifCount: 4321,
    undanganMenungguCount: 12,
  ),
  const Customer(
    id: 18,
    nama: 'PT Uji Sejahtera',
    alamat: '',
    contactPerson: '',
    telepon: '',
    email: '',
    jumlahAlat: 3,
    alatCount: 3,
    sertifikatCount: 5,
    anggotaAktifCount: 0,
    undanganMenungguCount: 1,
    tanpaAkun: true,
    namaNormalKosong: true,
  ),
  const Customer(
    id: 19,
    nama: 'CV Singkat',
    alamat: '',
    contactPerson: 'Rina',
    telepon: '',
    email: '',
    jumlahAlat: 5,
  ),
];

/// Anggota/undangan dengan nama dan email sangat panjang serta data kosong.
DataAnggotaPelanggan dataAnggotaBuruk() => DataAnggotaPelanggan.fromJson({
  'data': {
    'customer': {'id': 17, 'nama': _pelangganBuruk.first.nama},
    'maks_anggota': 50,
    'jumlah_aktif': 3,
    'pic_admin': {
      'id': 4,
      'nama': namaSangatPanjang,
      'email': emailSangatPanjang,
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
          'nama': namaSangatPanjang,
          'email': emailSangatPanjang,
          'telepon': '0812000000',
          'jabatan': 'Manajer Pengendalian Mutu dan Kepatuhan Regulasi Lab',
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
        'id': 43,
        'peran': 'staf',
        'status': 'aktif',
        'bergabung_pada': null,
        'dinonaktifkan_pada': null,
        'dinonaktifkan_oleh': null,
        'pic_utama_terakhir': false,
        'bisa_dicabut': true,
        'orang': null,
      },
      {
        'id': 40,
        'peran': 'staf',
        'status': 'nonaktif',
        'bergabung_pada': '2026-10-20T01:00:00+00:00',
        'dinonaktifkan_pada': '2026-11-10T09:30:00+00:00',
        'dinonaktifkan_oleh': {'id': 4, 'nama': namaSangatPanjang},
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
        'email': emailSangatPanjang,
        'peran': 'pic_utama',
        'kedaluwarsa_pada': '2026-11-25T08:00:00+00:00',
        'dibuat_pada': '2026-11-18T08:00:00+00:00',
        'diundang_oleh': {'id': 4, 'nama': namaSangatPanjang},
      },
      {
        'id': 13,
        'email': 'staf@contoh.test',
        'peran': 'staf',
        'kedaluwarsa_pada': null,
        'dibuat_pada': null,
        'diundang_oleh': null,
      },
    ],
  },
});

DataAnggotaPelanggan _dataKosong() => DataAnggotaPelanggan.fromJson({
  'data': {
    'customer': {'id': 17, 'nama': 'PT Contoh Makmur'},
    'maks_anggota': 50,
    'jumlah_aktif': 0,
    'pic_admin': null,
    'anggota': [],
    'undangan_menunggu': [],
  },
});

/// Alat dengan nama/merek/seri sangat panjang dan data kosong.
final _alatBuruk = <AlatRingkas>[
  const AlatRingkas(
    id: 701,
    nama: namaSangatPanjang,
    merk: 'Merek Internasional Dengan Nama Sangat Panjang Sekali Corporation',
    model: 'MODEL-SERI-SANGAT-PANJANG-DENGAN-KODE-1234567890',
    nomorSeri: 'SN-1234567890-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0987654321',
    status: 'overdue',
    jumlahSertifikat: 12345,
  ),
  const AlatRingkas(id: 702, nama: 'Timbangan', status: 'aktif'),
  AlatRingkas(
    id: 703,
    nama: 'Thermohygrometer Digital',
    merk: 'Fluke',
    model: '1620A',
    nomorSeri: 'SN-9',
    status: 'nonaktif',
    jatuhTempo: DateTime(2027, 3, 14),
    jumlahSertifikat: 3,
  ),
];

const _alatRiwayat = AlatRingkas(
  id: 701,
  nama: namaSangatPanjang,
  merk: 'Merek Internasional Dengan Nama Sangat Panjang Sekali Corporation',
  model: 'MODEL-SERI-SANGAT-PANJANG-DENGAN-KODE-1234567890',
  nomorSeri: 'SN-1234567890-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0987654321',
  status: 'aktif',
  jumlahSertifikat: 60,
);

/// Pratinjau terburuk: nama PT, alat, dan anggota sangat panjang; banyak orang.
final _pratinjauBuruk = PratinjauPindahAlat(
  dari: RingkasPt(
    id: 17,
    nama: _pelangganBuruk.first.nama,
    anggotaAktifCount: 0,
  ),
  ke: const RingkasPt(
    id: 18,
    nama:
        'PT Perusahaan Tujuan Dengan Nama Yang Juga Sangat Panjang Sekali Tbk',
    anggotaAktifCount: 4321,
  ),
  jumlahAlat: 3,
  alat: const [
    AlatDipindah(
      id: 701,
      nama: namaSangatPanjang,
      nomorSeri: 'SN-1234567890-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0987654321',
      jumlahSertifikat: 12345,
    ),
    AlatDipindah(id: 702, nama: 'Timbangan', jumlahSertifikat: 0),
    AlatDipindah(
      id: 703,
      nama: 'Thermohygrometer Digital',
      nomorSeri: 'SN-9',
      jumlahSertifikat: 3,
    ),
  ],
  sertifikatTerdampak: 12348,
  sertifikatTerlihatPelanggan: 12000,
  anggotaMulaiMelihat: [
    for (var i = 0; i < 3; i++)
      OrangTerdampak(id: i, nama: namaSangatPanjang, email: emailSangatPanjang),
  ],
  anggotaBerhentiMelihat: const [
    OrangTerdampak(id: 9, nama: 'Sari Dewi', email: 'sari@contoh.test'),
  ],
  paketTerkaitCount: 4,
  peringatan: const [
    PeringatanPindah(kode: 'paket_tidak_dipindah', pesan: 'paket'),
    PeringatanPindah(kode: 'arsip_tidak_dipindah', pesan: 'arsip'),
    PeringatanPindah(kode: 'isi_sertifikat_tetap', pesan: 'isi'),
  ],
);

LapisanUjiSa _lapisanPindah({
  Object? galatPratinjau,
  Object? galatPindah,
  Duration jeda = Duration.zero,
}) => LapisanUjiSa(
  riwayat: MockRiwayatAlatService(alatTetap: _alatBuruk),
  anggota:
      MockAnggotaPelangganService(
          pelanggan: _pelangganBuruk,
          data: dataAnggotaBuruk(),
          jeda: jeda,
          pratinjauTetap: _pratinjauBuruk,
        )
        ..galatPratinjau = galatPratinjau
        ..galatPindah = galatPindah,
);

/// Jalankan [KeadaanSa.sesudah] sesuai aturan `tinggiBesar` (lihat di sana).
Future<void> jalankanSesudah(WidgetTester tester, KeadaanSa k) async {
  final sesudah = k.sesudah;
  if (sesudah == null) return;
  if (!k.tinggiBesar) {
    await sesudah(tester);
    return;
  }
  final asli = tester.view.physicalSize;
  tester.view.physicalSize = Size(asli.width, 8000);
  await tester.pump();
  await sesudah(tester);
  tester.view.physicalSize = asli;
  await tester.pump();
}

/// Ketuk [finder] di layar APA PUN: bila belum dibangun (daftar malas di layar
/// 320 dp) digulir dulu; bila di luar layar disorong ke dalam. Tanpa ini
/// interaksi tes gagal di layar kecil padahal tata letaknya benar.
Future<void> ketukDi(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Gulir VERTIKAL pertama (kotak isian satu baris punya gulir mendatar
    // sendiri yang tidak boleh terpilih).
    final gulir = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.vertical,
    );
    if (gulir.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: gulir.first,
        maxScrolls: 200,
      );
    }
  }
  expect(finder, findsWidgets, reason: 'tidak ditemukan: $finder');
  final alvo = finder.first;
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

Future<void> _pilihAlatPindah(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('pilih-alat-701')));
  await ketukDi(tester, find.byKey(const Key('pilih-alat-702')));
}

Future<void> _pilihAlatDanTujuan(WidgetTester tester) async {
  await _pilihAlatPindah(tester);
  await ketukDi(tester, find.byKey(const Key('pilih-tujuan')));
  await tester.pumpAndSettle();
  await ketukDi(tester, find.byKey(const Key('tujuan-18')));
  await tester.pumpAndSettle();
}

Future<void> _isiAlasanPindah(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('alasan-pindah')));
  await tester.enterText(
    find.byKey(const Key('alasan-pindah')),
    'PT salah ketik, pemilik sebenarnya PT lain yang sudah punya akun pelanggan.',
  );
  await tester.pump();
}

Future<void> _konfirmasiPindah(WidgetTester tester) async {
  await _isiAlasanPindah(tester);
  await ketukDi(tester, find.byKey(const Key('pindahkan')));
  await tester.pumpAndSettle();
}

Future<void> _eksekusiPindah(WidgetTester tester) async {
  await _konfirmasiPindah(tester);
  await tester.tap(find.byKey(const Key('konfirmasi-pindah')));
  await tester.pumpAndSettle();
}

Customer get _pelangganDetail => _pelangganBuruk.first;

Future<void> _gulirKeAlat(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Alat pelanggan'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _menu(WidgetTester tester, int id, String aksi) async {
  await ketukDi(tester, find.byKey(Key('menu-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(aksi));
  await tester.pumpAndSettle();
}

Future<void> _isiGantiSandiKosong(WidgetTester tester) async {
  await ketukDi(tester, find.widgetWithText(FilledButton, 'Ganti sandi'));
  await tester.pumpAndSettle();
}

LapisanUjiSa _lapisanPengguna({
  bool kosong = false,
  Object? galat,
  Duration jeda = Duration.zero,
}) => LapisanUjiSa(
  pengguna: MockPenggunaSaService(
    awal: kosong
        ? <User>[]
        : [...MockPenggunaSaService.contoh, ...penggunaBurukSa],
    galat: galat,
    jeda: jeda,
  ),
);

LapisanUjiSa _lapisanPelanggan({
  List<Customer>? pelanggan,
  DataAnggotaPelanggan? data,
  Object? galat,
  Object? galatAmbil,
  Duration jeda = Duration.zero,
  RiwayatAlatService? riwayat,
}) => LapisanUjiSa(
  riwayat: riwayat ?? MockRiwayatAlatService(alatTetap: _alatBuruk),
  anggota: MockAnggotaPelangganService(
    pelanggan: pelanggan ?? _pelangganBuruk,
    data: data ?? dataAnggotaBuruk(),
    galat: galat,
    galatAmbil: galatAmbil,
    jeda: jeda,
  ),
);

/// Layar yang dijalankan di MATRIKS lebar x skala huruf (lihat
/// `super_admin_responsif_test.dart`).
final List<KeadaanSa> layarMatriksSa = [
  KeadaanSa(
    'hub',
    () => const PengelolaanSuperAdminScreen(),
    () => LapisanUjiSa(),
  ),
  KeadaanSa(
    'pengguna-daftar',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(),
  ),
  KeadaanSa(
    'pengguna-form-tambah',
    () => const PenggunaFormScreen(),
    () => LapisanUjiSa(),
  ),
  KeadaanSa(
    'pengguna-form-ubah',
    () => PenggunaFormScreen(akun: penggunaBurukSa.first),
    () => LapisanUjiSa(),
  ),
  KeadaanSa(
    'pelanggan-daftar',
    () => const PelangganSaScreen(),
    () => _lapisanPelanggan(),
  ),
  KeadaanSa(
    'pelanggan-detail',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(),
  ),
  KeadaanSa(
    'detail-alat',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(),
    sesudah: _gulirKeAlat,
    tinggiBesar: false,
  ),
  KeadaanSa(
    'riwayat-sertifikat',
    () => const RiwayatSertifikatAlatScreen(alat: _alatRiwayat),
    () => LapisanUjiSa(),
  ),
  KeadaanSa(
    'pindah-pilih',
    () => PindahkanAlatScreen(asal: _pelangganDetail),
    () => _lapisanPindah(),
    sesudah: _pilihAlatPindah,
  ),
  KeadaanSa(
    'pindah-pratinjau',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(),
    sesudah: _isiAlasanPindah,
  ),
  KeadaanSa(
    'ganti-sandi',
    () => const GantiSandiScreen(),
    () => LapisanUjiSa(),
  ),
];

/// Keadaan lain (kosong, galat, memuat, dialog): diuji di kombinasi ukuran
/// terburuk, dan semuanya dipotret oleh harness PNG.
final List<KeadaanSa> keadaanLainSa = [
  KeadaanSa(
    'pengguna-memuat',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(jeda: _jedaMemuat),
    menahan: true,
  ),
  KeadaanSa(
    'pengguna-kosong',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(kosong: true),
  ),
  KeadaanSa(
    'pengguna-galat',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(galat: const KoneksiException('x')),
  ),
  KeadaanSa(
    'pengguna-dialog-nonaktifkan',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(),
    sesudah: (t) => _menu(t, 21, 'Nonaktifkan akun'),
  ),
  KeadaanSa(
    'pengguna-dialog-setel-sandi',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(),
    sesudah: (t) => _menu(t, 21, 'Setel ulang sandi'),
  ),
  KeadaanSa(
    'pengguna-dialog-aktifkan',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(),
    sesudah: (t) => _menu(t, 23, 'Aktifkan kembali'),
  ),
  KeadaanSa(
    'pengguna-dialog-setujui',
    () => const PenggunaScreen(),
    () => _lapisanPengguna(),
    sesudah: (t) async {
      await ketukDi(t, find.text('Setujui'));
      await t.pumpAndSettle();
    },
  ),
  KeadaanSa(
    'pengguna-form-galat',
    () => const PenggunaFormScreen(),
    () => LapisanUjiSa(),
    sesudah: (t) async {
      await ketukDi(t, find.text('Buat akun'));
      await t.pumpAndSettle();
    },
  ),
  KeadaanSa(
    'pelanggan-kosong',
    () => const PelangganSaScreen(),
    () => _lapisanPelanggan(pelanggan: const []),
  ),
  KeadaanSa(
    'pelanggan-galat',
    () => const PelangganSaScreen(),
    () => _lapisanPelanggan(galat: const KoneksiException('x')),
  ),
  KeadaanSa(
    'detail-memuat',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(jeda: _jedaMemuat),
    menahan: true,
  ),
  KeadaanSa(
    'detail-kosong',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(data: _dataKosong()),
  ),
  KeadaanSa(
    'detail-galat',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(
      galatAmbil: const ApiException('Data nggak ketemu.', status: 404),
    ),
  ),
  KeadaanSa(
    'detail-dialog-cabut',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(),
    sesudah: (t) async {
      final tombol = find.descendant(
        of: find.byKey(const Key('anggota-42')),
        matching: find.text('Cabut akses'),
      );
      await ketukDi(t, tombol);
      await t.pumpAndSettle();
    },
  ),
  KeadaanSa(
    'detail-dialog-pic',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(),
    sesudah: (t) async {
      await ketukDi(t, find.text('Ubah PIC admin'));
      await t.pumpAndSettle();
    },
  ),
  KeadaanSa(
    'detail-dialog-batalkan',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(),
    sesudah: (t) async {
      final tombol = find.descendant(
        of: find.byKey(const Key('undangan-12')),
        matching: find.text('Batalkan undangan'),
      );
      await ketukDi(t, tombol);
      await t.pumpAndSettle();
    },
  ),
  KeadaanSa(
    'detail-alat-kosong',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(riwayat: MockRiwayatAlatService(jumlahAlat: 0)),
    sesudah: _gulirKeAlat,
    tinggiBesar: false,
  ),
  KeadaanSa(
    'detail-alat-galat',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(
      riwayat: MockRiwayatAlatService(
        galat: const KoneksiException('Nggak bisa nyambung ke server.'),
      ),
    ),
    sesudah: _gulirKeAlat,
    tinggiBesar: false,
  ),
  KeadaanSa(
    'detail-alat-memuat',
    () => PelangganDetailScreen(pelanggan: _pelangganDetail),
    () => _lapisanPelanggan(riwayat: MockRiwayatAlatService(jeda: _jedaMemuat)),
    sesudah: _gulirKeAlat,
    tinggiBesar: false,
    menahan: true,
  ),
  KeadaanSa(
    'riwayat-kosong',
    () => const RiwayatSertifikatAlatScreen(alat: _alatRiwayat),
    () => LapisanUjiSa(riwayat: MockRiwayatAlatService(jumlahSertifikat: 0)),
  ),
  KeadaanSa(
    'riwayat-galat',
    () => const RiwayatSertifikatAlatScreen(alat: _alatRiwayat),
    () => LapisanUjiSa(
      riwayat: MockRiwayatAlatService(
        galat: const KoneksiException('Nggak bisa nyambung ke server.'),
      ),
    ),
  ),
  KeadaanSa(
    'riwayat-memuat',
    () => const RiwayatSertifikatAlatScreen(alat: _alatRiwayat),
    () => LapisanUjiSa(riwayat: MockRiwayatAlatService(jeda: _jedaMemuat)),
    menahan: true,
  ),
  KeadaanSa(
    'pindah-pilih-kosong',
    () => PindahkanAlatScreen(asal: _pelangganDetail),
    () => _lapisanPindah(),
  ),
  KeadaanSa(
    'pindah-pilih-siap',
    () => PindahkanAlatScreen(asal: _pelangganDetail),
    () => _lapisanPindah(),
    sesudah: _pilihAlatDanTujuan,
  ),
  KeadaanSa(
    'pindah-pilih-tanpa-alat',
    () => PindahkanAlatScreen(asal: _pelangganDetail),
    () => LapisanUjiSa(riwayat: MockRiwayatAlatService(jumlahAlat: 0)),
  ),
  KeadaanSa(
    'pindah-pratinjau-memuat',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(jeda: _jedaMemuat),
    menahan: true,
  ),
  KeadaanSa(
    'pindah-pratinjau-galat',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(
      galatPratinjau: const KoneksiException('Nggak bisa nyambung ke server.'),
    ),
  ),
  KeadaanSa(
    'pindah-dialog-konfirmasi',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(),
    sesudah: _konfirmasiPindah,
  ),
  KeadaanSa(
    'pindah-galat-409',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(
      galatPindah: const ApiException(
        'x',
        status: 409,
        body: {'kode': 'alat_sudah_pindah', 'message': 'x'},
      ),
    ),
    sesudah: _eksekusiPindah,
  ),
  KeadaanSa(
    'pindah-sukses',
    () => PratinjauPindahAlatScreen(
      asal: _pelangganBuruk[0],
      tujuan: _pelangganBuruk[1],
      alatIds: const [701, 702, 703],
    ),
    () => _lapisanPindah(),
    sesudah: _eksekusiPindah,
  ),
  KeadaanSa(
    'ganti-sandi-galat',
    () => const GantiSandiScreen(),
    () => LapisanUjiSa(),
    sesudah: _isiGantiSandiKosong,
  ),
  KeadaanSa(
    'ganti-sandi-sukses',
    () => const GantiSandiScreen(),
    () => LapisanUjiSa(),
    sesudah: (t) async {
      for (final (kunci, isi) in [
        ('ganti-lama', 'sandi-lama-benar'),
        ('ganti-baru', 'sandi-baru-123'),
        ('ganti-ulang', 'sandi-baru-123'),
      ]) {
        final kolom = find.byKey(Key(kunci));
        await ketukDi(t, kolom);
        await t.enterText(kolom, isi);
      }
      await _isiGantiSandiKosong(t);
    },
  ),
];
