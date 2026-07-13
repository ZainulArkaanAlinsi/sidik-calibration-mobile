import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

/// Provider pertama di project ini — sekaligus bukti wiring Riverpod jalan.
/// Provider lain (auth, api client, dst) nyusul di minggu berikutnya.
final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

final appEnvProvider = Provider<AppEnv>((ref) => AppConfig.env);
