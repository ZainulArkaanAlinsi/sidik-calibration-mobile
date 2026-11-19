import '../models/customer_lookup.dart';
import '../models/equipment.dart';
import '../models/equipment_lookup.dart';
import 'auth_service.dart' show ApiException;
import 'customer_lookup_service.dart';
import 'equipment_lookup_service.dart';
import 'equipment_service.dart';
import 'identitas_kertas.dart' show kunciSeri, seriBisaDipakai;
import 'simpanan_pelanggan.dart' show SimpananPelanggan;

/// Isian panel "Alat baru" (diisi dari kertas, diedit teknisi).
class DataAlatBaru {
  const DataAlatBaru({
    required this.namaAlat,
    required this.seri,
    required this.pemilik,
    required this.kategori,
    required this.profil,
    this.merk = '',
    this.model = '',
    this.noIdentifikasi = '',
    this.alamat = '',
    this.namaAlatKemampuan,
  });

  final String namaAlat;
  final String seri;
  final String pemilik;

  /// Kode kategori dan jenis kemampuan ditentukan LEMBAR yang dibuka
  /// (`bentuk.alatBaru`), bukan tebakan dari kertas.
  final String kategori;

  /// Kode lembar (jenis alat): alat yang SUDAH ada hanya dianggap sejenis bila
  /// ketemu lewat pencarian per profil ini; kategori terlalu kasar.
  final String profil;
  final String? namaAlatKemampuan;
  final String merk;
  final String model;
  final String noIdentifikasi;
  final String alamat;
}

/// Hasil [PembuatAlatDariKertas.jalankan].
sealed class HasilBuatAlat {
  const HasilBuatAlat();
}

/// Alat BARU yang baru saja dibuat (atau dibuat lebih dulu oleh percobaan yang
/// sama dan dilanjutkan): siap dipakai. Alat yang SUDAH ada sebelum ketukan ini
/// tidak pernah dikembalikan di sini ([SeriSudahTerdaftar]), karena memasang alat
/// orang lain tanpa ketukan berarti profil dan hitungan salah tanpa galat.
class AlatSiap extends HasilBuatAlat {
  const AlatSiap(this.alat);

  final EquipmentLookup alat;
}

/// Nomor seri ini SUDAH terdaftar pada alat SEJENIS (ketemu lewat pencarian per
/// profil lembar). Tidak terpasang dan tidak dibuat kembar: kartu dengan ketukan
/// "Pakai alat ini" (atau teknisi mengubah serinya). [pemilikBeda] = PT alat itu
/// tidak sama dengan PT di panel.
class SeriSudahTerdaftar extends HasilBuatAlat {
  const SeriSudahTerdaftar(this.alat, {required this.pemilikBeda});

  final EquipmentLookup alat;
  final bool pemilikBeda;
}

/// Isian seri bukan nomor seri (kosong, "-", "N/A", "Tidak ada", ...). Tidak ada
/// pencarian, PT, atau alat yang dibuat.
class SeriTidakValid extends HasilBuatAlat {
  const SeriTidakValid();
}

/// Server menemukan PT yang MIRIP (bukan nama persis sama): teknisi memilih
/// salah satunya atau menegaskan ini PT lain. Belum ada alat yang dibuat.
class PtPerluDipilih extends HasilBuatAlat {
  const PtPerluDipilih(this.kandidat);

  final List<CustomerLookup> kandidat;
}

/// Nomor seri ini terdaftar pada alat dari JENIS LAIN (bukan jenis lembar ini,
/// walau kategorinya sama): tidak dipakai dan tidak dibuat kembar. Teknisi
/// memperbaiki serinya (salah baca); tidak ada ketukan untuk memakai alat itu.
class SeriMilikAlatLain extends HasilBuatAlat {
  const SeriMilikAlatLain(this.alat);

  final EquipmentLookup alat;
}

/// Gagal (jaringan, ditolak server). Aman diulang: langkah yang sudah berhasil
/// (PT, alat) tidak dibuat dua kali.
class GagalBuatAlat extends HasilBuatAlat {
  const GagalBuatAlat(this.galat);

  final Object galat;
}

/// Membuat PT dan alat dari panel "Alat baru" LEWAT layanan yang sama dengan
/// form Alat dan PT cepat (`POST /customers/cepat`, `POST /equipments`), dalam
/// urutan PT -> alat. Tidak atomik (dua permintaan), tetapi tiap langkah
/// IDEMPOTEN:
///
///  - PT: nama yang sama (huruf besar-kecil/tanda baca diabaikan) dicari dulu;
///    409 "nama persis sudah ada" memakai PT itu; 409 "mirip" TIDAK menembus
///    otomatis, teknisi yang memilih.
///  - Alat: nomor seri dicari dulu (unik per lab; jenis lembar ini lebih dulu,
///    lalu semua jenis); 422 seri kembar dijawab dengan mencari alat yang ada,
///    bukan membuat lagi. Alat yang SUDAH ada tidak pernah terpasang otomatis
///    ([SeriSudahTerdaftar] / [SeriMilikAlatLain] menunggu ketukan teknisi).
///  - Hasil langkah yang sudah berhasil dipegang di sini, jadi mengulang setelah
///    gagal sebagian tidak membuat PT atau alat ganda.
///
/// Hanya dipanggil dari ketukan teknisi ("Buat dan lanjut").
class PembuatAlatDariKertas {
  PembuatAlatDariKertas({
    required this.pelanggan,
    required this.cariAlat,
    required this.layananAlat,
    required this.token,
  });

  final CustomerLookupService pelanggan;
  final EquipmentLookupService cariAlat;
  final EquipmentService layananAlat;
  final Future<String> Function() token;

  CustomerLookup? _ptSiap;
  EquipmentLookup? _alatSiap;
  Future<HasilBuatAlat>? _berjalan;

  static String _normal(String s) => SimpananPelanggan.normalkan(s);

  /// [ptDipilih] = PT yang diketuk teknisi dari kandidat mirip; [tetapBuatPt] =
  /// teknisi menegaskan PT ini perusahaan lain (menembus yang MIRIP, tidak yang
  /// persis sama).
  Future<HasilBuatAlat> jalankan(
    DataAlatBaru data, {
    CustomerLookup? ptDipilih,
    bool tetapBuatPt = false,
  }) {
    // Ketukan kedua selagi yang pertama berjalan memakai hasil yang sama.
    return _berjalan ??= _kerjakan(
      data,
      ptDipilih,
      tetapBuatPt,
    ).whenComplete(() => _berjalan = null);
  }

  Future<HasilBuatAlat> _kerjakan(
    DataAlatBaru d,
    CustomerLookup? ptDipilih,
    bool tetapBuatPt,
  ) async {
    try {
      // Bukan nomor seri (kosong, "-", "N/A", ...): alat kedua akan menempel
      // diam-diam ke alat pertama yang berseri sama. Tidak ada yang dikerjakan.
      if (!seriBisaDipakai(d.seri)) return const SeriTidakValid();

      final tok = await token();

      // Alat yang sudah berhasil dibuat untuk seri ini tidak dibuat lagi.
      final siap = _alatSiap;
      if (siap != null && kunciSeri(siap.serialNumber) == kunciSeri(d.seri)) {
        return AlatSiap(siap);
      }

      // 1. Seri yang sudah terdaftar dipakai, tidak dibuat kembar. Dicek SEBELUM
      //    PT supaya tidak ada PT yatim untuk alat yang ternyata sudah ada.
      final ada = await _cariSeri(tok, d);
      if (ada != null) return ada;

      // 2. PT.
      CustomerLookup? pt = ptDipilih;
      if (pt == null) {
        final memo = _ptSiap;
        if (memo != null && _normal(memo.nama) == _normal(d.pemilik)) pt = memo;
      }
      if (pt == null) {
        final hasil = await _resolusiPt(tok, d, tetapBuatPt);
        if (hasil is PtPerluDipilih) return hasil;
        pt = (hasil as _PtSiap).pt;
      }
      _ptSiap = pt;

      // 3. Alat.
      final Equipment dibuat;
      try {
        dibuat = await layananAlat.simpan(
          tok,
          Equipment(
            id: 0,
            namaAlat: d.namaAlat.trim(),
            serialNumber: d.seri.trim(),
            kategori: d.kategori,
            status: EquipmentStatus.aktif,
            merk: d.merk.trim(),
            model: d.model.trim(),
            noIdentifikasi: d.noIdentifikasi.trim(),
            pelangganId: pt.id,
            pelangganNama: pt.nama,
            namaAlatKemampuan: d.namaAlatKemampuan,
          ),
        );
      } on ApiException catch (e) {
        // 422 seri sudah dipakai (balapan, atau tidak terlihat oleh pencarian):
        // cari alat itu dan pakai, jangan membuat lagi.
        final errors = e.body['errors'];
        if (e.status == 422 &&
            errors is Map &&
            errors['serial_number'] != null) {
          final lagi = await _cariSeri(tok, d);
          if (lagi != null) return lagi;
        }
        rethrow;
      }

      final lookup = EquipmentLookup(
        id: dibuat.id,
        namaAlat: dibuat.namaAlat,
        serialNumber: dibuat.serialNumber,
        kategori: dibuat.kategori,
        status: dibuat.status.rawValue,
        merk: dibuat.merk,
        model: dibuat.model,
        satuan: dibuat.satuan,
        rangeMin: dibuat.rangeMin,
        rangeMax: dibuat.rangeMax,
        resolusi: dibuat.resolusi,
        pelangganNama: pt.nama,
        pelangganAlamat: (pt.alamat ?? '').isNotEmpty ? pt.alamat! : d.alamat,
        lokasi: dibuat.lokasi,
      );
      _alatSiap = lookup;

      return AlatSiap(lookup);
    } catch (e) {
      return GagalBuatAlat(e);
    }
  }

  /// Alat dengan seri ini yang SUDAH terdaftar. Sejenis (ketemu lewat pencarian
  /// per profil lembar) = [SeriSudahTerdaftar]; ketemu hanya tanpa profil = jenis
  /// lain = [SeriMilikAlatLain] (kategori sama TIDAK cukup: satu kategori memuat
  /// banyak jenis, dan server memilih profil dari alat yang dikirim). Keduanya
  /// menunggu ketukan teknisi. `null` = belum ada.
  Future<HasilBuatAlat?> _cariSeri(String tok, DataAlatBaru d) async {
    final kunci = kunciSeri(d.seri);
    final seri = d.seri.trim();

    EquipmentLookup? persis(List<EquipmentLookup> hasil) {
      for (final a in hasil) {
        if (kunciSeri(a.serialNumber) == kunci) return a;
      }

      return null;
    }

    final sejenis = persis(
      await cariAlat.cari(tok, search: seri, profil: d.profil),
    );
    if (sejenis != null) {
      return SeriSudahTerdaftar(sejenis, pemilikBeda: _pemilikBeda(sejenis, d));
    }

    final lain = persis(await cariAlat.cari(tok, search: seri));

    return lain == null ? null : SeriMilikAlatLain(lain);
  }

  /// PT alat yang sudah ada berbeda dari PT di panel (keduanya terisi).
  bool _pemilikBeda(EquipmentLookup a, DataAlatBaru d) {
    final terdaftar = a.pelangganNama.trim();
    final kertas = d.pemilik.trim();
    if (terdaftar.isEmpty || kertas.isEmpty) return false;

    return _normal(terdaftar) != _normal(kertas);
  }

  Future<Object> _resolusiPt(String tok, DataAlatBaru d, bool tetapBuat) async {
    final nama = d.pemilik.trim();
    final normal = _normal(nama);

    // Nama yang sama sudah terdaftar: pakai.
    final ada = await pelanggan.cari(tok, search: nama);
    final sama = [
      for (final c in ada)
        if (_normal(c.nama) == normal) c,
    ];
    if (sama.isNotEmpty) {
      return _PtSiap(
        sama.firstWhere((c) => c.nama == nama, orElse: () => sama.first),
      );
    }

    try {
      final baru = await pelanggan.daftarkan(
        tok,
        nama: nama,
        alamat: d.alamat.trim().isEmpty ? null : d.alamat.trim(),
        tetapBuat: tetapBuat,
      );

      return _PtSiap(baru);
    } on PelangganMiripException catch (e) {
      if (e.namaPersisSudahAda) {
        // Buntu di server: nama persis sama sudah ada. Pakai yang itu.
        final persis = [
          for (final c in e.kandidat)
            if (_normal(c.nama) == normal) c,
        ];
        if (persis.isNotEmpty) return _PtSiap(persis.first);
        rethrow;
      }

      return PtPerluDipilih(e.kandidat);
    }
  }
}

class _PtSiap {
  const _PtSiap(this.pt);

  final CustomerLookup pt;
}
