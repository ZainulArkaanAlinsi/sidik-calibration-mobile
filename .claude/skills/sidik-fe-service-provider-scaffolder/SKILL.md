---
name: sidik-fe-service-provider-scaffolder
description: Generate pasangan service (ApiXxxService/MockXxxService) + provider Riverpod baru buat endpoint baru di sidik-calibration-mobile, ikutin pola tiga-lapis (interface, Api impl, Mock impl) dan AsyncNotifier/FutureProvider. Pakai saat user minta konsumsi endpoint API baru dari mobile.
---

# Sidik FE Service & Provider Scaffolder

Rekan `sidik-api-scaffolder` di backend, arah sebaliknya: bukan bikin
endpoint, tapi mengonsumsinya di Flutter. Pola tiga-lapis di proyek ini
KETAT — service baru yang nyimpang bikin dua sumber kebenaran mock vs API.

## Pola Wajib (lihat `equipment_service.dart` + `equipment_provider.dart`)

### 1. Service — abstract class + dua implementasi
```dart
abstract class XxxService {
  Future<Xxx> aksi(String token, ...);
}

class ApiXxxService implements XxxService {
  ApiXxxService(this._api);
  final ApiClient _api;
  // panggil _api.get/post/put/patch/delete, decode via Model.fromJson
}

class MockXxxService implements XxxService {
  MockXxxService({this.gagal = false});
  final bool gagal;
  // data statis in-memory, throw Exception kalau gagal==true
}
```
- Method SELALU terima `String token` sebagai parameter pertama (bukan baca
  dari provider di dalam service) — token dioper dari layer provider yang
  udah baca `tokenStorageProvider`.
- Response yang dibungkus `data` di-unwrap: `(json['data'] ?? json) as
  Map<String, dynamic>`, cocok kontrak di `docs/kontrak-api.md` §0.
- Upload file pakai `_api.unggahFile`/`_api.unggahBanyak`, BUKAN bikin
  `MultipartRequest` sendiri — dua method itu udah nangani timeout & error
  yang sesuai.

### 2. Provider — pilih Api/Mock via AppConfig, state via AsyncNotifier
```dart
final xxxServiceProvider = Provider<XxxService>((ref) {
  if (AppConfig.useMock) return MockXxxService();
  return ApiXxxService(ref.watch(apiClientProvider));
});
```
- List berpaginasi → `AsyncNotifierProvider` dengan `_page`/`_lastPage` +
  `bisaMuatLagi` + `muatLebihBanyak()` yang APPEND (bukan replace) biar
  scroll position gak keloncat.
- Data ringkas non-paginasi (dropdown, lookup) → `FutureProvider` biasa atau
  `FutureProvider.family` kalau perlu di-key parameter (lihat
  `deviceOverviewProvider` — sengaja TERPISAH dari provider tab utama biar
  filter satu layar gak bocor ke layar lain).
- Token hilang → `throw const TokenHilangException()` (dari
  `dashboard_provider.dart`), jangan return null diam-diam.

## Checklist Sebelum Dianggap Selesai
- [ ] Endpoint & bentuk JSON dicek ke `docs/kontrak-api.md` — kalau belum
      ada di situ, itu tandanya backend belum expose, cek `[[sidik-fe-kontrak-sync]]`
      dulu sebelum ngoding.
- [ ] `MockXxxService` diisi data contoh yang REALISTIS (nama alat, satuan,
      dst — bukan `"test123"`), karena dipakai juga buat `AppConfig.useMock`
      demo mode, bukan cuma test.
- [ ] Error dari backend (422/403/404) dibiarkan lewat apa adanya
      (`AuthException`/`ApiException`) — jangan ditangkap-generic-kan di
      provider, layar yang nampilin pesannya.

## Guidelines
- Jangan bikin service manggil `http` langsung — semua lewat `ApiClient`.
- Jangan simpan token di provider/service sebagai field — selalu baca ulang
  dari `tokenStorageProvider` tiap aksi (token bisa dicabut kapan saja).
