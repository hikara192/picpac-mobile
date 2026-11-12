import 'dart:async';
import 'dart:io';

import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Command-line entry point of the PicPac mock API.
///
///   dart run packages/mock_server/bin/server.dart [--port 8080]
///        [--host 127.0.0.1] [--seed packages/mock_server/seeds] [--quiet]
///
/// Prints the address, the seed snapshot date and the demo credentials, serves
/// `GET /health`, and shuts down gracefully on SIGINT/SIGTERM.
Future<void> main(List<String> arguments) async {
  final options = _parse(arguments);
  if (options.help) {
    _printUsage();
    return;
  }

  final server = MockServer(
    seedPath: options.seedPath,
    logSink: options.quiet ? null : (line) => stdout.writeln('[mock] $line'),
  );
  final httpServer = await _startMockServer(server, options);

  final address = httpServer.address.address;
  final port = httpServer.port;
  stdout
    ..writeln('PicPac mock API is listening on http://$address:$port')
    ..writeln('Health:  http://$address:$port/health')
    ..writeln('Seed:    ${server.seededAt} (${server.seeds.catalog.source})')
    ..writeln('Accounts: customer@picpac.test / Test1234 (customer)')
    ..writeln('          support@picpac.test / Test1234 (support_agent)')
    ..writeln('Promo:    TEST10 (-10 %), PIC100 (100 %, order paid at once)')
    ..writeln('Uploads:  JPEG/PNG only, <= 25 MiB; HEIC is rejected');

  var closing = false;
  Future<void> shutdown(ProcessSignal signal) async {
    if (closing) return;
    closing = true;
    stdout.writeln('\n${signal.name}: shutting down the mock API…');
    await httpServer.close(force: true);
    exit(0);
  }

  final subscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen(shutdown),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown),
  ];

  // The process stays alive until a signal closes the socket.
  await Completer<void>().future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
}

/// Starts a server from an already built [MockServer] (used by the CLI so the
/// banner can read the seed metadata and the CLI owns the lifecycle).
Future<HttpServer> _startMockServer(MockServer server, _Options options) =>
    shelf_io.serve(
      createHandler(server),
      options.host == null
          ? InternetAddress.loopbackIPv4
          : InternetAddress(options.host!),
      options.port,
    );

final class _Options {
  const _Options({
    required this.port,
    required this.host,
    required this.seedPath,
    required this.quiet,
    required this.help,
  });

  final int port;
  final String? host;
  final String? seedPath;
  final bool quiet;
  final bool help;
}

_Options _parse(List<String> arguments) {
  var port = 8080;
  String? host;
  String? seedPath;
  var quiet = false;
  var help = false;

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    String? valueFor(String name) {
      final inline = argument.split('=');
      if (inline.length == 2) return inline[1];
      if (i + 1 >= arguments.length) {
        stderr.writeln('missing value for $name');
        exit(64);
      }
      return arguments[++i];
    }

    if (argument == '--help' || argument == '-h') {
      help = true;
    } else if (argument == '--quiet' || argument == '-q') {
      quiet = true;
    } else if (argument.startsWith('--port')) {
      port = int.tryParse(valueFor('--port') ?? '') ?? 0;
      if (port < 1 || port > 65535) {
        stderr.writeln('--port must be within 1..65535');
        exit(64);
      }
    } else if (argument.startsWith('--host')) {
      host = valueFor('--host');
    } else if (argument.startsWith('--seed')) {
      seedPath = valueFor('--seed');
    } else {
      stderr.writeln('unknown argument: $argument');
      _printUsage();
      exit(64);
    }
  }

  return _Options(
    port: port,
    host: host,
    seedPath: seedPath,
    quiet: quiet,
    help: help,
  );
}

void _printUsage() {
  stdout
    ..writeln('PicPac stateful mock API')
    ..writeln()
    ..writeln('Usage: dart run bin/server.dart [options]')
    ..writeln()
    ..writeln('  --port <n>     port to listen on (default 8080)')
    ..writeln('  --host <ip>    interface to bind (default 127.0.0.1)')
    ..writeln('  --seed <path>  seed directory or bundle file')
    ..writeln('  --quiet        do not log requests')
    ..writeln('  -h, --help     show this help');
}
