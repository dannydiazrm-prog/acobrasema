import 'package:intl/intl.dart';

/// Utilidades de formato para guaraníes y fechas.
class CurrencyFormatter {
  static final _formatter = NumberFormat('#,###', 'es_PY');
  static final _dateFormatter = DateFormat('dd/MM/yyyy', 'es');
  static final _dateLongFormatter = DateFormat("d 'de' MMMM 'de' y", 'es');

  /// Formatea un número como guaraní: 150000 -> "150.000 ₲"
  static String format(num amount) {
    return '${_formatter.format(amount).replaceAll(',', '.')} ₲';
  }

  /// Formatea sin el símbolo: 150000 -> "150.000"
  static String formatNumber(num amount) {
    return _formatter.format(amount).replaceAll(',', '.');
  }

  /// Convierte texto del usuario a número: "150.000" -> 150000.0
  static double parse(String value) {
    final clean = value
        .replaceAll('.', '')
        .replaceAll('₲', '')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  /// Formatea en vivo mientras el usuario escribe.
  /// "1500" -> "1.500", "150000" -> "150.000"
  static String formatInput(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return '';
    final number = int.tryParse(clean);
    if (number == null) return '';
    return _formatter.format(number).replaceAll(',', '.');
  }

  /// Formatea una fecha corta: "10/10/2026"
  static String formatDate(DateTime date) => _dateFormatter.format(date);

  /// Formatea una fecha larga: "10 de octubre de 2026"
  static String formatDateLong(DateTime date) => _dateLongFormatter.format(date);

  /// Cuántos días pasaron desde una fecha.
  static int daysSince(DateTime date) {
    return DateTime.now().difference(date).inDays;
  }
}