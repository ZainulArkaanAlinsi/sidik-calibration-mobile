import '../models/customer_lookup.dart';
import '../models/equipment.dart';
import '../models/equipment_lookup.dart';
import 'auth_service.dart' show ApiException;
import 'customer_lookup_service.dart';
import 'equipment_lookup_service.dart';
import 'equipment_service.dart';
import 'identitas_kertas.dart' show kunciSeri;
import 'simpanan_pelanggan.dart' show SimpananPelanggan;

/// Isian panel "Alat baru" (diisi dari kertas, diedit teknisi).
class DataAlatBaru {
  const DataAlatBaru({
    required this.namaAlat,
    required this.seri,
    required this.pemilik,
    required this.kategori,
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

/// Alat siap dipakai. [sudahAda] = nomor serinya SUDAH terdaftar (dicek sebelum
/// membuat, atau server menolak seri kembar), jadi alat yang ada dipakai dan
/// tidak ada duplikat.
class AlatSiap extends HasilBuatAlat {
  const AlatSiap(this.alat, {required this.sudahAda});

  final EquipmentLookup alat;
  final bool sudahAda;
}

/// Server menemukan PT yang MIRIP (bukan nama persis sama): teknisi memilih
/// salah satunya atau menegaskan ini PT lain. Belum ada alat yang dibuat.
class PtPerluDipilih extends HasilBuatAlat {
  const PtPerluDipilih(this.kandidat);

  final List<CustomerLookup> kandidat;
}

/// Nomor seri ini sudah dipakai alat dari JENIS LAIN: tidak dipakai ulang dan
/// tidak dibuat kembar. Teknisi memperbaiki serinya (salah baca) atau memilih
/// alat yang benar.
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
///  - Alat: nomor seri dicari dulu (unik per lab); 422 seri kembar dijawab
///    dengan mencari alat yang ada, bukan membuat lagi.
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
      final tok = await token();

      // Alat yang sudah berhasil dibuat untuk seri ini tidak dibuat lagi.
      final siap = _alatSiap;
      if (siap != null && kunciSeri(siap.serialNumber) == kunciSeri(d.seri)) {
        return AlatSiap(siap, sudahAda: false);
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

      return AlatSiap(lookup, sudahAda: false);
    } catch (e) {
      return GagalBuatAlat(e);
    }
  }

  /// Alat dengan seri ini yang SUDAH terdaftar: sejenis = dipakai, jenis lain =
  /// ditolak dengan alasan. `null` = belum ada.
  Future<HasilBuatAlat?> _cariSeri(String tok, DataAlatBaru d) async {
    final kunci = kunciSeri(d.seri);
    final hasil = await cariAlat.cari(tok, search: d.seri.trim());
    for (final a in hasil) {
      if (kunciSeri(a.serialNumber) != kunci) continue;

      return a.kategori == d.kategori
          ? AlatSiap(a, sudahAda: true)
          : SeriMilikAlatLain(a);
    }

    return null;
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
