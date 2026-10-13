class Festivo {
  const Festivo({required this.fecha, required this.nombre});
  final DateTime fecha;
  final String nombre;

  factory Festivo.fromJson(Map<String, dynamic> json) {
    final texto = json['date'];
    final nombre = json['localName'];
    if (texto is! String ||
        nombre is! String ||
        nombre.trim().isEmpty ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) {
      throw const FormatException('Festivo inválido');
    }
    final fecha = DateTime.parse(texto);
    if (fecha.toIso8601String().substring(0, 10) != texto) {
      throw const FormatException('Fecha inválida');
    }
    return Festivo(fecha: fecha, nombre: nombre.trim());
  }
}
