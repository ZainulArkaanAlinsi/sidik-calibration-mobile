import 'dart:typed_data';

import '../core/utils/angka.dart' show parseAngkaInput;

import '../services/peta_tabel_foto.dart';
import 'lembar_kerja_submission.dart' show BacaanMesin;
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

/// Capture the recognizer output before the technician edits the review.
Map<String, BacaanMesin> bacaanMesinFoto(List<SelTabelFoto> sel) =>
    Map.unmodifiable({
      for (final s in sel)
        kunciSelFoto(s.titikUkur, s.repeatNo, s.fieldId): BacaanMesin(
          teksMentah: s.teks,
          keyakinan: s.keyakinan,
        ),
    });

/// Empty and non-finite values are not readings.
bool angkaFotoFinite(String teks) => parseAngkaInput(teks)?.isFinite ?? false;

/// Storage representation guard, not a metrological limit.
/// API raw_measurements.pembacaan uses decimal(20,8): 12 integer digits and
/// 8 decimal places (2026_07_14_120700_create_raw_measurements_table.php).
/// Compare exact decimal values, including exponent notation, so trailing
/// zeros are harmless but parsing/formatting cannot silently change a digit.
bool angkaFotoSah(String teks) {
  final nilai = parseAngkaInput(teks);
  if (nilai == null || !nilai.isFinite || nilai.abs() >= 1e12) return false;
  final asli = _desimalKanonik(teks.trim().replaceAll(',', '.'));
  // Payload readings are doubles: JSON uses their shortest decimal form.
  // Fixed-8 equality alone can hide the different value actually sent.
  return asli != null &&
      asli == _desimalKanonik(nilai.toString()) &&
      asli == _desimalKanonik(nilai.toStringAsFixed(8));
}

String? _desimalKanonik(String teks) {
  final m = RegExp(
    r'^([+-]?)(?:(\d+)(?:\.(\d*))?|\.(\d+))(?:[eE]([+-]?\d+))?$',
  ).firstMatch(teks);
  if (m == null) return null;
  final pecahan = m[3] ?? m[4] ?? '';
  var digit = '${m[2] ?? ''}$pecahan'.replaceFirst(RegExp(r'^0+'), '');
  if (digit.isEmpty) return '0';
  final eksponen = int.tryParse(m[5] ?? '0');
  if (eksponen == null) return null;
  var pangkat = eksponen - pecahan.length;
  while (digit.endsWith('0')) {
    digit = digit.substring(0, digit.length - 1);
    pangkat++;
  }
  return '${m[1] == '-' ? '-' : ''}$digit@$pangkat';
}

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
