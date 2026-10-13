class Habito {
  Habito({
    required this.id,
    required this.nombre,
    required this.meta,
    required this.unidad,
    this.progreso = 0,
  });

  final int id;
  String nombre;
  int meta;
  String unidad;
  int progreso;

  bool get completado => progreso >= meta;
  double get porcentaje => meta <= 0 ? 0 : (progreso / meta).clamp(0, 1);
}
