import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/calibration_history_item.dart';
import '../models/garis_waktu_arsip.dart';
import '../models/pencarian_arsip.dart';
import '../services/arsip_cari_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final arsipCariServiceProvider = Provider<ArsipCariService>((ref) {
  if (AppConfig.useMock) return MockArsipCariService();
  return ApiArsipCariService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Saringan layar Arsip yang sedang berlaku (sudah lewat debounce).
///
/// Memuat id PT milik satu lab, jadi ikut dibuang waktu akun berganti — yang
/// dipantau id akunnya, bukan seluruh `authProvider`, supaya penyegaran
/// profil di latar tidak menghapus saringan yang sedang dipakai.
final filterArsipProvider =
    NotifierProvider<FilterArsipController, FilterArsip>(
      FilterArsipController.new,
    );

class FilterArsipController extends Notifier<FilterArsip> {
  @override
  FilterArsip build() {
    ref.watch(authProvider.select((a) => a.value?.id));
    return FilterArsip.kosong;
  }

  void aturKata(String mentah) => _setel(state.denganKata(mentah));

  void aturRentang(DateTime? dari, DateTime? sampai) =>
      _setel(state.denganRentang(dari, sampai));

  void aturPelanggan(int? id, String? nama) =>
      _setel(state.denganPelanggan(id, nama));

  void bersihkan() => _setel(FilterArsip.kosong);

  // Nilai yang sama tidak boleh memicu ambil ulang: ketikan yang menghasilkan
  // kata sama (spasi di ujung) bukan alasan menembak server lagi.
  void _setel(FilterArsip baru) {
    if (baru != state) state = baru;
  }
}

/// Satu langkah penelusuran garis waktu. [label] kosong untuk akar.
class LangkahGarisWaktu {
  const LangkahGarisWaktu(this.posisi, [this.label]);

  final PosisiGarisWaktu posisi;
  final String? label;
}

/// Tumpukan tingkat yang sedang dibuka (tahun › bulan › pekan › hari).
///
/// Kembali ke akar waktu saringan PT berganti: tahun/bulan/pekan yang dibuka
/// untuk PT lama belum tentu berisi apa-apa untuk PT baru.
final jalurGarisWaktuProvider =
    NotifierProvider<JalurGarisWaktuController, List<LangkahGarisWaktu>>(
      JalurGarisWaktuController.new,
    );

class JalurGarisWaktuController extends Notifier<List<LangkahGarisWaktu>> {
  static const _akar = LangkahGarisWaktu(PosisiGarisWaktu.akar);

  @override
  List<LangkahGarisWaktu> build() {
    ref.watch(authProvider.select((a) => a.value?.id));
    ref.watch(filterArsipProvider.select((f) => f.pelangganId));
    return const [_akar];
  }

  /// Buka tingkat berikutnya persis menurut `telusuri` kelompok dari server.
  void masuk(KelompokGarisWaktu kelompok) {
    final tujuan = kelompok.telusuri;
    if (tujuan == null || tujuan == state.last.posisi) return;
    state = [...state, LangkahGarisWaktu(tujuan, kelompok.label)];
  }

  void naik() {
    if (state.length > 1) state = state.sublist(0, state.length - 1);
  }

  /// Kembali ke langkah [indeks] (0 = akar), membuang yang lebih dalam.
  void kembaliKe(int indeks) {
    if (indeks < 0 || indeks >= state.length - 1) return;
    state = state.sublist(0, indeks + 1);
  }
}

/// Isi satu tingkat garis waktu, berikut dokumen yang sudah termuat (tingkat
/// `hari`).
class StatusGarisWaktu {
  const StatusGarisWaktu({
    required this.posisi,
    required this.pelangganId,
    required this.halaman,
    required this.item,
    required this.halamanDimuat,
    required this.halamanTerakhir,
    this.akunId,
    this.memuatLagi = false,
    this.galatMuatLagi,
  });

  /// Untuk mencocokkan isi dengan tingkat yang sedang ditampilkan: sesudah
  /// berpindah tingkat, isi lama masih sempat terbaca sebentar.
  final PosisiGarisWaktu posisi;
  final int? pelangganId;

  /// Akun yang datanya ini. Isi akun lain tidak boleh tampil, sekejap pun,
  /// selagi data akun yang baru dimuat.
  final int? akunId;

  /// Halaman pertama — kelompok dan total datang dari sini.
  final HalamanGarisWaktu halaman;
  final List<ItemGarisWaktu> item;
  final int halamanDimuat;
  final int halamanTerakhir;
  final bool memuatLagi;
  final Object? galatMuatLagi;

  bool get bisaMuatLagi => halamanDimuat < halamanTerakhir;

  StatusGarisWaktu _salin({
    List<ItemGarisWaktu>? item,
    int? halamanDimuat,
    int? halamanTerakhir,
    required bool memuatLagi,
    Object? galat,
  }) => StatusGarisWaktu(
    posisi: posisi,
    pelangganId: pelangganId,
    halaman: halaman,
    item: item ?? this.item,
    halamanDimuat: halamanDimuat ?? this.halamanDimuat,
    halamanTerakhir: halamanTerakhir ?? this.halamanTerakhir,
    akunId: akunId,
    memuatLagi: memuatLagi,
    galatMuatLagi: galat,
  );
}

final garisWaktuProvider =
    AsyncNotifierProvider<GarisWaktuController, StatusGarisWaktu>(
      GarisWaktuController.new,
      retry: (retryCount, error) => null,
    );

class GarisWaktuController extends AsyncNotifier<StatusGarisWaktu> {
  /// Naik tiap `build()`. Jawaban `muatLebihBanyak` yang datang sesudah
  /// tingkat/saringan berganti dibuang, bukan ditempelkan ke isi yang baru.
  int _generasi = 0;

  @override
  Future<StatusGarisWaktu> build() async {
    _generasi++;
    final akunId = ref.watch(authProvider).value?.id;
    final langkah = ref.watch(jalurGarisWaktuProvider).last;
    final pelangganId = ref.watch(
      filterArsipProvider.select((f) => f.pelangganId),
    );

    final token = await _token(ref);
    final halaman = await ref
        .read(arsipCariServiceProvider)
        .garisWaktu(token, posisi: langkah.posisi, pelangganId: pelangganId);

    return StatusGarisWaktu(
      posisi: langkah.posisi,
      pelangganId: pelangganId,
      halaman: halaman,
      item: halaman.item,
      halamanDimuat: halaman.halaman,
      halamanTerakhir: halaman.halamanTerakhir,
      akunId: akunId,
    );
  }

  /// Jawaban halaman berikutnya hanya boleh menempel bila isi yang sekarang
  /// MASIH isi yang diminta: bukan sedang dimuat ulang, dan tingkat, PT, serta
  /// akunnya sama. Penjaga generasi saja tidak cukup — `build()` baru sudah
  /// menaikkannya sebelum tombol "muat lagi" sempat ditekan di daftar lama.
  bool _masihIsiYangSama(StatusGarisWaktu saat, int generasi) {
    if (!ref.mounted || generasi != _generasi || state.isLoading) return false;
    final kini = state.value;
    return kini != null &&
        kini.posisi == saat.posisi &&
        kini.pelangganId == saat.pelangganId &&
        kini.akunId == saat.akunId;
  }

  Future<void> muatUlang() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Galatnya sudah ada di `state`; layar yang menampilkannya.
    }
  }

  /// Halaman dokumen berikutnya (tingkat `hari`). Berhenti di
  /// `meta.last_page`; dokumen yang id-nya sudah ada tidak digandakan.
  Future<void> muatLebihBanyak() async {
    final saat = state.value;
    // `state.isLoading`: isi yang tampil adalah sisa tingkat/saringan lama
    // selagi yang baru dimuat — halaman berikutnya miliknya tidak boleh
    // diminta.
    if (saat == null ||
        state.isLoading ||
        !saat.bisaMuatLagi ||
        saat.memuatLagi) {
      return;
    }

    final generasi = _generasi;
    state = AsyncData(saat._salin(memuatLagi: true));

    try {
      final token = await _token(ref);
      final jawab = await ref
          .read(arsipCariServiceProvider)
          .garisWaktu(
            token,
            posisi: saat.posisi,
            pelangganId: saat.pelangganId,
            halaman: saat.halamanDimuat + 1,
          );
      if (!_masihIsiYangSama(saat, generasi)) return;

      final sudahAda = {for (final i in saat.item) i.id};
      state = AsyncData(
        saat._salin(
          item: [
            ...saat.item,
            for (final i in jawab.item)
              if (!sudahAda.contains(i.id)) i,
          ],
          halamanDimuat: saat.halamanDimuat + 1,
          halamanTerakhir: jawab.halamanTerakhir,
          memuatLagi: false,
        ),
      );
    } catch (e) {
      if (!_masihIsiYangSama(saat, generasi)) return;
      state = AsyncData(saat._salin(memuatLagi: false, galat: e));
    }
  }
}

/// Hasil cari: sesi menurut saringan, halaman demi halaman.
class HasilCariArsip {
  const HasilCariArsip({
    required this.filter,
    required this.baris,
    required this.halaman,
    required this.halamanTerakhir,
    required this.total,
    this.akunId,
    this.memuatLagi = false,
    this.galatMuatLagi,
  });

  /// Tidak ada saringan hasil → tidak ada panggilan server.
  factory HasilCariArsip.belumDicari(FilterArsip filter, {int? akunId}) =>
      HasilCariArsip(
        filter: filter,
        baris: const [],
        halaman: 0,
        halamanTerakhir: 0,
        total: 0,
        akunId: akunId,
      );

  final FilterArsip filter;
  final List<CalibrationHistoryItem> baris;
  final int halaman;
  final int halamanTerakhir;

  /// `meta.total` — jumlah SESI cocok menurut server (bukan jumlah alat).
  final int total;

  /// Akun yang hasilnya ini; hasil akun lain tidak boleh tampil.
  final int? akunId;
  final bool memuatLagi;
  final Object? galatMuatLagi;

  bool get bisaMuatLagi => halaman > 0 && halaman < halamanTerakhir;

  HasilCariArsip _salin({
    List<CalibrationHistoryItem>? baris,
    int? halaman,
    int? halamanTerakhir,
    int? total,
    required bool memuatLagi,
    Object? galat,
  }) => HasilCariArsip(
    filter: filter,
    baris: baris ?? this.baris,
    halaman: halaman ?? this.halaman,
    halamanTerakhir: halamanTerakhir ?? this.halamanTerakhir,
    total: total ?? this.total,
    akunId: akunId,
    memuatLagi: memuatLagi,
    galatMuatLagi: galat,
  );
}

final hasilCariArsipProvider =
    AsyncNotifierProvider<HasilCariArsipController, HasilCariArsip>(
      HasilCariArsipController.new,
      retry: (retryCount, error) => null,
    );

class HasilCariArsipController extends AsyncNotifier<HasilCariArsip> {
  int _generasi = 0;

  @override
  Future<HasilCariArsip> build() async {
    _generasi++;
    final akunId = ref.watch(authProvider).value?.id;
    final filter = ref.watch(filterArsipProvider);

    if (!filter.modeHasil) {
      return HasilCariArsip.belumDicari(filter, akunId: akunId);
    }

    final token = await _token(ref);
    final jawab = await ref
        .read(arsipCariServiceProvider)
        .cariRiwayat(token, filter: filter);

    return HasilCariArsip(
      filter: filter,
      baris: jawab.baris,
      halaman: jawab.halaman,
      halamanTerakhir: jawab.halamanTerakhir,
      total: jawab.total,
      akunId: akunId,
    );
  }

  /// Lihat `GarisWaktuController._masihIsiYangSama`.
  bool _masihIsiYangSama(HasilCariArsip saat, int generasi) {
    if (!ref.mounted || generasi != _generasi || state.isLoading) return false;
    final kini = state.value;
    return kini != null &&
        kini.filter == saat.filter &&
        kini.akunId == saat.akunId;
  }

  Future<void> muatUlang() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Galatnya sudah ada di `state`; layar yang menampilkannya.
    }
  }

  /// Halaman berikutnya. Urutan server stabil (peringkat, lalu `id` menurun),
  /// jadi halaman demi halaman tidak menggandakan dan tidak melewatkan baris;
  /// id yang sudah ada tetap dilewati sebagai pengaman.
  Future<void> muatLebihBanyak() async {
    final saat = state.value;
    // `state.isLoading`: yang tampil masih daftar saringan LAMA selagi
    // saringan baru dimuat; halaman berikutnya miliknya tidak boleh diminta,
    // atau jawabannya menimpa hasil saringan baru.
    if (saat == null ||
        state.isLoading ||
        !saat.bisaMuatLagi ||
        saat.memuatLagi) {
      return;
    }

    final generasi = _generasi;
    state = AsyncData(saat._salin(memuatLagi: true));

    try {
      final token = await _token(ref);
      final jawab = await ref
          .read(arsipCariServiceProvider)
          .cariRiwayat(token, filter: saat.filter, halaman: saat.halaman + 1);
      if (!_masihIsiYangSama(saat, generasi)) return;

      final sudahAda = {for (final b in saat.baris) b.id};
      state = AsyncData(
        saat._salin(
          baris: [
            ...saat.baris,
            for (final b in jawab.baris)
              if (!sudahAda.contains(b.id)) b,
          ],
          halaman: saat.halaman + 1,
          halamanTerakhir: jawab.halamanTerakhir,
          total: jawab.total,
          memuatLagi: false,
        ),
      );
    } catch (e) {
      if (!_masihIsiYangSama(saat, generasi)) return;
      state = AsyncData(saat._salin(memuatLagi: false, galat: e));
    }
  }
}
