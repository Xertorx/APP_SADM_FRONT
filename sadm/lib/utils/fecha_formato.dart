import 'package:intl/intl.dart';

/// Formats a date in Spanish using the user's local time zone.
/// Requires `initializeDateFormatting('es')` to have run at startup.
String formatearFechaHora(DateTime fecha) {
  return DateFormat("d 'de' MMMM 'de' yyyy, HH:mm", 'es').format(fecha.toLocal());
}
