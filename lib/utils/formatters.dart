import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat('#,###', 'es_PY');

  static String format(num amount) {
    return '${_formatter.format(amount).replaceAll(',', '.')} ₲';
  }

  static double parse(String value) {
    String clean = value.replaceAll('.', '').replaceAll('₲', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
