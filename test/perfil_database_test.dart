import 'dart:io';
import 'dart:typed_data';

import 'package:appmovil/modelos/usuario.dart';
import 'package:appmovil/servicios/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temp;
  late DatabaseHelper db;
  final foto = Uint8List.fromList([137, 80, 78, 71]);

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('perfil_test_');
    db = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      join(temp.path, 'test.db'),
    );
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test(
    'Nombre y foto persisten al reabrir sin cambiar identidad ni tareas',
    () async {
      final usuario = await db.registrar(
        nombre: 'Ana',
        correo: 'ana@example.com',
        password: 'clave1234',
      );
      await db.guardar('tareas', {'titulo': 'Conservar', 'hora': '10:00'});
      final antes = (await (await db.database).query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuario.id],
      )).single;
      final actualizado = await db.actualizarPerfil(
        usuarioId: usuario.id,
        nombre: '  Ana López  ',
        foto: foto,
      );
      expect(actualizado.nombre, 'Ana López');
      expect(db.usuarioActual, same(actualizado));
      await db.close();
      final recuperado = await db.iniciarSesion('ana@example.com', 'clave1234');
      expect(recuperado?.id, usuario.id);
      expect(recuperado?.nombre, 'Ana López');
      expect(recuperado?.foto, orderedEquals(foto));
      expect((await db.obtener('tareas')).single['titulo'], 'Conservar');
      final despues = (await (await db.database).query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuario.id],
      )).single;
      for (final campo in [
        'correo',
        'password',
        'rol',
        'proveedor',
        'google_id',
      ]) {
        expect(despues[campo], antes[campo]);
      }
      await db.actualizarPerfil(
        usuarioId: usuario.id,
        nombre: 'Ana López',
        foto: null,
      );
      await db.close();
      expect(
        (await db.iniciarSesion('ana@example.com', 'clave1234'))?.foto,
        isNull,
      );
    },
  );

  test('Google conserva el perfil editado y separa las cuentas', () async {
    final ana = await db.guardarSesionGoogle(
      googleId: 'ana',
      correo: 'ana@gmail.com',
      nombre: 'Ana',
    );
    await db.actualizarPerfil(
      usuarioId: ana.id,
      nombre: 'Mi nombre',
      foto: foto,
    );
    final luis = await db.guardarSesionGoogle(
      googleId: 'luis',
      correo: 'luis@gmail.com',
      nombre: 'Luis',
    );
    expect(luis.foto, isNull);
    await expectLater(
      db.actualizarPerfil(usuarioId: ana.id, nombre: 'Otro', foto: null),
      throwsA(isA<AccesoDenegadoException>()),
    );
    final deNuevo = await db.guardarSesionGoogle(
      googleId: 'ana',
      correo: 'ana@gmail.com',
      nombre: 'Nombre de Google',
    );
    expect(deNuevo.nombre, 'Mi nombre');
    expect(deNuevo.foto, orderedEquals(foto));
    db.cerrarSesion();
    await expectLater(
      db.actualizarPerfil(usuarioId: ana.id, nombre: 'Sin sesión', foto: null),
      throwsA(isA<AccesoDenegadoException>()),
    );
  });

  test(
    'Rechaza nombres vacíos y fotos demasiado grandes sin cambiar el perfil',
    () async {
      final usuario = await db.guardarSesionGoogle(
        googleId: 'ana',
        correo: 'ana@gmail.com',
        nombre: 'Ana',
      );
      for (final nombre in ['  ', 'a' * 81]) {
        await expectLater(
          db.actualizarPerfil(
            usuarioId: usuario.id,
            nombre: nombre,
            foto: null,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        db.actualizarPerfil(
          usuarioId: usuario.id,
          nombre: 'Cambio',
          foto: Uint8List(Usuario.maxFotoBytes + 1),
        ),
        throwsArgumentError,
      );
      expect(db.usuarioActual?.nombre, 'Ana');
      expect(
        (await (await db.database).query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [usuario.id],
        )).single['nombre'],
        'Ana',
      );
    },
  );

  test('Migra v4 conservando perfil, rol y tareas existentes', () async {
    final admin = await db.iniciarSesion('cp448570@gmail.com', 'cobito1234');
    await db.guardar('tareas', {'titulo': 'Conservar', 'hora': '10:00'});
    final raw = await db.database;
    await raw.update(
      'usuarios',
      {'nombre': 'Nombre anterior'},
      where: 'id = ?',
      whereArgs: [admin!.id],
    );
    await raw.execute('ALTER TABLE usuarios DROP COLUMN foto');
    await raw.execute('PRAGMA user_version = 4');
    await db.close();
    final migrado = await db.iniciarSesion('cp448570@gmail.com', 'cobito1234');
    expect(migrado?.id, admin.id);
    expect(migrado?.esAdmin, isTrue);
    expect(migrado?.nombre, 'Nombre anterior');
    expect(migrado?.foto, isNull);
    expect(await db.obtener('tareas'), hasLength(1));
    await db.actualizarPerfil(
      usuarioId: admin.id,
      nombre: 'Nuevo nombre',
      foto: foto,
    );
    expect(db.usuarioActual?.foto, orderedEquals(foto));
    expect(await (await db.database).getVersion(), 5);
  });
}
