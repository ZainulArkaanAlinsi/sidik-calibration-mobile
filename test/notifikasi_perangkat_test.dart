import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/notification_item.dart';
import 'package:sidik_calibration/providers/notifikasi_perangkat_provider.dart';
import 'package:sidik_calibration/services/notifikasi_perangkat.dart';

/// Notifikasi sistem operasi — yang nongol di bilah HP & pojok layar laptop.
///
/// Yang diuji di sini bukan plugin-nya (itu native, nggak ada di widget test),
/// tapi KEPUTUSAN mana yang layak dibunyiin. Salah di lapisan ini ada dua
/// bentuk, dan dua-duanya bikin orang matiin notifikasinya:
///
///  - banjir waktu login (semua yang belum dibaca ikut bunyi sekaligus), dan
///  - bunyi ulang buat notifikasi yang itu-itu juga tiap sambungan
///    putus-nyambung.
void main() {
  var urut = 0;

  NotificationItem notif(String id, {bool dibaca = false}) => NotificationItem(
    id: id,
    kategori: NotifKategori.sesiMenungguApproval,
    judul: 'Lembar kerja masuk',
    isi: 'Teknisi Joko ngirim sesi $id',
    dibaca: dibaca,
    dibuatPada: DateTime(2026, 8, 20, 9, urut++),
  );

  test('yang udah ada waktu login dicatat, nggak dibunyiin', () async {
    final perangkat = MockNotifikasiPerangkat();
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([notif('a'), notif('b'), notif('c')]);

    expect(perangkat.ditampilkan, isEmpty);
    // Izin diminta di sini — sesudah orangnya login, bukan waktu app pertama
    // kebuka dan dia belum tahu app-nya buat apa.
    expect(perangkat.jumlahSiapkan, 1);
  });

  test('cuma yang beneran baru yang nongol', () async {
    final perangkat = MockNotifikasiPerangkat();
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([notif('a')]);
    await pengabar.umumkan([notif('b'), notif('a')]);

    expect(perangkat.ditampilkan.map((n) => n.id), ['b']);
  });

  test('umuman kedua nggak ngulang yang sama', () async {
    final perangkat = MockNotifikasiPerangkat();
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([]);
    await pengabar.umumkan([notif('b')]);
    await pengabar.umumkan([notif('b')]);

    expect(perangkat.ditampilkan.length, 1);
  });

  test('yang udah dibaca di perangkat lain nggak ikut bunyi', () async {
    final perangkat = MockNotifikasiPerangkat();
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([]);
    // Orangnya udah mbuka ini di HP; laptopnya nggak perlu ikut bunyi.
    await pengabar.umumkan([notif('b', dibaca: true), notif('c')]);

    expect(perangkat.ditampilkan.map((n) => n.id), ['c']);
  });

  test('urutannya dibalik — yang terbaru berakhir di paling atas', () async {
    final perangkat = MockNotifikasiPerangkat();
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([]);
    // API ngirim terbaru-duluan; bilah notifikasi numpuk dari bawah.
    await pengabar.umumkan([notif('baru'), notif('lama')]);

    expect(perangkat.ditampilkan.map((n) => n.id), ['lama', 'baru']);
  });

  test('izin ditolak → app tetap jalan, cuma nggak ada yang nongol', () async {
    final perangkat = MockNotifikasiPerangkat(izinDikasih: false);
    final pengabar = PengabarNotifikasi(perangkat);

    await pengabar.mulai([]);
    await pengabar.umumkan([notif('b')]);

    expect(perangkat.ditampilkan, isEmpty);
  });
}
