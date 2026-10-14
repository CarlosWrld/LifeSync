import 'dart:io';
import 'dart:typed_data';

import 'package:appmovil/servicios/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temp;
  late DatabaseHelper db;
  late String path;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lifesync_sesion_');
    path = join(temp.path, 'lifesync.db');
    db = DatabaseHelper.forTesting(databaseFactoryFfi, path);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> reiniciar() async {
    await db.close();
    db = DatabaseHelper.forTesting(databaseFactoryFfi, path);
    expect(db.usuarioActual, isNull);
  }

  test('Una instalación nueva no inicia sesión en la cuenta preexistente', () async {
    expect(await db.restaurarSesion(), isNull);
    expect(await (await db.database).query('usuarios'), isNotEmpty);
  });

  test('Registro y acceso local recuerdan la cuenta al reiniciar', () async {
    final usuario = await db.registrar(
      nombre: 'Ana', correo: 'ana@example.com', password: 'clave1234',
    );
    await db.guardar('tareas', {'titulo': 'Mi tarea', 'hora': '10:00'});
    await reiniciar();
    expect((await db.restaurarSesion())?.id, usuario.id);
    expect((await db.obtener('tareas')).single['titulo'], 'Mi tarea');

    await db.cerrarSesion();
    await reiniciar();
    expect(await db.restaurarSesion(), isNull);
    await db.iniciarSesion('ana@example.com', 'clave1234');
    await reiniciar();
    expect((await db.restaurarSesion())?.id, usuario.id);
    expect(await db.obtener('tareas'), hasLength(1));
  });

  test('Google restaura el perfil actualizado y solo los datos de esa cuenta', () async {
    await db.guardarSesionGoogle(googleId: 'otro', correo: 'otro@example.com', nombre: 'Otro');
    await db.guardar('tareas', {'titulo': 'Privada de otro', 'hora': '09:00'});
    final usuario = await db.guardarSesionGoogle(
      googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana',
    );
    final foto = Uint8List.fromList([1, 2, 3]);
    await db.actualizarPerfil(usuarioId: usuario.id, nombre: 'Ana nueva', foto: foto);
    await db.guardar('tareas', {'titulo': 'Propia', 'hora': '10:00'});
    await reiniciar();
    final restaurado = await db.restaurarSesion();
    expect(restaurado?.id, usuario.id);
    expect(restaurado?.nombre, 'Ana nueva');
    expect(restaurado?.proveedor, 'google');
    expect(restaurado?.foto, foto);
    expect(restaurado?.esAdmin, isFalse);
    expect((await db.obtener('tareas')).single['titulo'], 'Propia');

    await db.cerrarSesion();
    await reiniciar();
    expect(await db.restaurarSesion(), isNull);
    await expectLater(db.obtener('tareas'), throwsA(isA<AccesoDenegadoException>()));
    await db.guardarSesionGoogle(googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana');
    await reiniciar();
    expect((await db.restaurarSesion())?.nombre, 'Ana nueva');
    expect((await db.obtener('tareas')).single['titulo'], 'Propia');
  });

  test('Un acceso fallido no deja una sesión anterior guardada', () async {
    await db.guardarSesionGoogle(googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana');
    expect(await db.iniciarSesion('inexistente@example.com', 'incorrecta'), isNull);
    await reiniciar();
    expect(await db.restaurarSesion(), isNull);
  });

  test('Migrar v5 conserva los datos sin inventar una sesión', () async {
    final usuario = await db.guardarSesionGoogle(
      googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana',
    );
    await db.guardar('tareas', {'titulo': 'Conservar', 'hora': '10:00'});
    final raw = await db.database;
    await raw.execute('DROP TABLE sesion_activa');
    await raw.setVersion(5);
    await reiniciar();
    expect(await db.restaurarSesion(), isNull);
    expect(await (await db.database).getVersion(), 6);
    expect((await (await db.database).query('tareas')).single['usuario_id'], usuario.id);
    await db.guardarSesionGoogle(googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana');
    await reiniciar();
    expect((await db.restaurarSesion())?.id, usuario.id);
    expect((await db.obtener('tareas')).single['titulo'], 'Conservar');
  });

  test('Eliminar la cuenta invalida su sesión persistida', () async {
    final usuario = await db.guardarSesionGoogle(
      googleId: 'google-ana', correo: 'ana@example.com', nombre: 'Ana',
    );
    await (await db.database).delete('usuarios', where: 'id = ?', whereArgs: [usuario.id]);
    await reiniciar();
    expect(await db.restaurarSesion(), isNull);
  });
}
