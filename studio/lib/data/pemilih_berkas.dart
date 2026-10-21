import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Berkas yang dipilih orang: [jalur] di perangkat + [nama] untuk tampilan.
typedef BerkasDipilih = ({String jalur, String nama});

/// Ekstensi master yang diterima layar "Unggah master" (K-50-12).
const List<String> ekstensiMaster = ['xlsm', 'xlsx', 'csv'];

/// Ekstensi [nama] termasuk [ekstensiMaster]?
bool ekstensiMasterSah(String nama) {
  final titik = nama.lastIndexOf('.');
  if (titik < 0) return false;
  return ekstensiMaster.contains(nama.substring(titik + 1).toLowerCase());
}

/// Pemilih berkas — provider supaya test memasang tiruan (dialog sistem tidak
/// bisa dijalankan di test). `null` = batal.
final pemilihBerkasMasterProvider = Provider<Future<BerkasDipilih?> Function()>(
  (ref) => () async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ekstensiMaster,
    );
    final f = hasil?.files.single;
    final jalur = f?.path;
    if (f == null || jalur == null) return null;
    return (jalur: jalur, nama: f.name);
  },
);
