import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_item.dart';

/// Notifikasi tingkat SISTEM OPERASI — yang nongol di bilah HP dan di pojok
/// layar laptop, bukan lonceng di dalam app.
///
/// Bedanya penting: lonceng cuma kelihatan sama orang yang lagi mbuka app-nya.
/// Admin yang lagi ngerjain hal lain di laptop nggak akan tahu ada lembar kerja
/// baru masuk dari teknisi sampai dia kebetulan mbuka app-nya lagi — dan itu
/// persis kejadian yang bikin kiriman teknisi nganggur seharian.
///
/// **Sengaja dipisah jadi antarmuka.** Yang manggil (provider realtime) nggak
/// boleh kenal `flutter_local_notifications` langsung: test widget nggak punya
/// binding plugin native, dan tanpa lapisan ini tiap test yang nyentuh alur
/// notifikasi bakal gagal di channel yang nggak ada.
abstract class NotifikasiPerangkat {
  /// Siapin channel & minta izin. Aman dipanggil berkali-kali.
  ///
  /// Balikin `false` kalau user nolak izinnya — app tetap jalan, cuma
  /// notifikasinya nggak nongol. Nolak izin BUKAN error.
  Future<bool> siapkan();

  /// Tampilin satu notifikasi sistem.
  Future<void> tampilkan(NotificationItem item);
}

/// Implementasi asli — `flutter_local_notifications`.
///
/// Dipakai buat Android, iOS, macOS, dan Windows. Bukan Firebase: selama
/// app-nya JALAN, kabar dari server udah nyampe lewat websocket Reverb yang
/// app ini punya, jadi nampilin notifikasinya nggak butuh layanan pihak ketiga
/// sama sekali. Firebase baru perlu buat satu kasus yang websocket nggak bisa
/// tutup — HP dengan app ketutup total.
class LocalNotifikasiPerangkat implements NotifikasiPerangkat {
  LocalNotifikasiPerangkat({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _siap = false;

  /// Satu channel buat semua kabar kerja. Dipisah dari channel bawaan supaya
  /// user bisa matiin notifikasi app ini sendiri lewat setelan Android tanpa
  /// mesti matiin app-nya.
  static const _channelId = 'sidik_kerja';

  @override
  Future<bool> siapkan() async {
    if (_siap) return true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Izin diminta belakangan lewat `requestNotificationsPermission`, bukan
    // pas init: kalau diminta pas app pertama kebuka, orang nolaknya sambil
    // lalu karena belum tahu app-nya buat apa.
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // Windows minta identitas app yang tetap. GUID-nya SENGAJA dipatok di
    // sini — Windows nyimpen riwayat & setelan notifikasi per GUID, jadi
    // angka yang berubah tiap rilis bikin setelan user kereset diam-diam.
    const windows = WindowsInitializationSettings(
      appName: 'Sidik Calibration',
      appUserModelId: 'com.ptsidik.kalibrasi',
      guid: '9d3f6c2a-7b41-4e58-9c0d-2f7a1b8e5d34',
    );

    final ok = await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        macOS: apple,
        windows: windows,
      ),
    );

    _siap = ok ?? false;
    if (_siap) await _mintaIzin();
    return _siap;
  }

  Future<void> _mintaIzin() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @override
  Future<void> tampilkan(NotificationItem item) async {
    if (!_siap && !await siapkan()) return;

    await _plugin.show(
      id: _idAngka(item.id),
      title: item.judul,
      body: item.isi,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Kabar kerja',
          channelDescription:
              'Lembar kerja masuk, sesi disetujui atau perlu revisi, '
              'sertifikat terbit, dan alat jatuh tempo.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      // Dibawa balik waktu notifikasinya diketuk — dipakai buat mbuka layar
      // yang bersangkutan, bukan cuma mbuka app di halaman depan.
      payload: item.id,
    );
  }

  /// Plugin-nya minta id berupa `int`, sementara notifikasi Laravel id-nya
  /// UUID. Dipetakan lewat `hashCode` yang dipositifkan — bukan nomor urut,
  /// supaya notifikasi yang SAMA (mis. kekirim dua kali gara-gara sambungan
  /// putus-nyambung) nimpa dirinya sendiri, bukan numpuk dua baris.
  static int _idAngka(String id) => id.hashCode & 0x7fffffff;
}

/// Versi test & mode mock: nyatet apa yang mestinya nongol, nggak manggil
/// plugin apa pun.
class MockNotifikasiPerangkat implements NotifikasiPerangkat {
  MockNotifikasiPerangkat({this.izinDikasih = true});

  /// Buat nguji jalur "user nolak izin" — app mesti tetap jalan.
  final bool izinDikasih;

  final List<NotificationItem> ditampilkan = [];
  int jumlahSiapkan = 0;

  @override
  Future<bool> siapkan() async {
    jumlahSiapkan++;
    return izinDikasih;
  }

  @override
  Future<void> tampilkan(NotificationItem item) async {
    if (!izinDikasih) return;
    ditampilkan.add(item);
  }
}
