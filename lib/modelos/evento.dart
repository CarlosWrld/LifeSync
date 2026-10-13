class Evento {
  Evento({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.hora,
    this.completado = false,
  });

  final int id;
  String titulo;
  DateTime fecha;
  String hora;
  bool completado;
}
