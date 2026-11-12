import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';


const String devPspWebhookSecret = 'picpac-mock-insecure-dev-webhook-secret';

const Duration webhookTimestampTolerance = Duration(minutes: 5);

const int lookupMaxFailures = 5;

const int claimMaxFailures = 3;

const int loginMaxFailures = 5;

const int challengeMaxAttempts = 5;

const Duration failureWindow = Duration(minutes: 15);

const Duration failureBaseLock = Duration(minutes: 15);

const Duration failureMaxLock = Duration(hours: 24);

abstract final class MockEnv {
  static bool get customerAdvance =>
      (const String.fromEnvironment(
        'MOCK_CUSTOMER_ADVANCE',
        defaultValue: '1',
      )) !=
      '0';

  static const String _defineWebhookSecret = String.fromEnvironment(
    'PSP_WEBHOOK_SECRET',
  );
  static const String _defineMockControls = String.fromEnvironment(
    'MOCK_CONTROLS',
    defaultValue: '1',
  );
  static const String _defineAllowAnonymous = String.fromEnvironment(
    'MOCK_ALLOW_ANONYMOUS',
    defaultValue: '0',
  );
  static const String _defineAgentBaseUrl = String.fromEnvironment(
    'AGENT_BASE_URL',
  );
  static const String _defineAgentModel = String.fromEnvironment('AGENT_MODEL');
  static const String _defineAgentApiKey = String.fromEnvironment(
    'AGENT_API_KEY',
  );

  static String? get webhookSecret =>
      _string('PSP_WEBHOOK_SECRET', _defineWebhookSecret);

  static bool get mockControls =>
      _flag('MOCK_CONTROLS', _defineMockControls, fallback: true);

  static bool get allowAnonymousMockControls =>
      _flag('MOCK_ALLOW_ANONYMOUS', _defineAllowAnonymous, fallback: false);

  static String? get agentBaseUrl =>
      _string('AGENT_BASE_URL', _defineAgentBaseUrl);

  static String? get agentModel => _string('AGENT_MODEL', _defineAgentModel);

  static String? get agentApiKey =>
      _string('AGENT_API_KEY', _defineAgentApiKey);

  static String? _string(String name, String defineValue) {
    final fromProcess = Platform.environment[name]?.trim();
    if (fromProcess != null && fromProcess.isNotEmpty) return fromProcess;
    final trimmed = defineValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _flag(String name, String defineValue, {required bool fallback}) {
    final raw = _string(name, defineValue)?.toLowerCase();
    return switch (raw) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }
}

String pspWebhookSignature({
  required String secret,
  required String timestamp,
  required List<int> body,
}) {
  final mac = Hmac(sha256, utf8.encode(secret));
  return mac.convert(<int>[...utf8.encode('$timestamp\n'), ...body]).toString();
}

bool isPspSignatureShape(String value) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool constantTimeEquals(String a, String b) {
  final left = utf8.encode(a);
  final right = utf8.encode(b);
  final length = left.length > right.length ? left.length : right.length;
  var diff = left.length ^ right.length;
  for (var i = 0; i < length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    diff |= x ^ y;
  }
  return diff == 0;
}


const int pbkdf2Iterations = 100000;

const int pbkdf2KeyLength = 32;

const int pbkdf2SaltLength = 16;

const String pbkdf2Prefix = r'pbkdf2$';

String pbkdf2Hash(
  String password, {
  int iterations = pbkdf2Iterations,
  List<int>? salt,
  Random? random,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'must be positive');
  }
  final effectiveSalt = salt ?? _randomSalt(random ?? Random.secure());
  final derived = _pbkdf2(
    utf8.encode(password),
    effectiveSalt,
    iterations,
    pbkdf2KeyLength,
  );
  return '$pbkdf2Prefix$iterations\$'
      '${base64.encode(effectiveSalt)}\$${base64.encode(derived)}';
}

final String dummyPasswordHash = pbkdf2Hash(
  'picpac-dummy-password',
  salt: List<int>.filled(pbkdf2SaltLength, 0x42),
);

bool pbkdf2Verify(String password, String encoded) {
  final parts = encoded.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  final List<int> salt;
  final List<int> expected;
  try {
    salt = base64.decode(parts[2]);
    expected = base64.decode(parts[3]);
  } on FormatException {
    return false;
  }
  if (salt.isEmpty || expected.isEmpty) return false;
  final actual = _pbkdf2(
    utf8.encode(password),
    salt,
    iterations,
    expected.length,
  );
  return _bytesEqual(actual, expected);
}

List<int> _pbkdf2(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  final prf = Hmac(sha256, password);
  const blockSize = 32;
  final blocks = (keyLength + blockSize - 1) ~/ blockSize;
  final output = <int>[];
  for (var block = 1; block <= blocks; block++) {
    var u = prf.convert(<int>[
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ]).bytes;
    final accumulator = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = prf.convert(u).bytes;
      for (var j = 0; j < accumulator.length; j++) {
        accumulator[j] ^= u[j];
      }
    }
    output.addAll(accumulator);
  }
  return output.sublist(0, keyLength);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

List<int> _randomSalt(Random random) =>
    List<int>.generate(pbkdf2SaltLength, (_) => random.nextInt(256));
