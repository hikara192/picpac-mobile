import '../json.dart';

enum ActorRole {
  customer('customer'),

  supportAgent('support_agent'),

  system('system'),

  unknown('unknown');

  const ActorRole(this.wire);

  final String wire;

  static ActorRole fromWire(String? raw) {
    for (final role in values) {
      if (role != ActorRole.unknown && role.wire == raw) return role;
    }
    return ActorRole.unknown;
  }
}

final class AuditRecord with ValueJson {
  const AuditRecord({
    required this.id,
    required this.at,
    required this.action,
    required this.objectType,
    required this.objectId,
    required this.result,
    required this.actorRole,
    this.actorId,
    this.details = const <String, Object?>{},
  });

  final String id;

  final DateTime at;

  final String action;

  final String objectType;

  final String objectId;

  final String result;

  final ActorRole actorRole;

  final String? actorId;

  final Map<String, Object?> details;

  bool get isSuccess => result == 'success';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'action': action,
    'objectType': objectType,
    'objectId': objectId,
    'result': result,
    'actorRole': actorRole.wire,
    if (actorId != null) 'actorId': actorId,
    if (details.isNotEmpty) 'details': details,
  };

  factory AuditRecord.fromJson(JsonMap json, [String path = r'$']) {
    final details = json['details'];
    return AuditRecord(
      id: J.readId(json['id'], '$path.id'),
      at: J.readDate(json['at'], '$path.at'),
      action: J.readId(json['action'], '$path.action'),
      objectType: J.readId(json['objectType'], '$path.objectType'),
      objectId: J.readId(json['objectId'], '$path.objectId'),
      result: J.readId(json['result'], '$path.result'),
      actorRole: J.readEnum<ActorRole>(
        json['actorRole'],
        '$path.actorRole',
        values: ActorRole.values,
        wire: (role) => role.wire,
        fallback: ActorRole.unknown,
      ),
      actorId: J.readIdOrNull(json['actorId'], '$path.actorId'),
      details: details == null
          ? const <String, Object?>{}
          : J.readObject(details, '$path.details'),
    );
  }
}
