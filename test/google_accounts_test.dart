import 'dart:io';
import 'package:appmovil/servicios/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper db;
  setUpAll(sqfliteFfiInit);
  setUp(() {
    db = DatabaseHelper.forTesting(databaseFactoryFfi, inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('Google crea usuario normal y conserva ID y tareas al volver', () async {
    final first = await db.guardarSesionGoogle(
      googleId: 'google-123',
      correo: 'test@gmail.com',
      nombre: 'Prueba',
    );
    expect(first.esAdmin, isFalse);
    expect(first.proveedor, 'google');
    await db.guardar('tareas', {'titulo': 'Conservar', 'hora': '10:00'});
    db.cerrarSesion();
    expect(await db.iniciarSesion('test@gmail.com', ''), isNull);
    final second = await db.guardarSesionGoogle(
      googleId: 'google-123',
      correo: 'test@gmail.com',
      nombre: 'Prueba',
    );
    expect(second.id, first.id);
    expect(await db.obtener('tareas'), hasLength(1));
    await expectLater(
      db.obtenerUsuarios(),
      throwsA(isA<AccesoDenegadoException>()),
    );
  });

  test('No vincula por correo ni permite entrar al administrador', () async {
    final admin = (await (await db.database).query('usuarios')).single;
    await expectLater(
      db.guardarSesionGoogle(
        googleId: 'otro-id',
        correo: admin['correo'] as String,
        nombre: 'Otra persona',
      ),
      throwsA(isA<CorreoRegistradoException>()),
    );
    expect(db.usuarioActual, isNull);
    await db.registrar(
      nombre: 'Local',
      correo: 'local@gmail.com',
      password: 'clave1234',
    );
    await expectLater(
      db.guardarSesionGoogle(
        googleId: 'otro-id',
        correo: 'local@gmail.com',
        nombre: 'Otra persona',
      ),
      throwsA(isA<CorreoRegistradoException>()),
    );
    expect(db.usuarioActual, isNull);
  });

  test('Actualiza una base v3 real sin perder cuentas ni tareas', () async {
    final dir = await Directory.systemTemp.createTemp('google_migration_');
    final path = '${dir.path}/test.db';
    final legacy = DatabaseHelper.forTesting(databaseFactoryFfi, path);
    final local = await legacy.registrar(
      nombre: 'Local',
      correo: 'local@example.com',
      password: 'clave1234',
    );
    await legacy.guardar('tareas', {'titulo': 'Conservar', 'hora': '12:00'});
    final raw = await legacy.database;
    await raw.execute('DROP INDEX idx_usuarios_google');
    await raw.execute('ALTER TABLE usuarios DROP COLUMN google_id');
    await raw.execute('PRAGMA user_version = 3');
    await legacy.close();
    final migrated = DatabaseHelper.forTesting(databaseFactoryFfi, path);
    try {
      expect(
        (await migrated.iniciarSesion('local@example.com', 'clave1234'))?.id,
        local.id,
      );
      expect(await migrated.obtener('tareas'), hasLength(1));
      final google = await migrated.guardarSesionGoogle(
        googleId: 'nuevo-id',
        correo: 'nuevo@gmail.com',
        nombre: 'Nuevo',
      );
      expect(google.esAdmin, isFalse);
      expect(await migrated.obtener('tareas'), isEmpty);
    } finally {
      await migrated.close();
      await dir.delete(recursive: true);
    }
  });
}
