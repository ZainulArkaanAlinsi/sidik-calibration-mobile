import '../models/equipment_lookup.dart';
import 'equipment_lookup_service.dart';
import 'identitas_kertas.dart';
import 'simpanan_pelanggan.dart' show SimpananPelanggan;

/// Hasil mencocokkan identitas kertas ke alat yang sudah terdaftar di lab.
///
/// Kuncinya NOMOR SERI (unik per lab untuk alat hidup, aturan server):
///
///  - [CocokPersis]: seri di kertas sama (huruf besar, tanpa tanda baca) dengan
///    satu alat terdaftar. Tetap menunggu ketukan teknisi; tidak ada yang
///    dipilih atau disalin diam-diam.
///  - [CocokMirip]: tidak ada yang persis, tapi ada yang MIRIP (salah baca satu
///    dua karakter, O/0, I/1). Teknisi memilih ("Maksud Anda?"), tidak pernah
///    dipilihkan.
///  - [AlatBaru]: tidak ada yang cocok, atau seri tidak terbaca. Tidak ada alat
///    yang dibuat di sini; hanya membuka panel "Alat baru" yang diisi dari kertas.
///  - [CocokGagal]: server tidak terjangkau atau menolak. Jujur, tanpa tebakan;
///    lembar tetap bisa dipakai lewat pilihan alat manual.
sealed class HasilCocokAlat {
  const HasilCocokAlat();
}

class CocokPersis extends HasilCocokAlat {
  const CocokPersis(this.alat);

  final EquipmentLookup alat;
}

class CocokMirip extends HasilCocokAlat {
  const CocokMirip(this.kandidat);

  /// Paling banyak [maksKandidatMirip], yang terdekat dulu.
  final List<EquipmentLookup> kandidat;
}

class AlatBaru extends HasilCocokAlat {
  const AlatBaru({required this.seriKosong});

  /// Seri tidak terbaca / kosong: WAJIB diketik, alat tidak dibuat tanpa seri.
  final bool seriKosong;
}

class CocokGagal extends HasilCocokAlat {
  const CocokGagal(this.galat);

  final Object galat;
}

/// Paling banyak kandidat "Maksud Anda?" (arahan pemilik: tiga).
const maksKandidatMirip = 3;

/// Satu bidang identitas yang BEDA antara kertas dan data terdaftar.
class SelisihIdentitas {
  const SelisihIdentitas({
    required this.kode,
    required this.kertas,
    required this.terdaftar,
  });

  /// Kode kolom lembar (`alat_merk`, `alat_model`, `pemilik_nama`, ...).
  final String kode;
  final String kertas;
  final String terdaftar;

  @override
  bool operator ==(Object other) =>
      other is SelisihIdentitas &&
      other.kode == kode &&
      other.kertas == kertas &&
      other.terdaftar == terdaftar;

  @override
  int get hashCode => Object.hash(kode, kertas, terdaftar);

  @override
  String toString() => 'Selisih($kode: kertas "$kertas" != "$terdaftar")';
}

/// Bandingkan teks tanpa memedulikan huruf besar-kecil, tanda baca, spasi ganda.
String _rata(String s) => SimpananPelanggan.normalkan(s);

/// Bidang yang tertulis di kertas DAN di data terdaftar tetapi tidak sama.
/// Bidang yang kosong di salah satu sisi bukan selisih (tidak ada yang dibantah).
List<SelisihIdentitas> selisihIdentitas(
  IdentitasKertas kertas,
  EquipmentLookup alat,
) {
  final hasil = <SelisihIdentitas>[];

  void banding(String kode, String? dariKertas, String terdaftar) {
    final k = dariKertas?.trim() ?? '';
    final t = terdaftar.trim();
    if (k.isEmpty || t.isEmpty) return;
    if (_rata(k) == _rata(t)) return;

    hasil.add(SelisihIdentitas(kode: kode, kertas: k, terdaftar: t));
  }

  banding('alat_merk', kertas.merk, alat.merk);
  banding('alat_model', kertas.model, alat.model);
  banding('pemilik_nama', kertas.pemilik, alat.pelangganNama);

  return hasil;
}

/// Mencocokkan [kertas] ke alat terdaftar lewat `GET /equipments?search=`
/// ([layanan] yang sudah ada; seri persis didahulukan server).
///
/// [profil] = kode lembar: hanya alat berjenis itu yang dicocokkan, jadi seri
/// yang kebetulan sama dengan alat jenis lain tidak ikut. Seri itu tetap
/// ditolak server saat alat baru dibuat (unik per lab) dan ditangani di sana.
///
/// Urutan permintaan (berhenti begitu ada yang PERSIS): seri apa adanya, seri
/// tanpa tanda baca, awalan dan akhiran seri (untuk kandidat mirip). Galat
/// jaringan = [CocokGagal], bukan "alat baru".
Future<HasilCocokAlat> cocokkanAlat({
  required EquipmentLookupService layanan,
  required String token,
  required IdentitasKertas kertas,
  required String profil,
}) async {
  final seri = kertas.seri?.trim() ?? '';
  final kunci = kunciSeri(seri);
  // Kosong, strip, "N/A", "Tidak ada": bukan nomor seri; tidak ada yang dicari.
  if (!seriBisaDipakai(seri)) {
    return const AlatBaru(seriKosong: true);
  }

  final semua = <int, EquipmentLookup>{};

  Future<void> cari(String q) async {
    final hasil = await layanan.cari(token, search: q, profil: profil);
    for (final a in hasil) {
      semua[a.id] = a;
    }
  }

  EquipmentLookup? persis() {
    for (final a in semua.values) {
      if (kunciSeri(a.serialNumber) == kunci) return a;
    }

    return null;
  }

  try {
    await cari(seri);
    var ketemu = persis();

    if (ketemu == null && seri != kunci) {
      await cari(kunci);
      ketemu = persis();
    }
    if (ketemu != null) return CocokPersis(ketemu);

    // Kandidat mirip: server mencari dengan LIKE, jadi seri yang salah baca satu
    // karakter tidak ikut kembali. Awalan dan akhiran seri menjaring yang
    // salah bacanya di bagian lain.
    if (kunci.length >= 6) {
      await cari(kunci.substring(0, 5));
      await cari(kunci.substring(kunci.length - 5));
    }
    final dekat = persis();
    if (dekat != null) return CocokPersis(dekat);

    final mirip =
        [
          for (final a in semua.values)
            if (seriMirip(seri, a.serialNumber)) a,
        ]..sort(
          (a, b) =>
              jarakEdit(
                kunciSeriLonggar(seri),
                kunciSeriLonggar(a.serialNumber),
              ).compareTo(
                jarakEdit(
                  kunciSeriLonggar(seri),
                  kunciSeriLonggar(b.serialNumber),
                ),
              ),
        );

    if (mirip.isNotEmpty) {
      return CocokMirip(mirip.take(maksKandidatMirip).toList());
    }

    return const AlatBaru(seriKosong: false);
  } catch (e) {
    return CocokGagal(e);
  }
}
