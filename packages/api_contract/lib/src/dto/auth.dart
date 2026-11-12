import '../json.dart';

enum UserRole {
  customer('customer'),

  supportAgent('support_agent'),

  guest('guest'),

  unknown('unknown');

  const UserRole(this.wire);

  final String wire;

  static UserRole fromWire(String? raw) {
    for (final role in values) {
      if (role != UserRole.unknown && role.wire == raw) return role;
    }
    return UserRole.unknown;
  }
}

final class Customer with ValueJson {
  const Customer({
    required this.id,
    required this.createdAt,
    this.name,
    this.email,
    this.phoneMasked,
    this.isGuest = false,
  });

  final String id;

  final DateTime createdAt;

  final String? name;

  final String? email;

  final String? phoneMasked;

  final bool isGuest;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (name != null) 'name': name,
    if (email != null) 'email': email,
    if (phoneMasked != null) 'phoneMasked': phoneMasked,
    'isGuest': isGuest,
  };

  factory Customer.fromJson(JsonMap json, [String path = r'$']) => Customer(
    id: J.readId(json['id'], '$path.id'),
    createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
    name: J.readIdOrNull(json['name'], '$path.name'),
    email: J.readIdOrNull(json['email'], '$path.email'),
    phoneMasked: J.readIdOrNull(json['phoneMasked'], '$path.phoneMasked'),
    isGuest: J.readBoolOr(json['isGuest'], '$path.isGuest', fallback: false),
  );
}

final class AuthSession with ValueJson {
  const AuthSession({
    required this.token,
    required this.role,
    this.refreshToken,
    this.customerId,
    this.expiresAt,
    this.customer,
  });

  final String token;

  final String? refreshToken;

  final UserRole role;

  final String? customerId;

  final DateTime? expiresAt;

  final Customer? customer;

  bool get isGuest => role == UserRole.guest;

  bool get isSupportAgent => role == UserRole.supportAgent;

  bool isExpiredAt(DateTime now) {
    final at = expiresAt;
    return at != null && !at.isAfter(now.toUtc());
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'role': role.wire,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (customerId != null) 'customerId': customerId,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (customer != null) 'customer': customer!.toJson(),
  };

  factory AuthSession.fromJson(JsonMap json, [String path = r'$']) {
    final customerJson = json['customer'];
    return AuthSession(
      token: J.readId(json['token'], '$path.token'),
      refreshToken: J.readIdOrNull(json['refreshToken'], '$path.refreshToken'),
      role: J.readEnum<UserRole>(
        json['role'],
        '$path.role',
        values: UserRole.values,
        wire: (role) => role.wire,
        fallback: UserRole.unknown,
      ),
      customerId: J.readIdOrNull(json['customerId'], '$path.customerId'),
      expiresAt: J.readDateOrNull(json['expiresAt'], '$path.expiresAt'),
      customer: customerJson == null
          ? null
          : Customer.fromJson(J.readObject(customerJson, '$path.customer')),
    );
  }
}

final class AnonymousSessionRequest with ValueJson {
  const AnonymousSessionRequest({required this.locale, this.deviceId});

  final String locale;

  final String? deviceId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'locale': locale,
    if (deviceId != null) 'deviceId': deviceId,
  };

  factory AnonymousSessionRequest.fromJson(
    JsonMap json, [
    String path = r'$',
  ]) => AnonymousSessionRequest(
    locale: J.readId(json['locale'], '$path.locale'),
    deviceId: J.readIdOrNull(json['deviceId'], '$path.deviceId'),
  );
}

final class LoginRequest with ValueJson {
  const LoginRequest({
    required this.email,
    required this.password,
    this.locale,
  });

  final String email;

  final String password;

  final String? locale;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'password': password,
    if (locale != null) 'locale': locale,
  };

  factory LoginRequest.fromJson(JsonMap json, [String path = r'$']) =>
      LoginRequest(
        email: J.readId(json['email'], '$path.email'),
        password: J.readId(json['password'], '$path.password'),
        locale: J.readIdOrNull(json['locale'], '$path.locale'),
      );
}


final class RegisterRequest with ValueJson {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    this.locale,
  });

  final String name;
  final String email;
  final String password;
  final String? locale;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'email': email,
    'password': password,
    if (locale != null) 'locale': locale,
  };
}
