import 'package:api_contract/api_contract.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../money_format.dart';

final class Fmt {
  Fmt(this.locale);

  final String locale;

  late final MoneyFormatter _moneyFormatter = MoneyFormatter(locale: locale);

  static Fmt of(BuildContext context) =>
      Fmt(Localizations.localeOf(context).languageCode);

  String money(Money amount) => _moneyFormatter.format(amount);

  String dateTime(DateTime value) =>
      DateFormat('d MMM, HH:mm', locale).format(value.toLocal());

  String date(DateTime value) =>
      DateFormat('d MMMM yyyy', locale).format(value.toLocal());

  String shortDate(DateTime value) =>
      DateFormat('d MMM', locale).format(value.toLocal());

  String slot(DateTime start, DateTime end) {
    final head = DateFormat('d MMM, HH:mm', locale);
    final tail = DateFormat('HH:mm', locale);
    return '${head.format(start.toLocal())}'
        '–${tail.format(end.toLocal())}';
  }

  static String millimetres(double value, {String locale = 'ru'}) =>
      NumberFormat(
        value == value.roundToDouble() ? '0' : '0.#',
        locale,
      ).format(value);
}
