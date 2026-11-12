import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/audit_log.dart';
import '../services/audit_log_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;
import 'penjaga_urutan_muat.dart';

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  if (AppConfig.useMock) return MockAuditLogService();
  return ApiAuditLogService(ref.watch(apiClientProvider));
});

/// Riwayat perubahan data lab. Baca-saja; dipaginasi di server (25/halaman),
/// jadi state-nya menyimpan halaman terakhir seperti `equipmentProvider`.
final auditLogProvider =
    AsyncNotifierProvider<AuditLogController, List<AuditLogItem>>(
      AuditLogController.new,
      retry: (retryCount, error) => null,
    );

class AuditLogController extends AsyncNotifier<List<AuditLogItem>>
    with PenjagaUrutanMuat<List<AuditLogItem>> {
  FilterAuditLog _filter = const FilterAuditLog();
  int _page = 1;
  int _lastPage = 1;

  /// Akun yang memiliki [_filter] sekarang. Notifier yang sama dipakai ulang
  /// waktu `build()` jalan lagi, jadi field-nya TIDAK ikut bersih sendiri
  /// saat akun ganti — penyaring milik admin A tidak boleh jadi penyaring
  /// awal admin B.
  int? _pemilikFilter;

  FilterAuditLog get filter => _filter;
  bool get bisaMuatLagi => _page < _lastPage;

  @override
  Future<List<AuditLogItem>> build() async {
    // Daftarkan build ini sebagai permintaan terbaru SEBELUM apa pun, supaya
    // "muat lebih banyak" yang masih di jalan milik akun/penyaring sebelumnya
    // dianggap ketinggalan dan dibuang — tanpa ini halaman 2 akun A bisa
    // mendarat sesudah akun B login dan menempel ke daftar B.
    final nomor = mulaiPermintaan();

    // Ikut akun yang login: ganti akun → data lab sebelumnya nggak ikut.
    final akun = ref.watch(authProvider).value;
    if (akun?.id != _pemilikFilter) {
      _pemilikFilter = akun?.id;
      _filter = const FilterAuditLog();
    }

    _page = 1;
    final hasil = await _ambil(1);
    // Metadata halaman cuma dipasang kalau build ini masih yang terbaru:
    // build yang disusul build lain (ganti akun dua kali) tidak boleh menimpa
    // metadata milik yang sekarang.
    if (masihTerbaru(nomor)) _lastPage = hasil.lastPage;

    return hasil.items;
  }

  Future<HalamanAuditLog> _ambil(int page) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    return ref
        .read(auditLogServiceProvider)
        .daftar(token, filter: _filter, page: page);
  }

  Future<void> _muatUlangTerjaga() async {
    HalamanAuditLog? hasil;

    await muatDenganPenjaga(
      () async {
        hasil = await _ambil(1);
        return hasil!.items;
      },
      // `muatDenganPenjaga` memanggil ini juga waktu permintaannya GAGAL
      // (hasil masih null): halaman kembali ke 1, tanpa halaman berikutnya.
      saatTerbaru: () {
        _page = 1;
        _lastPage = hasil?.lastPage ?? 1;
      },
    );
  }

  Future<void> terapkanFilter(FilterAuditLog filter) async {
    _filter = filter;
    await _muatUlangTerjaga();
  }

  Future<void> muatUlang() => _muatUlangTerjaga();

  /// Menambah halaman berikutnya ke daftar yang sudah ada (bukan memuat ulang)
  /// supaya posisi gulir tidak loncat. Kegagalan dilempar ke pemanggil — layar
  /// yang menampilkan pesannya, daftar yang sudah kelihatan tidak dirusak.
  Future<void> muatLebihBanyak() async {
    final sebelum = state.value;
    if (sebelum == null || !bisaMuatLagi) return;

    // Nomor diambil SEBELUM await pertama (alasan di `EquipmentController`).
    final nomor = mulaiPermintaan();
    final halaman = _page + 1;

    final hasil = await _ambil(halaman);

    if (!masihTerbaru(nomor)) return;

    _page = halaman;
    _lastPage = hasil.lastPage;
    state = AsyncValue.data([...sebelum, ...hasil.items]);
  }
}
