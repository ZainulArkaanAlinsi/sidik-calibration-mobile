import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/perusahaan_direktori.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart'
    show kunciSeri;
import 'package:sidik_calibration/services/simpanan_pelanggan.dart'
    show SimpananPelanggan;

/// Layanan tiruan untuk tes "alat dari kertas": pencarian alat (meniru
/// `GET /equipments?search=` dengan seri dinormalkan server), `POST
/// /equipments`, dan PT (daftar, 409 mirip). Dipakai tes layanan dan tes blok.

/// Pencarian alat tiruan: daftar yang bisa berubah antar-panggilan.
///
/// [sembunyikanDariProfil] = id alat yang TIDAK ikut bila `profil` diberikan
/// (meniru penyaring jenis lembar di server: alat jenis lain tidak muncul di
/// pencarian per profil, tetapi tetap ditemukan tanpa profil).
class PencariAlatUji implements EquipmentLookupService {
  PencariAlatUji([List<EquipmentLookup>? awal]) : alat = [...?awal];

  final List<EquipmentLookup> alat;
  Set<int> sembunyikanDariProfil = {};
  bool gagal = false;
  int dipanggil = 0;
  final kueri = <String?>[];

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async {
    dipanggil++;
    kueri.add(search);
    if (gagal) throw Exception('server nggak nyaut');
    final q = kunciSeri(search ?? '');
    final disembunyikan = profil != null
        ? sembunyikanDariProfil
        : const <int>{};

    // Tanpa kata kunci = daftar lengkap (seperti `GET /equipments`); dengan kata
    // kunci = seri yang dinormalkan server.
    return [
      for (final a in alat)
        if (!disembunyikan.contains(a.id) &&
            ((search ?? '').trim().isEmpty ||
                (q.isNotEmpty && kunciSeri(a.serialNumber).contains(q))))
          a,
    ];
  }
}

/// `POST /equipments` tiruan: mencatat yang dikirim, bisa diprogram gagal.
class LayananAlatUji implements EquipmentService {
  LayananAlatUji({this.sebelumSimpan});

  /// Dipanggil sebelum menyimpan; boleh melempar atau mengubah dunia (mis.
  /// menambah alat kembar, meniru balapan).
  Future<void> Function(Equipment data)? sebelumSimpan;

  final dikirim = <Equipment>[];
  int _id = 500;

  @override
  Future<Equipment> simpan(String token, Equipment data) async {
    await sebelumSimpan?.call(data);
    dikirim.add(data);

    return Equipment(
      id: _id++,
      namaAlat: data.namaAlat,
      serialNumber: data.serialNumber,
      kategori: data.kategori,
      status: data.status,
      merk: data.merk,
      model: data.model,
      noIdentifikasi: data.noIdentifikasi,
      pelangganId: data.pelangganId,
      pelangganNama: data.pelangganNama,
      namaAlatKemampuan: data.namaAlatKemampuan,
    );
  }

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int? pelangganId,
    int? jatuhTempoDalam,
    bool termasukLewat = false,
    String? urut,
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<Equipment> ubah(String token, Equipment data) =>
      throw UnimplementedError();

  @override
  Future<void> hapus(String token, int id) => throw UnimplementedError();
}

/// PT tiruan: daftar PT yang ada, hitung `daftarkan`, dan jawaban 409 mirip.
class PtUji implements CustomerLookupService {
  PtUji({List<CustomerLookup>? ada, this.mirip = const []}) : _ada = [...?ada];

  final List<CustomerLookup> _ada;
  final List<CustomerLookup> mirip;
  int didaftarkan = 0;

  /// Berapa kali PT dicari (`GET /customers/lookup`).
  int jumlahCari = 0;
  bool? terakhirTetapBuat;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    jumlahCari++;

    return [
      for (final c in _ada)
        // Seperti `CustomerController::lookup()`: nama dinormalkan (tanda baca
        // dan spasi ganda diratakan) sebelum dicari.
        if ((search ?? '').isEmpty ||
            SimpananPelanggan.normalkan(
              c.nama,
            ).contains(SimpananPelanggan.normalkan(search ?? '')))
          c,
    ];
  }

  @override
  Future<HasilDirektori> cariDirektori(
    String token, {
    required String search,
  }) => throw UnimplementedError();

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) async {
    terakhirTetapBuat = tetapBuat;
    if (mirip.isNotEmpty && !tetapBuat) {
      throw PelangganMiripException(
        pesan: 'Ada pelanggan yang mirip.',
        kandidat: mirip,
        namaPersisSudahAda: false,
      );
    }
    didaftarkan++;
    final baru = CustomerLookup(
      id: 900 + didaftarkan,
      nama: nama,
      alamat: alamat,
    );
    _ada.add(baru);

    return baru;
  }
}
