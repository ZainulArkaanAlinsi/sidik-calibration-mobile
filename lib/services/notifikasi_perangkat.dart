import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/navigasi_global.dart';
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
  LocalNotifikasiPerangkat({
    FlutterLocalNotificationsPlugin? plugin,
    this.mintaIzin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _siap = false;

  /// Penjelasan singkat SEBELUM dialog izin sistem Android 13+. Balikan
  /// `false` = pengguna bilang "nanti": dialog sistem tidak dimunculkan.
  /// `null` = langsung minta (perilaku lama; dipakai test).
  final Future<bool> Function()? mintaIzin;

  /// Kanal kabar kerja: lembar masuk, disetujui, revisi, sertifikat terbit.
  /// Nilainya HARUS sama dengan `default_notification_channel_id` di
  /// AndroidManifest (kanal bawaan push FCM waktu aplikasi di latar).
  ///
  /// Dipisah jadi dua kanal supaya pengguna bisa membisukan pengingat jatuh
  /// tempo tanpa kehilangan kabar kerja lewat setelan Android.
  static const kanalKerja = 'sidik_kerja';
  static const kanalPengingat = 'sidik_pengingat';

  /// Ikon kecil monokrom (siluet logo) & ikon besar berwarna (logo) — dibuat
  /// `tool/buat_ikon_notifikasi.dart`, ada di `android/app/src/main/res`.
  static const ikonKecil = 'ic_stat_sidik';
  static const ikonBesar = 'ic_notif_besar';
  static const _warnaAksen = Color(0xFF1D4292);

  static const _kanalKerja = AndroidNotificationChannel(
    kanalKerja,
    'Kabar kerja',
    description:
        'Lembar kerja masuk, sesi disetujui atau perlu revisi, dan sertifikat terbit.',
    importance: Importance.high,
  );
  static const _kanalPengingat = AndroidNotificationChannel(
    kanalPengingat,
    'Pengingat jatuh tempo',
    description: 'Alat yang mendekati atau melewati jatuh tempo kalibrasi.',
    importance: Importance.defaultImportance,
  );

  @override
  Future<bool> siapkan() async {
    if (_siap) return true;

    const android = AndroidInitializationSettings(ikonKecil);
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
      // Ketukan di bilah notifikasi mendarat di sini. Muatannya `tipe:id`,
      // bukan id notifikasinya — biar layarnya kebuka tanpa perlu narik
      // daftar notifikasi dulu, yang belum tentu sempat waktu aplikasinya
      // baru bangun.
      onDidReceiveNotificationResponse: (respons) =>
          bukaTautanDariLuar(bacaTautan(respons.payload)),
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        macOS: apple,
        windows: windows,
      ),
    );

    _siap = ok ?? false;
    if (_siap) {
      // Kanal dibuat eksplisit (bukan lazy saat `show`) supaya kanal push FCM
      // juga sudah ada dan muncul di setelan Android sebelum notifikasi pertama.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_kanalKerja);
      await android?.createNotificationChannel(_kanalPengingat);
      await _mintaIzin();
    }
    return _siap;
  }

  Future<void> _mintaIzin() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      // Android 12 ke bawah & izin yang sudah diberikan: tidak ada yang perlu
      // ditanyakan, dan tidak ada penjelasan yang perlu ditampilkan.
      if (await android.areNotificationsEnabled() ?? false) return;
      if (mintaIzin != null && !await mintaIzin!()) return;
      await android.requestNotificationsPermission();
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

    final pengingat = item.kategori == NotifKategori.jatuhTempo;

    await _plugin.show(
      id: _idAngka(item.id),
      title: item.judul,
      body: item.isi,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          pengingat ? kanalPengingat : kanalKerja,
          pengingat ? _kanalPengingat.name : _kanalKerja.name,
          channelDescription: pengingat
              ? _kanalPengingat.description
              : _kanalKerja.description,
          importance: pengingat
              ? Importance.defaultImportance
              : Importance.high,
          priority: pengingat ? Priority.defaultPriority : Priority.high,
          icon: ikonKecil,
          color: _warnaAksen,
          largeIcon: const DrawableResourceAndroidBitmap(ikonBesar),
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        windows: const WindowsNotificationDetails(),
      ),
      // Dibawa balik waktu notifikasinya diketuk — dipakai buat mbuka layar
      // yang bersangkutan, bukan cuma mbuka app di halaman depan.
      payload: sandiTautan(item.tautan),
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
