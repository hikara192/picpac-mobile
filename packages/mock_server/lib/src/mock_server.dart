import 'dart:convert';
import 'dart:math';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'ai/agent_provider.dart';
import 'clock.dart';
import 'errors.dart';
import 'pricing.dart';
import 'records.dart';
import 'seeds.dart';
import 'security.dart';

final class MockServer {
  MockServer({
    Clock? clock,
    Seeds? seeds,
    String? seedPath,
    this.logSink,
    String? webhookSecret,
    bool? mockControls,
    bool? allowAnonymousMockControls,
    AgentConfig? agentConfig,
  }) : clock = clock ?? const SystemClock(),
       seeds = seeds ?? Seeds.load(seedPath: seedPath),
       webhookSecret = _resolveWebhookSecret(webhookSecret),
       mockControlsEnabled = mockControls ?? MockEnv.mockControls,
       allowAnonymousMockControls =
           allowAnonymousMockControls ?? MockEnv.allowAnonymousMockControls,
       agentConfig = agentConfig ?? AgentConfig.fromEnv() {
    _tokenSecret = _randomSecret();
    _uuid = const Uuid();
    if (webhookSecretIsDev) {
      log(
        'security: insecure dev secret in use — set PSP_WEBHOOK_SECRET to '
        'sign PSP webhooks',
      );
    }
    reset();
  }

  final String webhookSecret;

  late final bool webhookSecretIsDev = webhookSecret == devPspWebhookSecret;

  final bool mockControlsEnabled;

  final bool allowAnonymousMockControls;

  final AgentConfig agentConfig;

  static String _resolveWebhookSecret(String? override) {
    final configured = override ?? MockEnv.webhookSecret;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return devPspWebhookSecret;
  }

  final Clock clock;

  final Seeds seeds;

  late final Pricing pricing = Pricing(seeds);

  late final String _tokenSecret;
  late final Uuid _uuid;

  final void Function(String line)? logSink;

  final Map<String, CustomerRecord> customers = <String, CustomerRecord>{};

  final Map<String, CustomerRecord> registeredAccounts =
      <String, CustomerRecord>{};

  final Map<String, String> registeredHashes = <String, String>{};

  final Map<String, SessionRecord> sessions = <String, SessionRecord>{};

  final Map<String, ChallengeRecord> challenges = <String, ChallengeRecord>{};

  final Map<String, DesignRecord> designs = <String, DesignRecord>{};

  final Map<String, CartRecord> carts = <String, CartRecord>{};

  final Map<String, OrderRecord> orders = <String, OrderRecord>{};

  final Map<String, IntentRecord> intents = <String, IntentRecord>{};

  final Map<String, RefundRecord> refunds = <String, RefundRecord>{};

  final Map<String, ReceiptRecord> receipts = <String, ReceiptRecord>{};

  final Map<String, UploadRecord> uploads = <String, UploadRecord>{};

  final Map<String, TicketRecord> tickets = <String, TicketRecord>{};

  final Map<String, Set<String>> favoriteIdsByCustomer =
      <String, Set<String>>{};

  final Set<String> webhookReplayKeys = <String>{};

  final List<AuditRecordEntry> _audit = <AuditRecordEntry>[];
  final Map<String, IdempotencyRecord> _idempotency =
      <String, IdempotencyRecord>{};
  final Map<String, int> _faults = <String, int>{};
  final Map<String, List<DateTime>> _rateBuckets = <String, List<DateTime>>{};
  final Map<String, _FailureState> _failures = <String, _FailureState>{};
  final Map<String, int> _challengeAttempts = <String, int>{};
  final Set<String> _burnedChallenges = <String>{};
  final Map<String, int> _counters = <String, int>{};

  String get seededAt => seeds.seededAt;

  List<AuditRecordEntry> get auditLog =>
      List<AuditRecordEntry>.unmodifiable(_audit);

  int get auditLength => _audit.length;

  AuditRecordEntry auditAt(int index) => _audit[index];

  void replaceAudit(int index, AuditRecordEntry entry) => _audit[index] = entry;

  void forgetIdempotency(String customerId) =>
      _idempotency.removeWhere((_, record) => record.customerId == customerId);

  Set<String> favoritesOf(String customerId) =>
      favoriteIdsByCustomer.putIfAbsent(customerId, () => <String>{});

  void forgetFavorites(String customerId) =>
      favoriteIdsByCustomer.remove(customerId);

  void log(String line) => logSink?.call(line);

  void reset() {
    customers.clear();
    sessions.clear();
    challenges.clear();
    designs.clear();
    carts.clear();
    orders.clear();
    intents.clear();
    refunds.clear();
    receipts.clear();
    uploads.clear();
    tickets.clear();
    favoriteIdsByCustomer.clear();
    webhookReplayKeys.clear();
    _audit.clear();
    _idempotency.clear();
    _faults.clear();
    _rateBuckets.clear();
    _failures.clear();
    _challengeAttempts.clear();
    _burnedChallenges.clear();
    _counters.clear();

    final now = clock.now();
    for (final account in seeds.accounts.accounts) {
      customers[account.id] = CustomerRecord(
        id: account.id,
        createdAt: now,
        role: account.role,
        isGuest: account.isGuest,
        name: account.name,
        email: account.email,
        phoneMasked: account.phoneMasked,
      );
    }
    for (final challenge in seeds.accounts.challenges) {
      challenges[challenge.id] = ChallengeRecord(
        id: challenge.id,
        accountId: challenge.accountId,
        code: challenge.code,
        expiresAt: now.add(Duration(minutes: challenge.ttlMinutes)),
      );
    }
  }

  String nextId(String prefix) {
    final next = (_counters[prefix] ?? 0) + 1;
    _counters[prefix] = next;
    return '${prefix}_${next.toString().padLeft(4, '0')}';
  }

  String nextOrderNumber() {
    final next = (_counters['order_number'] ?? 1000) + 1;
    _counters['order_number'] = next;
    return 'PP-$next';
  }

  String newRequestId() => _uuid.v4();

  CustomerRecord? customerById(String id) => customers[id];

  CustomerRecord createGuest() {
    final now = clock.now();
    final customer = CustomerRecord(
      id: nextId('cus'),
      createdAt: now,
      role: UserRole.guest,
      isGuest: true,
    );
    customers[customer.id] = customer;
    return customer;
  }

  ({SessionRecord session, String token}) issueSession(
    CustomerRecord customer,
  ) {
    final now = clock.now();
    final session = SessionRecord(
      id: nextId('ses'),
      customerId: customer.id,
      role: customer.role,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    sessions[session.id] = session;
    final payload = <String, Object?>{
      'sid': session.id,
      'exp': session.expiresAt.millisecondsSinceEpoch ~/ 1000,
    };
    final encoded = _base64Url(jsonEncode(payload));
    final signature = _sign(encoded);
    return (session: session, token: 'mck.$encoded.$signature');
  }

  SessionRecord authenticate(String token) {
    final parts = token.split('.');
    if (parts.length != 3 || parts[0] != 'mck') {
      throw ApiException.unauthorized('malformed access token');
    }
    final encoded = parts[1];
    if (!_constantTimeEquals(_sign(encoded), parts[2])) {
      throw ApiException.unauthorized('invalid access token signature');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(_base64UrlDecode(encoded)));
    } on FormatException {
      throw ApiException.unauthorized('malformed access token payload');
    }
    if (decoded is! Map<String, Object?> || decoded['sid'] is! String) {
      throw ApiException.unauthorized('malformed access token payload');
    }
    final session = sessions[decoded['sid']];
    if (session == null || session.revoked) {
      throw ApiException.unauthorized('the session is no longer valid');
    }
    if (session.isExpiredAt(clock.now())) {
      session.revoked = true;
      throw ApiException.unauthorized('the session has expired');
    }
    return session;
  }

  CartRecord cartFor(String customerId) {
    final now = clock.now();
    final existing = carts[customerId];
    if (existing != null) {
      if (!existing.isExpiredAt(now)) return existing;
      _auditCartExpiry(existing);
      carts.remove(customerId);
    }
    final cart = CartRecord(
      id: nextId('cart'),
      customerId: customerId,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    );
    carts[customerId] = cart;
    return cart;
  }

  void _auditCartExpiry(CartRecord cart) {
    _audit.add(
      AuditRecordEntry(
        id: nextId('aud'),
        at: clock.now(),
        action: 'cart.expire',
        objectType: 'cart',
        objectId: cart.id,
        result: 'success',
        actorRole: ActorRole.system,
        details: <String, Object?>{'lines': cart.lines.length},
      ),
    );
  }

  void audit({
    required String action,
    required String objectType,
    required String objectId,
    required String result,
    ActorRole actorRole = ActorRole.system,
    String? actorId,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _audit.add(
      AuditRecordEntry(
        id: nextId('aud'),
        at: clock.now(),
        action: action,
        objectType: objectType,
        objectId: objectId,
        result: result,
        actorRole: actorRole,
        actorId: actorId,
        details: details,
      ),
    );
  }

  static ActorRole actorRoleOf(SessionRecord? session) =>
      switch (session?.role) {
        UserRole.supportAgent => ActorRole.supportAgent,
        UserRole.customer || UserRole.guest => ActorRole.customer,
        _ => ActorRole.system,
      };

  void armFault(String mode) {
    _faults[mode] = (_faults[mode] ?? 0) + 1;
  }

  bool consumeFault(String mode) {
    final count = _faults[mode] ?? 0;
    if (count <= 0) return false;
    if (count == 1) {
      _faults.remove(mode);
    } else {
      _faults[mode] = count - 1;
    }
    return true;
  }

  void clearFaults() => _faults.clear();

  bool checkRateLimit(
    String bucket, {
    int max = 5,
    Duration window = const Duration(minutes: 1),
  }) {
    final now = clock.now();
    final attempts = _rateBuckets.putIfAbsent(bucket, () => <DateTime>[]);
    attempts.removeWhere((at) => now.difference(at) >= window);
    if (attempts.length >= max) return false;
    attempts.add(now);
    return true;
  }

  int retryAfterSeconds(
    String bucket, {
    Duration window = const Duration(minutes: 1),
  }) {
    final attempts = _rateBuckets[bucket];
    if (attempts == null || attempts.isEmpty) return window.inSeconds;
    final oldest = attempts.first;
    final remaining = window - clock.now().difference(oldest);
    return remaining.isNegative ? 0 : remaining.inSeconds + 1;
  }

  Duration? lockRemaining(String bucket) {
    final until = _failures[bucket]?.lockedUntil;
    if (until == null) return null;
    final now = clock.now();
    if (!until.isAfter(now)) return null;
    return until.difference(now);
  }

  void recordFailure(
    String bucket, {
    required int maxAttempts,
    Duration window = failureWindow,
    Duration baseLock = failureBaseLock,
    Duration maxLock = failureMaxLock,
  }) {
    final now = clock.now();
    if (_failures.length > 512) _pruneFailures(now, window);
    final state = _failures.putIfAbsent(bucket, _FailureState.new);
    state.attempts.removeWhere((at) => now.difference(at) >= window);
    state.attempts.add(now);
    if (state.attempts.length < maxAttempts) return;
    state.attempts.clear();
    state.blocks += 1;
    final shift = (state.blocks - 1).clamp(0, 20).toInt();
    final lock = baseLock * (1 << shift);
    state.lockedUntil = now.add(lock > maxLock ? maxLock : lock);
  }

  void _pruneFailures(DateTime now, Duration window) {
    _failures.removeWhere((_, state) {
      final locked = state.lockedUntil;
      if (locked != null && locked.isAfter(now)) return false;
      state.attempts.removeWhere((at) => now.difference(at) >= window);
      return state.attempts.isEmpty;
    });
  }

  bool isLocked(String bucket) => lockRemaining(bucket) != null;

  void clearFailures(String bucket) => _failures.remove(bucket);

  bool challengeBurned(String challengeId) =>
      _burnedChallenges.contains(challengeId);

  bool recordChallengeFailure(String challengeId) {
    final attempts = (_challengeAttempts[challengeId] ?? 0) + 1;
    _challengeAttempts[challengeId] = attempts;
    if (attempts < challengeMaxAttempts) return false;
    burnChallenge(challengeId);
    return true;
  }

  void burnChallenge(String challengeId) {
    _burnedChallenges.add(challengeId);
    challenges.remove(challengeId);
    _challengeAttempts.remove(challengeId);
  }

  static String webhookReplayKey(String provider, String eventId) =>
      '$provider|$eventId';

  bool webhookSeen(String provider, String eventId) =>
      webhookReplayKeys.contains(webhookReplayKey(provider, eventId));

  void rememberWebhook(String provider, String eventId) =>
      webhookReplayKeys.add(webhookReplayKey(provider, eventId));

  IdempotencyRecord? idempotency(
    String endpoint,
    String customerId,
    String key,
  ) => _idempotency['$endpoint|$customerId|$key'];

  void rememberIdempotency(IdempotencyRecord record) {
    _idempotency['${record.endpoint}|${record.customerId}|${record.key}'] =
        record;
  }

  static String bodyHash(String body) =>
      sha256.convert(utf8.encode(body)).toString();

  String signOpaque(String value) => _base64UrlBytes(
    Hmac(sha256, utf8.encode(_tokenSecret)).convert(utf8.encode(value)).bytes,
  );

  bool verifyOpaque(String value, String? token) =>
      token != null && _constantTimeEquals(signOpaque(value), token);

  static String anonymizedActorId(String customerId) {
    final digest = sha256.convert(utf8.encode(customerId)).toString();
    return 'deleted:${digest.substring(0, 12)}';
  }

  String _sign(String encodedPayload) => _base64UrlBytes(
    Hmac(
      sha256,
      utf8.encode(_tokenSecret),
    ).convert(utf8.encode(encodedPayload)).bytes,
  );

  String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _base64Url(String value) =>
      base64UrlEncode(utf8.encode(value)).replaceAll('=', '');

  static String _base64UrlBytes(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  static List<int> _base64UrlDecode(String value) =>
      base64Url.decode(base64Url.normalize(value));

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

final class _FailureState {
  final List<DateTime> attempts = <DateTime>[];

  DateTime? lockedUntil;

  int blocks = 0;
}

final class ChallengeRecord {
  const ChallengeRecord({
    required this.id,
    required this.accountId,
    required this.code,
    required this.expiresAt,
  });

  final String id;

  final String accountId;

  final String code;

  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}
