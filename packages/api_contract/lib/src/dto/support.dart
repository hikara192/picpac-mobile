import '../json.dart';
import 'auth.dart';

enum TicketStatus {
  open('open'),

  pending('pending'),

  resolved('resolved'),

  closed('closed'),

  unknown('unknown');

  const TicketStatus(this.wire);

  final String wire;

  String get messageKey => 'ticket.status.$wire';

  bool get isOpen => this == TicketStatus.open || this == TicketStatus.pending;

  static TicketStatus fromWire(String? raw) {
    for (final status in values) {
      if (status != TicketStatus.unknown && status.wire == raw) return status;
    }
    return TicketStatus.unknown;
  }
}

enum TicketType {
  question('question'),

  defect('defect'),

  refund('refund'),

  delivery('delivery'),

  other('other'),

  unknown('unknown');

  const TicketType(this.wire);

  final String wire;

  String get messageKey => 'ticket.type.$wire';

  static TicketType fromWire(String? raw) {
    for (final type in values) {
      if (type != TicketType.unknown && type.wire == raw) return type;
    }
    return TicketType.unknown;
  }
}

final class TicketMessage with ValueJson {
  const TicketMessage({
    required this.id,
    required this.authorRole,
    required this.body,
    required this.createdAt,
    this.attachments = const <String>[],
  });

  final String id;

  final UserRole authorRole;

  final String body;

  final DateTime createdAt;

  final List<String> attachments;

  bool get isFromCustomer => authorRole == UserRole.customer;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'authorRole': authorRole.wire,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'attachments': attachments,
  };

  factory TicketMessage.fromJson(JsonMap json, [String path = r'$']) {
    final attachments = json['attachments'];
    return TicketMessage(
      id: J.readId(json['id'], '$path.id'),
      authorRole: J.readEnum<UserRole>(
        json['authorRole'],
        '$path.authorRole',
        values: UserRole.values,
        wire: (role) => role.wire,
        fallback: UserRole.unknown,
      ),
      body: J.readString(json['body'], '$path.body'),
      createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
      attachments: attachments == null
          ? const <String>[]
          : J.readStringList(attachments, '$path.attachments'),
    );
  }
}

final class SupportTicket with ValueJson {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.messages = const <TicketMessage>[],
    this.slaDueAt,
  });

  final String id;

  final String subject;

  final TicketType type;

  final TicketStatus status;

  final DateTime createdAt;

  final DateTime updatedAt;

  final String? orderId;

  final List<TicketMessage> messages;

  final DateTime? slaDueAt;

  bool get isOrderRelated => orderId != null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'subject': subject,
    'type': type.wire,
    'status': status.wire,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (orderId != null) 'orderId': orderId,
    'messages': <Object?>[for (final message in messages) message.toJson()],
    if (slaDueAt != null) 'slaDueAt': slaDueAt!.toUtc().toIso8601String(),
  };

  factory SupportTicket.fromJson(JsonMap json, [String path = r'$']) {
    final messagesJson = json['messages'] == null
        ? const <Object?>[]
        : J.readList(json['messages'], '$path.messages');
    return SupportTicket(
      id: J.readId(json['id'], '$path.id'),
      subject: J.readString(json['subject'], '$path.subject'),
      type: J.readEnum<TicketType>(
        json['type'],
        '$path.type',
        values: TicketType.values,
        wire: (type) => type.wire,
        fallback: TicketType.unknown,
      ),
      status: J.readEnum<TicketStatus>(
        json['status'],
        '$path.status',
        values: TicketStatus.values,
        wire: (status) => status.wire,
        fallback: TicketStatus.unknown,
      ),
      createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
      updatedAt: J.readDate(json['updatedAt'], '$path.updatedAt'),
      orderId: J.readIdOrNull(json['orderId'], '$path.orderId'),
      messages: <TicketMessage>[
        for (var i = 0; i < messagesJson.length; i++)
          TicketMessage.fromJson(
            J.readObject(messagesJson[i], '$path.messages[$i]'),
            '$path.messages[$i]',
          ),
      ],
      slaDueAt: J.readDateOrNull(json['slaDueAt'], '$path.slaDueAt'),
    );
  }
}

final class CreateTicketRequest with ValueJson {
  const CreateTicketRequest({
    required this.subject,
    required this.body,
    required this.type,
    this.orderId,
    this.attachments = const <String>[],
  });

  final String subject;

  final String body;

  final TicketType type;

  final String? orderId;

  final List<String> attachments;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'subject': subject,
    'body': body,
    'type': type.wire,
    if (orderId != null) 'orderId': orderId,
    'attachments': attachments,
  };

  factory CreateTicketRequest.fromJson(JsonMap json, [String path = r'$']) =>
      CreateTicketRequest(
        subject: J.readString(json['subject'], '$path.subject'),
        body: J.readString(json['body'], '$path.body'),
        type: J.readEnum<TicketType>(
          json['type'],
          '$path.type',
          values: TicketType.values,
          wire: (type) => type.wire,
          fallback: TicketType.unknown,
        ),
        orderId: J.readIdOrNull(json['orderId'], '$path.orderId'),
        attachments: json['attachments'] == null
            ? const <String>[]
            : J.readStringList(json['attachments'], '$path.attachments'),
      );
}

final class PostTicketMessageRequest with ValueJson {
  const PostTicketMessageRequest({
    required this.ticketId,
    required this.body,
    this.attachments = const <String>[],
  });

  final String ticketId;

  final String body;

  final List<String> attachments;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'ticketId': ticketId,
    'body': body,
    'attachments': attachments,
  };

  factory PostTicketMessageRequest.fromJson(
    JsonMap json, [
    String path = r'$',
  ]) => PostTicketMessageRequest(
    ticketId: J.readId(json['ticketId'], '$path.ticketId'),
    body: J.readString(json['body'], '$path.body'),
    attachments: json['attachments'] == null
        ? const <String>[]
        : J.readStringList(json['attachments'], '$path.attachments'),
  );
}
