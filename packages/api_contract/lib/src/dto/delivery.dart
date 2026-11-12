import '../json.dart';
import '../money.dart';

enum DeliveryKind {
  pickup('pickup'),

  post('post'),

  ems('ems'),

  courier('courier'),

  unknown('unknown');

  const DeliveryKind(this.wire);

  final String wire;

  static DeliveryKind fromWire(String? raw) {
    for (final kind in values) {
      if (kind != DeliveryKind.unknown && kind.wire == raw) return kind;
    }
    return DeliveryKind.unknown;
  }
}

final class DeliveryOption with ValueJson {
  const DeliveryOption({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.price,
    this.freeFrom,
    this.etaDays = 0,
    this.requiresPoint = false,
    this.allowsCashOnDelivery = false,
  });

  final String id;

  final DeliveryKind kind;

  final String titleKey;

  final Money price;

  final Money? freeFrom;

  final int etaDays;

  final bool requiresPoint;

  final bool allowsCashOnDelivery;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.wire,
    'titleKey': titleKey,
    'price': price.toJson(),
    if (freeFrom != null) 'freeFrom': freeFrom!.toJson(),
    'etaDays': etaDays,
    'requiresPoint': requiresPoint,
    'allowsCashOnDelivery': allowsCashOnDelivery,
  };

  factory DeliveryOption.fromJson(JsonMap json, [String path = r'$']) {
    final freeFrom = json['freeFrom'];
    return DeliveryOption(
      id: J.readId(json['id'], '$path.id'),
      kind: J.readEnum<DeliveryKind>(
        json['kind'],
        '$path.kind',
        values: DeliveryKind.values,
        wire: (kind) => kind.wire,
        fallback: DeliveryKind.unknown,
      ),
      titleKey: J.readId(json['titleKey'], '$path.titleKey'),
      price: J.readMoney(json['price'], '$path.price'),
      freeFrom: freeFrom == null
          ? null
          : J.readMoney(freeFrom, '$path.freeFrom'),
      etaDays: J.readIntOrNull(json['etaDays'], '$path.etaDays') ?? 0,
      requiresPoint: J.readBoolOr(
        json['requiresPoint'],
        '$path.requiresPoint',
        fallback: false,
      ),
      allowsCashOnDelivery: J.readBoolOr(
        json['allowsCashOnDelivery'],
        '$path.allowsCashOnDelivery',
        fallback: false,
      ),
    );
  }
}

final class PickupSlot with ValueJson {
  const PickupSlot({
    required this.start,
    required this.end,
    this.available = true,
  });

  final DateTime start;

  final DateTime end;

  final bool available;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'available': available,
  };

  factory PickupSlot.fromJson(JsonMap json, [String path = r'$']) => PickupSlot(
    start: J.readDate(json['start'], '$path.start'),
    end: J.readDate(json['end'], '$path.end'),
    available: J.readBoolOr(
      json['available'],
      '$path.available',
      fallback: true,
    ),
  );
}

final class PickupPoint with ValueJson {
  const PickupPoint({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
    this.lat,
    this.lng,
    this.slots = const <PickupSlot>[],
  });

  final String id;

  final String title;

  final String address;

  final String city;

  final double? lat;

  final double? lng;

  final List<PickupSlot> slots;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'address': address,
    'city': city,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
  };

  factory PickupPoint.fromJson(JsonMap json, [String path = r'$']) {
    final slotsJson = json['slots'] == null
        ? const <Object?>[]
        : J.readList(json['slots'], '$path.slots');
    return PickupPoint(
      id: J.readId(json['id'], '$path.id'),
      title: J.readString(json['title'], '$path.title'),
      address: J.readString(json['address'], '$path.address'),
      city: J.readString(json['city'], '$path.city'),
      lat: J.readDoubleOrNull(json['lat'], '$path.lat'),
      lng: J.readDoubleOrNull(json['lng'], '$path.lng'),
      slots: <PickupSlot>[
        for (var i = 0; i < slotsJson.length; i++)
          PickupSlot.fromJson(
            J.readObject(slotsJson[i], '$path.slots[$i]'),
            '$path.slots[$i]',
          ),
      ],
    );
  }
}

final class DeliverySelection with ValueJson {
  const DeliverySelection({
    required this.kind,
    this.optionId,
    this.pointId,
    this.slot,
    this.address,
  });

  final DeliveryKind kind;

  final String? optionId;

  final String? pointId;

  final DateTime? slot;

  final String? address;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    if (optionId != null) 'optionId': optionId,
    if (pointId != null) 'pointId': pointId,
    if (slot != null) 'slot': slot!.toUtc().toIso8601String(),
    if (address != null) 'address': address,
  };

  factory DeliverySelection.fromJson(JsonMap json, [String path = r'$']) =>
      DeliverySelection(
        kind: J.readEnum<DeliveryKind>(
          json['kind'],
          '$path.kind',
          values: DeliveryKind.values,
          wire: (kind) => kind.wire,
          fallback: DeliveryKind.unknown,
        ),
        optionId: J.readIdOrNull(json['optionId'], '$path.optionId'),
        pointId: J.readIdOrNull(json['pointId'], '$path.pointId'),
        slot: J.readDateOrNull(json['slot'], '$path.slot'),
        address: J.readStringOrNull(json['address'], '$path.address'),
      );
}
