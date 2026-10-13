class Tarea {
  Tarea({
    required this.id,
    required this.titulo,
    required this.hora,
    this.completada = false,
  });

  final int id;
  String titulo;
  String hora;
  bool completada;
}
