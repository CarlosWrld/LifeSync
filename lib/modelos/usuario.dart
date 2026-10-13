import 'dart:typed_data';

class Usuario {
  // Mantiene cada perfil por debajo del límite de lectura de SQLite en Android.
  static const maxFotoBytes = 1024 * 1024;

  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final String proveedor;
  final Uint8List? foto;

  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    this.rol = 'usuario',
    this.proveedor = 'correo',
    this.foto,
  });

  bool get esAdmin => rol == 'admin';

  factory Usuario.fromMap(Map<String, Object?> row) => Usuario(
    id: row['id'] as int,
    nombre: row['nombre'] as String,
    correo: row['correo'] as String,
    rol: row['rol'] as String,
    proveedor: row['proveedor'] as String,
    foto: row['foto'] as Uint8List?,
  );
}
