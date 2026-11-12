import 'package:api_contract/api_contract.dart';

import 'errors.dart';
import 'mock_server.dart';
import 'records.dart';
import 'seeds.dart';


Map<String, Object?> authSessionJson({
  required SessionRecord session,
  required CustomerRecord customer,
  required String token,
}) => AuthSession(
  token: token,
  role: session.role,
  customerId: customer.id,
  expiresAt: session.expiresAt,
  customer: customer.toDto(),
).toJson();

Cart cartToDto(MockServer server, CartRecord cart) {
  final currency = server.seeds.catalog.currency;
  final items = <CartItem>[];
  var subtotal = 0;
  var canCheckout = cart.lines.isNotEmpty;
  for (final line in cart.lines) {
    final design = server.designs[line.designId];
    if (design == null) {
      canCheckout = false;
      continue;
    }
    final product = server.seeds.catalog.productById(
      design.document.product.id,
    );
    final format = product?.formatById(design.document.product.formatId);
    if (product == null || format == null) {
      canCheckout = false;
      continue;
    }
    try {
      final quote = server.pricing.quote(
        product: product,
        format: format,
        options: design.document.product.options,
        units: product.isPrints ? line.quantity : _spreadsOf(design),
        copies: product.isPrints ? 1 : line.quantity,
        promoCode: cart.promoCode,
      );
      subtotal += quote.totalMinor;
      items.add(
        CartItem(
          id: line.id,
          designId: line.designId,
          quantity: line.quantity,
          quote: quote.toDto(),
        ),
      );
    } on ApiException {
      canCheckout = false;
    }
  }
  return Cart(
    id: cart.id,
    items: items,
    expiresAt: cart.expiresAt,
    subtotal: Money(
      amountMinor: subtotal < 0 ? 0 : subtotal,
      currency: currency,
    ),
    promoCode: cart.promoCode,
    canCheckout: canCheckout && items.isNotEmpty,
  );
}

int pricingUnitsOf(SeedProduct product, DesignDocument document, int quantity) {
  if (product.isPrints) return quantity < 1 ? 1 : quantity;
  return document.spreadsCount < 1 ? 1 : document.spreadsCount;
}

int pricingCopiesOf(SeedProduct product, int quantity) =>
    product.isPrints ? 1 : (quantity < 1 ? 1 : quantity);

int _spreadsOf(DesignRecord design) =>
    design.document.spreadsCount < 1 ? 1 : design.document.spreadsCount;

List<PickupPoint> pickupPointsToDto(Seeds seeds, DateTime now) {
  final schedule = seeds.delivery.schedule;
  final offset = Duration(hours: schedule.utcOffsetHours);
  final localNow = now.add(offset);
  final todayLocal = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final slots = <PickupSlot>[];
  for (var day = 0; day < schedule.daysAhead; day++) {
    final date = todayLocal.add(Duration(days: day));
    if (schedule.closedWeekdays.contains(date.weekday)) continue;
    for (final hour in schedule.slotStartHoursLocal) {
      final start = date.add(Duration(hours: hour)).subtract(offset);
      final end = start.add(Duration(hours: schedule.slotDurationHours));
      slots.add(
        PickupSlot(start: start, end: end, available: start.isAfter(now)),
      );
    }
  }
  return <PickupPoint>[
    for (final point in seeds.delivery.pickupPoints)
      PickupPoint(
        id: point.id,
        title: point.title,
        address: point.address,
        city: point.city,
        slots: slots,
      ),
  ];
}

int? parseRevisionHeader(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.startsWith('W/')) value = value.substring(2);
  value = value.replaceAll('"', '').trim();
  if (value.isEmpty || value == '*') return null;
  return int.tryParse(value);
}

String designEtag(int revision) => '"$revision"';

String maskedLast4(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final last4 = digits.length >= 4
      ? digits.substring(digits.length - 4)
      : digits.padLeft(4, '*');
  return '***$last4';
}
