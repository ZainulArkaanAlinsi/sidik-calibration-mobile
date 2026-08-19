import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/inisial_nama.dart';

/// Avatar tanpa foto nampilin huruf awal nama — dan nama KOSONG nggak boleh
/// bikin layarnya mati.
///
/// Kartu profil dulu motongnya sendiri lewat `nama.characters.first`, yang
/// nglempar `StateError` buat string kosong. Panel samping desktop di app yang
/// sama udah jaga kasus itu dengan `?`. Jadi satu-satunya layar yang orang buka
/// buat MBENERIN datanya justru yang jatuh duluan waktu datanya bolong.
void main() {
  test('nama kosong dapat penanda, bukan StateError', () {
    expect(inisialNama(''), '?');
    expect(inisialNama('   '), '?');
  });

  test('maksimal dua huruf, huruf besar', () {
    expect(inisialNama('Raihan Nazhiif Yudhistira'), 'RN');
    expect(inisialNama('joko'), 'J');
  });

  test('spasi berlebih di tengah nggak bikin inisial kosong', () {
    expect(inisialNama('  Zainul   Arkaan  '), 'ZA');
  });

  test('penanda kosongnya bisa disetel pemanggil', () {
    expect(inisialNama('', kalauKosong: '—'), '—');
  });

  /// Kartu profil nulis SATU huruf besar di avatar gede, panel desktop dua
  /// huruf di lingkaran kecil. Yang disatukan aturan nama kosongnya, bukan
  /// tampilannya — dan golden `profil.png` yang jadi juri kalau ini kegeser.
  test('jumlah hurufnya bisa dibatasi pemanggil', () {
    expect(inisialNama('Raihan Nazhiif Yudhistira', maks: 1), 'R');
    expect(inisialNama('', maks: 1), '?');
  });
}
