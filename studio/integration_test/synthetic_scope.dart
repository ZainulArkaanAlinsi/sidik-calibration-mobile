import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as paths;

/// Test-only oracle supplied by the isolated PHP seed, never by a UI mock.
class SyntheticManifest {
  SyntheticManifest(Map<String, dynamic> json, {required String expectedRunId})
    : json = Map.unmodifiable(json) {
    if (json['schema_version'] != 1 ||
        json['run_id'] != expectedRunId ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$').hasMatch(expectedRunId)) {
      throw const FormatException('Synthetic manifest schema/run-id mismatch.');
    }
    for (final key in ['api_sha', 'mobile_sha']) {
      if (json[key] is! String ||
          !RegExp(r'^[0-9a-f]{40}$').hasMatch(json[key] as String)) {
        throw const FormatException(
          'Synthetic manifest requires full Git SHAs.',
        );
      }
    }
    endpoint = SyntheticEndpoint(json['api_base_url'] as String);
    if (!_positive(json['organization_id']) ||
        json['user_email'] is! String ||
        !(json['user_email'] as String).endsWith('.test') ||
        json['baseline'] is! Map<String, dynamic>) {
      throw const FormatException('Synthetic identity/baseline is missing.');
    }
    final workbook = json['workbook'] as Map<String, dynamic>;
    if (!_positive(workbook['id']) ||
        workbook['name'] != 'E2E_SYNTHETIC_$expectedRunId') {
      throw const FormatException('Synthetic workbook identity mismatch.');
    }
    sheets = (workbook['sheets'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
    if (sheets.length != 2 ||
        sheets.map((s) => s['name']).toSet().difference({
          'INPUT_SYNTHETIC',
          'DISPLAY_SYNTHETIC',
        }).isNotEmpty ||
        sheets.map((s) => s['name']).toSet().length != 2 ||
        sheets.map((s) => s['id']).toSet().length != 2) {
      throw const FormatException(
        'Synthetic fixture requires two distinct sheets.',
      );
    }
    var formulas = 0;
    for (final sheet in sheets) {
      if (!_positive(sheet['id']) || sheet['expected_cells'] is! List) {
        throw const FormatException('Synthetic sheet cells are missing.');
      }
      final cells = sheet['expected_cells'] as List;
      final addresses = <String>{};
      for (final value in cells) {
        final cell = value as Map;
        final address = cell['address'];
        if (address is! String ||
            !RegExp(r'^[A-Z]+[1-9][0-9]*$').hasMatch(address) ||
            !addresses.add(address) ||
            cell['text'] is! String) {
          throw const FormatException('Synthetic cell oracle is invalid.');
        }
        if (cell.containsKey('formula')) {
          if (cell['formula'] is! String ||
              !(cell['formula'] as String).startsWith('=')) {
            throw const FormatException('Synthetic formula oracle is invalid.');
          }
          formulas++;
        }
      }
      if (!addresses.containsAll(['A1', 'B2'])) {
        throw const FormatException(
          'Synthetic fixture must include A1 and B2.',
        );
      }
    }
    if (formulas == 0) {
      throw const FormatException('A stored formula oracle is required.');
    }
  }

  final Map<String, dynamic> json;
  late final SyntheticEndpoint endpoint;
  late final List<Map<String, dynamic>> sheets;
  String get runId => json['run_id'] as String;
  String get email => json['user_email'] as String;
  int get organizationId => json['organization_id'] as int;
  Map<String, dynamic> get workbook => json['workbook'] as Map<String, dynamic>;
  int get workbookId => workbook['id'] as int;

  void checkMarker(Map<String, dynamic> marker, String manifestSha256) {
    for (final key in ['schema_version', 'run_id', 'api_sha', 'mobile_sha']) {
      if (marker[key] != json[key]) {
        throw const FormatException('Synthetic server identity mismatch.');
      }
    }
    if (marker['app_env'] != 'testing' ||
        marker['db_driver'] != 'sqlite' ||
        marker['manifest_sha256'] != manifestSha256) {
      throw const FormatException(
        'Synthetic server environment/hash mismatch.',
      );
    }
  }

  static bool _positive(Object? value) => value is int && value > 0;
}

class SyntheticEndpoint {
  SyntheticEndpoint(String base) : base = Uri.parse(base) {
    if (this.base.scheme != 'http' ||
        this.base.host != '127.0.0.1' ||
        !this.base.hasPort ||
        this.base.port < 1024 ||
        this.base.port > 65535 ||
        [8000, 8010].contains(this.base.port) ||
        this.base.userInfo.isNotEmpty ||
        this.base.hasQuery ||
        this.base.hasFragment ||
        this.base.path != '/api') {
      throw const FormatException('Only the isolated loopback API is allowed.');
    }
  }

  final Uri base;
  Uri get marker => base.replace(path: '/__sidik_e2e');

  void check(Uri request) {
    if (request.scheme != base.scheme ||
        request.host != base.host ||
        request.port != base.port ||
        request.userInfo.isNotEmpty ||
        request.hasFragment) {
      // Do not include the rejected URI: it could contain userinfo/query data.
      throw const HttpException(
        'Synthetic transport rejected a non-owned target.',
      );
    }
  }
}

/// Every production http.Client() in the test zone is backed by real IO.
/// Failures are retained even if a production service catches its exception.
class SyntheticTransportAudit {
  SyntheticTransportAudit(this.endpoint);
  final SyntheticEndpoint endpoint;
  final List<String> requests = [];
  final List<String> failures = [];
  final Set<Completer<void>> _pending = {};
  final Set<http.Client> _clients = {};
  bool _sealed = false;

  int get pendingCount => _pending.length;

  Completer<void> begin() {
    if (_sealed) {
      failures.add('Synthetic request started after transport was sealed.');
      throw StateError('Synthetic transport is sealed.');
    }
    final pending = Completer<void>();
    _pending.add(pending);
    return pending;
  }

  void finish(Completer<void> pending) {
    if (_pending.remove(pending)) pending.complete();
  }

  Future<void> drain({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await (() async {
        while (_pending.isNotEmpty) {
          await Future.wait(_pending.map((item) => item.future).toList());
        }
      })().timeout(timeout);
    } on TimeoutException {
      failures.add('Synthetic response bodies did not finish before deadline.');
      rethrow;
    }
  }

  void sealAndClose() {
    _sealed = true;
    if (_pending.isNotEmpty) {
      failures.add('Synthetic transport closed with unfinished responses.');
    }
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }

  http.Client createClient() {
    if (_sealed) {
      failures.add('Synthetic client created after transport was sealed.');
      throw StateError('Synthetic transport is sealed.');
    }
    final native = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..findProxy = (_) => 'DIRECT';
    final client = SyntheticLoopbackClient(
      endpoint,
      IOClient(native),
      audit: this,
    );
    _clients.add(client);
    return client;
  }
}

class SyntheticLoopbackClient extends http.BaseClient {
  SyntheticLoopbackClient(this.endpoint, this.inner, {this.audit});
  final SyntheticEndpoint endpoint;
  final http.Client inner;
  final SyntheticTransportAudit? audit;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pending = audit?.begin();
    void finish() {
      if (pending != null) audit!.finish(pending);
    }

    try {
      endpoint.check(request.url);
      request.followRedirects = false;
      request.maxRedirects = 0;
      audit?.requests.add('${request.method} ${request.url.path}');
      final response = await inner.send(request);
      if (response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException(
          'Synthetic HTTP rejected status ${response.statusCode}.',
        );
      }
      // Headers are not completion: errors may arrive while reading the body.
      late StreamSubscription<List<int>> subscription;
      var completed = false;
      late StreamController<List<int>> controller;
      controller = StreamController<List<int>>(
        sync: true,
        onListen: () {
          subscription = response.stream.listen(
            controller.add,
            onError: (Object error, StackTrace stack) {
              audit?.failures.add('Synthetic response body failed.');
              controller.addError(error, stack);
            },
            onDone: () {
              completed = true;
              finish();
              controller.close();
            },
          );
        },
        onPause: () => subscription.pause(),
        onResume: () => subscription.resume(),
        onCancel: () async {
          if (!completed) {
            audit?.failures.add('Synthetic response body was cancelled.');
          }
          try {
            await subscription.cancel();
          } catch (_) {
            audit?.failures.add('Synthetic response cancellation failed.');
            rethrow;
          } finally {
            finish();
          }
        },
      );
      return http.StreamedResponse(
        controller.stream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      audit?.failures.add('Synthetic transport/request failed.');
      finish();
      rethrow;
    }
  }

  @override
  void close() => inner.close();
}

class SyntheticScope {
  SyntheticScope._(this.manifest, this.file, this.bytes, this.screenshots);
  final SyntheticManifest manifest;
  final File file;
  final Uint8List bytes;
  final Directory screenshots;
  String get hash => sha256.convert(bytes).toString();

  static SyntheticScope load() {
    const manifestPath = String.fromEnvironment('E2E_MANIFEST');
    const runId = String.fromEnvironment('E2E_RUN_ID');
    const output = String.fromEnvironment('E2E_POTRET');
    const api = String.fromEnvironment('API_BASE_URL');
    if (!Platform.isWindows || manifestPath.isEmpty || output.isEmpty) {
      throw const FormatException(
        'A Windows synthetic run manifest is required.',
      );
    }
    final file = File(manifestPath);
    final root = file.parent.absolute;
    final owner = Directory('C:/Users/USER/sidik-e2e-sintetis').absolute.path;
    if (!paths.isAbsolute(manifestPath) ||
        !paths.equals(paths.dirname(root.path), owner) ||
        paths.basename(root.path) != runId ||
        paths.basename(file.path) != 'manifest.json') {
      throw const FormatException(
        'Manifest is outside its owned synthetic run.',
      );
    }
    _checkPath(root.path, manifestPath);
    _checkPath(root.path, output);
    final bytes = file.readAsBytesSync();
    final manifest = SyntheticManifest(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      expectedRunId: runId,
    );
    if (manifest.endpoint.base.toString() != api) {
      throw const FormatException('Build API and manifest API disagree.');
    }
    final scope = SyntheticScope._(manifest, file, bytes, Directory(output));
    scope.checkOwnedPath(manifestPath);
    scope.checkOwnedPath(output);
    final database = manifest.json['database_path'];
    if (database is! String ||
        !paths.equals(
          database,
          paths.join(root.path, 'studio-synthetic.sqlite'),
        )) {
      throw const FormatException(
        'Manifest database is not the owned SQLite file.',
      );
    }
    scope.checkOwnedPath(database);
    return scope;
  }

  void checkOwnedPath(String candidate) {
    _checkPath(file.parent.absolute.path, candidate);
  }

  static void _checkPath(String root, String candidate) {
    final normalized = paths.normalize(candidate);
    if (!paths.isAbsolute(candidate) ||
        (!paths.equals(root, normalized) &&
            !paths.isWithin(root, normalized))) {
      throw const FormatException(
        'Synthetic artifact path leaves the owned run.',
      );
    }
    var current = normalized;
    while (true) {
      final type = FileSystemEntity.typeSync(current, followLinks: false);
      if (type == FileSystemEntityType.link ||
          (type != FileSystemEntityType.notFound &&
              !paths.equals(
                File(current).resolveSymbolicLinksSync(),
                current,
              ))) {
        throw const FormatException('Reparse/symbolic paths are not allowed.');
      }
      final parent = paths.dirname(current);
      if (parent == current) break;
      current = parent;
    }
  }

  void checkUnchanged() {
    if (sha256.convert(file.readAsBytesSync()).toString() != hash) {
      throw const FormatException(
        'Synthetic manifest changed during the smoke.',
      );
    }
  }
}
