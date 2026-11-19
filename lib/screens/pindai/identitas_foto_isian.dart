import '../../services/identitas_kertas.dart';
import '../calibration/lembar_kerja_state.dart';

/// Kolom lembar yang menampung identitas dari kertas. Kode kolom yang SAMA
/// dengan yang diketik teknisi (`alat_model`, ...): tidak ada jalur baru ke
/// payload, dan sel yang tidak ada di lembar tertentu dilewati.
const kolomIdentitasKertas = <String>[
  'alat_model',
  'alat_serial_number',
  'alat_merk',
  'pemilik_nama',
  'pemilik_alamat',
  'lokasi_nama',
];

/// Identitas dari kertas masuk ke kotak teks lembar sebagai SARAN, lewat
/// mekanisme "dari foto" yang sudah ada (`isianDariFoto` + `cekIsian`): tampil
/// "Perlu dicek", ikut gerbang wajib-cek sebelum kirim, dan tidak pernah dianggap
/// sudah dicek sampai teknisi mengubah isinya atau menekan konfirmasi.
extension IdentitasFotoIsian on LembarKerjaState {
  /// Menuang [id] ke kotak teks lembar. Kotak yang sudah ada isinya TIDAK
  /// ditimpa (nilai teknisi tidak pernah dihapus), kolom yang tidak ada di
  /// lembar ini dilewati, dan bidang kosong tetap kosong.
  ///
  /// Mengembalikan jumlah kotak yang terisi.
  int terapkanIdentitasKertas(IdentitasKertas id) {
    var terisi = 0;

    void isi(String kode, String? nilai) {
      final kotak = teks[kode];
      final v = nilai?.trim() ?? '';
      if (kotak == null || v.isEmpty) return;
      if (kotak.text.trim().isNotEmpty) return;

      kotak.text = v;
      isianDariFoto.add(kode);
      cekIsian.tandai(kode, kotak.text);
      terisi++;
    }

    isi('alat_model', id.model);
    isi('alat_serial_number', id.seri);
    isi('alat_merk', id.merk);
    isi('pemilik_nama', id.pemilik);
    isi('pemilik_alamat', id.alamat);
    isi('lokasi_nama', id.lokasi);

    if (terisi > 0) {
      adaIsianDariFoto = true;
      revisiCek.value++;
    }

    return terisi;
  }

  /// Teknisi menetapkan nilai [kode] SENDIRI (mengetik di panel, atau memilih
  /// "Pakai yang terdaftar"): kotak diisi dan tanda "dari foto" dilepas, karena
  /// nilainya kini keputusan manusia, bukan saran mesin.
  void tetapkanIdentitasOlehTeknisi(String kode, String nilai) {
    final kotak = teks[kode];
    if (kotak == null) return;

    kotak.text = nilai.trim();
    isianDariFoto.remove(kode);
    cekIsian.lepas(kode);
    revisiCek.value++;
  }

  /// Nilai [kode] di lembar masih SARAN dari kertas (belum diubah teknisi)?
  bool identitasMasihSaran(String kode, String dariKertas) =>
      isianDariFoto.contains(kode) &&
      (teks[kode]?.text.trim() ?? '') == dariKertas.trim();
}
