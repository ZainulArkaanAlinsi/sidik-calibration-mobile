import '../../models/calibration_history_item.dart';
import '../../models/garis_waktu_arsip.dart';
import 'tanggal_api.dart';

// Penyusun baris tampilan layar Arsip — fungsi murni, tanpa widget, supaya
// aturan "satu baris per alat" dan "PT terpisah jelas" bisa diuji sendiri.
//
// Yang dilakukan di sini cuma MENATA ulang apa yang sudah dikirim server:
// urutan, jumlah, dan label tidak dihitung ulang (kontrak arsip-cari §0).

/// Satu alat dengan semua sesinya yang ikut hasil cari.
class KelompokInstrumen {
  const KelompokInstrumen(this.kunci, this.wakil, this.lainnya);

  /// Identitas kelompok yang stabil selama halaman bertambah (wakilnya bisa
  /// berganti kalau halaman berikutnya membawa sertifikat yang lebih baru).
  final String kunci;

  /// Baris yang tampil: sertifikat TERBIT terbaru alat ini; kalau belum ada
  /// yang terbit, sesi terbarunya (keputusan produk 13 Nov 2026). "Terbaru"
  /// = id sesi terbesar.
  final CalibrationHistoryItem wakil;

  /// Sesi lain alat yang sama, urutan server. Dilipat di bawah [wakil].
  final List<CalibrationHistoryItem> lainnya;
}

/// Kata yang berarti "tidak ada nomor seri" — diisi teknisi supaya kolom wajib
/// tidak kosong, jadi bukan identitas alat.
const _seriKosongBermakna = {
  'n/a',
  'na',
  'none',
  'null',
  'tidak ada',
  'tdk ada',
  'belum ada',
};

bool _seriPlaceholder(String seri) =>
    RegExp(r'^[\s\-–—_./0]*$').hasMatch(seri) ||
    _seriKosongBermakna.contains(seri);

/// Kunci "alat yang sama".
///
/// Utamanya id alat di master (`equipment.id`): nomor seri di lembar kerja
/// adalah isian teks bebas, jadi "-" atau "N/A" bisa sama untuk dua alat yang
/// berbeda, dan dua jenis alat bisa kebetulan berseri sama di satu PT.
///
/// Cadangan untuk respons tanpa `equipment.id`: PT + nama alat + nomor seri,
/// huruf besar/kecil tak berpengaruh — dan HANYA bila nomor serinya berarti
/// (bukan kosong atau placeholder). Null = tidak digabung dengan apa pun.
String? kunciAlat(CalibrationHistoryItem sesi) {
  final id = sesi.equipmentId;
  if (id != null) return 'alat:$id';

  final seri = sesi.nomorSeri?.trim().toLowerCase();
  if (seri == null || seri.isEmpty || _seriPlaceholder(seri)) return null;
  final pt = (sesi.namaPelanggan ?? '').trim().toLowerCase();
  final alat = sesi.namaAlat.trim().toLowerCase();
  return 'seri:$pt\u0000$alat\u0000$seri';
}

/// Sertifikat terbit terbaru; tanpa terbitan, sesi terbaru. Terbaru = id
/// terbesar (id sesi naik menurut waktu dibuat).
CalibrationHistoryItem _pilihWakil(List<CalibrationHistoryItem> anggota) {
  final terbit = [
    for (final s in anggota)
      if (s.sertifikatTerbit) s,
  ];
  final kandidat = terbit.isNotEmpty ? terbit : anggota;
  return kandidat.reduce((a, b) => b.id > a.id ? b : a);
}

/// Satu kelompok per alat. Posisi kelompok = kemunculan pertama salah satu
/// anggotanya menurut urutan server, jadi halaman yang dimuat belakangan
/// tidak menyelip di atas posisi gulir pengguna.
List<KelompokInstrumen> kelompokkanPerAlat(List<CalibrationHistoryItem> baris) {
  final urut = <(String, List<CalibrationHistoryItem>)>[];
  final berdasarkanKunci = <String, List<CalibrationHistoryItem>>{};

  for (final sesi in baris) {
    final kunci = kunciAlat(sesi);
    final ada = kunci == null ? null : berdasarkanKunci[kunci];
    if (ada != null) {
      ada.add(sesi);
      continue;
    }

    final anggota = [sesi];
    urut.add((kunci ?? 'sesi:${sesi.id}', anggota));
    if (kunci != null) berdasarkanKunci[kunci] = anggota;
  }

  return [
    for (final (kunci, anggota) in urut)
      () {
        final wakil = _pilihWakil(anggota);
        return KelompokInstrumen(kunci, wakil, [
          for (final s in anggota)
            if (!identical(s, wakil)) s,
        ]);
      }(),
  ];
}

/// Baris yang digambar daftar Arsip.
sealed class BarisDaftarArsip {
  const BarisDaftarArsip();
}

/// Judul PT; [nama] null = baris tanpa pelanggan.
class BarisJudulPt extends BarisDaftarArsip {
  const BarisJudulPt(this.nama);

  final String? nama;
}

class BarisJudulHari extends BarisDaftarArsip {
  const BarisJudulHari(this.hari);

  final KelompokGarisWaktu hari;
}

class BarisInstrumen extends BarisDaftarArsip {
  const BarisInstrumen(this.instrumen);

  final KelompokInstrumen instrumen;
}

class BarisSertifikat extends BarisDaftarArsip {
  const BarisSertifikat(this.item);

  final ItemGarisWaktu item;
}

String? _bersih(String? nama) {
  final t = nama?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Hasil cari: satu baris per alat, dengan judul PT tiap kali PT berganti.
///
/// Judulnya muncul setiap PT berganti di antara baris yang BERURUTAN, bukan
/// dikumpulkan per PT: urutan server (peringkat cocok, lalu terbaru) tidak
/// diubah, dan halaman yang dimuat belakangan selalu menempel di ujung bawah
/// — baris tidak pernah menyelip di atas posisi gulir pengguna. Harga yang
/// dibayar: PT yang sama bisa punya judul lebih dari sekali. Pilih satu PT di
/// saringan untuk melihatnya utuh; [judulPt] dimatikan di situ.
List<BarisDaftarArsip> susunHasil(
  List<CalibrationHistoryItem> baris, {
  required bool judulPt,
}) {
  final hasil = <BarisDaftarArsip>[];
  String? kunciSebelumnya;
  var pertama = true;

  for (final alat in kelompokkanPerAlat(baris)) {
    final nama = _bersih(alat.wakil.namaPelanggan);
    final kunci = nama?.toLowerCase();

    if (judulPt && (pertama || kunci != kunciSebelumnya)) {
      hasil.add(BarisJudulPt(nama));
    }
    pertama = false;
    kunciSebelumnya = kunci;

    hasil.add(BarisInstrumen(alat));
  }

  return hasil;
}

/// Tingkat `hari`: kelompok per hari (urutan, label, dan jumlah dari server)
/// dengan dokumen yang SUDAH dimuat di bawah harinya masing-masing.
///
/// Hari yang dokumennya belum termuat (halaman berikutnya) tetap tampil
/// dengan jumlah dari server. Dokumen yang harinya tidak cocok dengan
/// kelompok mana pun ditaruh di ujung, bukan dibuang.
List<BarisDaftarArsip> susunHari(
  List<KelompokGarisWaktu> hari,
  List<ItemGarisWaktu> item, {
  required bool judulPt,
}) {
  final perHari = <String, List<ItemGarisWaktu>>{};
  for (final dokumen in item) {
    final tanggal = dokumen.tanggal;
    final kunci = tanggal == null ? '' : tanggalApi(tanggal);
    (perHari[kunci] ??= []).add(dokumen);
  }

  final hasil = <BarisDaftarArsip>[];

  void tambahkan(List<ItemGarisWaktu> daftar) {
    String? kunciSebelumnya;
    var pertama = true;

    for (final dokumen in daftar) {
      final nama = _bersih(dokumen.perusahaan);
      final kunci = '${dokumen.pelangganId ?? ''}|${nama?.toLowerCase() ?? ''}';

      if (judulPt && (pertama || kunci != kunciSebelumnya)) {
        hasil.add(BarisJudulPt(nama));
      }
      pertama = false;
      kunciSebelumnya = kunci;

      hasil.add(BarisSertifikat(dokumen));
    }
  }

  for (final kelompok in hari) {
    hasil.add(BarisJudulHari(kelompok));
    tambahkan(perHari.remove(kelompok.kunci) ?? const []);
  }

  // Sisa: dokumen tanpa hari yang cocok.
  for (final sisa in perHari.values) {
    tambahkan(sisa);
  }

  return hasil;
}
