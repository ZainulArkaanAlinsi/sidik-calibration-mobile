import 'dart:typed_data';

import '../services/peta_tabel_foto.dart';
import '../services/vonis_sel_foto.dart';

/// Satu baris di layar review hasil foto — satu sel tabel yang mau dimasukkan.
///
/// [potongan] PNG potongan citra sel ini, buat diadu ke bacaannya di layar yang
/// sama. `null` = potongannya gagal dibuat (sel jatuh di luar tepi foto, atau
/// citranya sudah nggak ada). Barisnya tetap ditampilkan tanpa gambar — yang
/// hilang alat bantunya, bukan selnya.
typedef BarisReviewFoto = ({
  double titikUkur,
  int repeatNo,
  String fieldId,
  String judul,
  String teks,
  double? keyakinan,
  VonisFoto vonis,
  Uint8List? potongan,
});

/// Kunci unik satu sel — dipakai buat menjodohkan baris review dengan
/// potongan citranya, dan buat mengembalikan nilai yang disetujui.
String kunciSelFoto(double titikUkur, int repeatNo, String fieldId) =>
    '$titikUkur|$repeatNo|$fieldId';

/// Susun bahan layar review dari hasil pemetaan foto.
///
/// ## Kenapa urutannya bukan urutan sel
///
/// Yang paling butuh mata teknisi ditaruh DULUAN: merah (bacaannya nggak bisa
/// dipercaya, kotaknya dikosongkan), lalu yang keyakinannya tidak diketahui,
/// lalu kuning. Layar yang mengurut menurut nomor baris bikin sel merah
/// tenggelam di tengah tiga puluh sel yang bacaannya wajar — dan yang paling
/// mungkin salah justru yang paling gampang kelewat.
///
/// Di dalam satu golongan urutannya tetap urutan kertas (titik ukur, lalu
/// Repeat), supaya teknisi bisa menelusurinya sambil melihat lembarnya.
List<BarisReviewFoto> susunReviewFoto({
  required List<SelTabelFoto> sel,
  required String Function(SelTabelFoto) judul,
  Map<String, Uint8List> potongan = const {},
  AmbangKeyakinan ambang = AmbangKeyakinan.bawaan,
}) {
  final baris = [
    for (final s in sel)
      (
        titikUkur: s.titikUkur,
        repeatNo: s.repeatNo,
        fieldId: s.fieldId,
        judul: judul(s),
        teks: s.teks,
        keyakinan: s.keyakinan,
        vonis: NilaiVonisFoto.dari(s.keyakinan, ambang: ambang),
        potongan: potongan[kunciSelFoto(s.titikUkur, s.repeatNo, s.fieldId)],
      ),
  ];

  baris.sort((a, b) {
    final p = _prioritas(a.vonis).compareTo(_prioritas(b.vonis));
    if (p != 0) return p;

    final t = a.titikUkur.compareTo(b.titikUkur);
    if (t != 0) return t;

    return a.repeatNo.compareTo(b.repeatNo);
  });

  return baris;
}

int _prioritas(VonisFoto v) => switch (v) {
  VonisFoto.merah => 0,
  VonisFoto.tidakDiketahui => 1,
  VonisFoto.kuning => 2,
  VonisFoto.hijau => 3,
};

/// Sel yang WAJIB disentuh teknisi sebelum boleh dimasukkan.
///
/// Merah saja: kotaknya memang dikosongkan, jadi menyetujuinya tanpa mengetik
/// berarti memasukkan sel kosong. Kuning & tidak-diketahui cukup DILIHAT —
/// menuntut teknisi mengetik ulang tiga puluh sel yang bacaannya sudah benar
/// bikin dia berhenti memakai fiturnya.
bool wajibDiisi(BarisReviewFoto b) => b.vonis == VonisFoto.merah;
