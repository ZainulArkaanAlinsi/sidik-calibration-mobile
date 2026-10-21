import 'package:flutter/widgets.dart';

/// Pengamat rute navigator akar (`MaterialApp.navigatorObservers`).
///
/// Dipakai `PemasangOtomatis` untuk tahu kapan shell KEMBALI jadi layar
/// teratas (`RouteAware.didPopNext`) — pop-up pembaruan yang dilewati karena
/// teknisi sedang di layar lain dicoba lagi saat itu, bukan hilang sampai
/// aplikasi ditutup.
final pengamatRute = RouteObserver<ModalRoute<void>>();
