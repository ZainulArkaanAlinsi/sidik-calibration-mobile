import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/screens/calibration/widgets/keypad_angka.dart';

void main() {
  String t(String awal, List<TombolKeypad> tombol) =>
      tombol.fold(awal, terapkanTombolKeypad);

  const d1 = TombolDigit('1');
  const d2 = TombolDigit('2');
  const koma = TombolKoma();
  const minus = TombolMinus();
  const hapus = TombolHapus();

  test('digit ditambahkan di belakang', () {
    expect(t('', [d1, d2]), '12');
  });

  test('koma: sekali saja, tidak menyisipkan nol sendiri', () {
    expect(t('', [d1, koma, d2, koma]), '1,2');
    expect(
      t('', [koma]),
      ',',
      reason: 'apa yang diketik teknisi, tanpa nol karangan',
    );
    expect(t('3.5', [koma]), '3.5', reason: 'sudah ada pemisah titik');
  });

  test('minus membalik tanda di depan', () {
    expect(t('', [minus, d1]), '-1');
    expect(t('-1,5', [minus]), '1,5');
    expect(t('1,5', [minus]), '-1,5');
    expect(t('', [minus, minus]), '');
  });

  test('hapus membuang satu karakter; kosong tetap kosong', () {
    expect(t('-7,03', [hapus]), '-7,0');
    expect(t('-', [hapus]), '');
    expect(t('', [hapus]), '');
  });

  test('batas panjang', () {
    final panjang = '1' * panjangMaksKeypad;
    expect(t(panjang, [d2]), panjang);
    expect(t(panjang, [koma]), panjang);
  });
}
