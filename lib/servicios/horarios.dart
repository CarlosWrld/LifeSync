/// Acepta horas anteriores en formato de 24 horas o con AM/PM.
int? minutosDeHora(String texto) {
  final limpio = texto.toUpperCase().replaceAll(RegExp(r'[\s.]'), '');
  final match = RegExp(r'^(\d{1,2}):(\d{2})(AM|PM)?$').firstMatch(limpio);
  if (match == null) return null;
  var hora = int.parse(match[1]!);
  final minuto = int.parse(match[2]!);
  final periodo = match[3];
  if (minuto > 59) return null;
  if (periodo != null) {
    if (hora < 1 || hora > 12) return null;
    hora = hora % 12 + (periodo == 'PM' ? 12 : 0);
  } else if (hora > 23) {
    return null;
  }
  return hora * 60 + minuto;
}

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
