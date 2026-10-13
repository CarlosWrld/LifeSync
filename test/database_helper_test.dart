import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:appmovil/servicios/database_helper.dart';

void main() {
  late Directory temp;
  late DatabaseHelper helper;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lifesync_test_');
    helper = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      join(temp.path, 'lifesync.db'),
    );
  });
  tearDown(() async {
    await helper.close();
    await temp.delete(recursive: true);
  });

  for (final cuentaExistente in [false, true]) {
    test(
      'Migración v2 conserva datos (cuenta existente: $cuentaExistente)',
      () async {
        final db = await helper.database;
        final original = (await db.query('usuarios')).single;
        final id = original['id'] as int;
        await db.update(
          'usuarios',
          {
            'correo': cuentaExistente
                ? 'cp448570@gmail.com'
                : 'anterior@example.com',
            'nombre': 'Anterior',
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await db.insert('tareas', {
          'usuario_id': id,
          'titulo': 'Conservar',
          'hora': '10:00',
        });
        await db.execute('PRAGMA user_version = 2');
        await helper.close();
        final admin = await helper.iniciarSesion(
          'cp448570@gmail.com',
          'cobito1234',
        );
        expect(admin?.nombre, 'Carlos Pérez');
        expect(admin?.esAdmin, isTrue);
        if (cuentaExistente) expect(admin?.id, id);
        final usuarios = await helper.obtenerUsuarios();
        expect(usuarios.where((u) => u.esAdmin), hasLength(1));
        expect(usuarios, hasLength(cuentaExistente ? 1 : 2));
        expect(
          (await (await helper.database).query('tareas')).single['usuario_id'],
          id,
        );
        await helper.close();
        expect(
          (await helper.iniciarSesion('cp448570@gmail.com', 'cobito1234'))?.id,
          admin?.id,
        );
        expect(
          await helper.obtenerUsuarios(),
          hasLength(cuentaExistente ? 1 : 2),
        );
      },
    );
  }

  test(
    'Horarios únicos al crear y editar, separados por fecha y usuario',
    () async {
      await helper.registrar(
        nombre: 'Ana',
        correo: 'ana@example.com',
        password: 'clave1234',
      );
      for (final table in ['tareas', 'eventos']) {
        final datos = <String, Object?>{
          'titulo': 'Primero',
          'hora': '6:30 PM',
          if (table == 'eventos') 'fecha': '2026-09-23T10:00:00.000',
        };
        await helper.guardar(table, datos);
        final id = (await helper.obtener(table)).single['id'] as int;
        await helper.guardar(table, {...datos, 'hora': '18:30'}, id: id);
        await expectLater(
          helper.guardar(table, {...datos, 'hora': '18:30'}),
          throwsA(isA<HorarioOcupadoException>()),
        );
        await helper.guardar(table, {...datos, 'hora': '19:00'});
        final otro =
            (await helper.obtener(table)).firstWhere((r) => r['id'] != id)['id']
                as int;
        await expectLater(
          helper.guardar(table, {'hora': '18:30'}, id: otro),
          throwsA(isA<HorarioOcupadoException>()),
        );
        if (table == 'eventos') {
          await helper.guardar(table, {...datos, 'fecha': '2026-09-24'});
        }
      }
      await helper.registrar(
        nombre: 'Luis',
        correo: 'luis@example.com',
        password: 'clave1234',
      );
      await helper.guardar('tareas', {
        'titulo': 'Otro usuario',
        'hora': '18:30',
      });
      expect(await helper.obtener('tareas'), hasLength(1));
    },
  );

  test(
    'Registro, correo único, contraseñas y permisos administrativos',
    () async {
      final admin = await helper.registrar(
        nombre: 'Ana',
        correo: ' Ana@Example.com ',
        password: 'clave1234',
      );
      expect(admin.rol, 'usuario');
      expect(admin.correo, 'ana@example.com');
      expect(admin.proveedor, 'correo');
      final rows = await (await helper.database).query('usuarios');
      expect(
        rows.firstWhere((r) => r['id'] == admin.id)['password'],
        isNot('clave1234'),
      );
      await expectLater(
        helper.obtenerUsuarios(),
        throwsA(isA<AccesoDenegadoException>()),
      );
      final seeded = await helper.iniciarSesion(
        'cp448570@gmail.com',
        'cobito1234',
      );
      expect(seeded?.esAdmin, isTrue);
      expect(seeded?.nombre, 'Carlos P\u00e9rez');
      await expectLater(
        helper.registrar(
          nombre: 'Duplicada',
          correo: 'ANA@example.com',
          password: 'clave1234',
        ),
        throwsA(isA<CorreoRegistradoException>()),
      );
      expect((await helper.obtenerUsuarios()).length, 2);
      final user = await helper.registrar(
        nombre: 'Luis',
        correo: 'luis@example.com',
        password: 'otra1234',
      );
      expect(user.rol, 'usuario');
      await expectLater(
        helper.obtenerUsuarios(),
        throwsA(isA<AccesoDenegadoException>()),
      );
      expect(
        await helper.iniciarSesion('ana@example.com', 'incorrecta'),
        isNull,
      );
      await expectLater(
        helper.obtener('tareas'),
        throwsA(isA<AccesoDenegadoException>()),
      );
      expect(
        (await helper.iniciarSesion(' ANA@EXAMPLE.COM ', 'clave1234'))?.id,
        admin.id,
      );
      await expectLater(
        helper.obtenerUsuarios(),
        throwsA(isA<AccesoDenegadoException>()),
      );
      await helper.iniciarSesion('cp448570@gmail.com', 'cobito1234');
      expect((await helper.obtenerUsuarios()).length, 3);
    },
  );

  test(
    'CRUD de las tres tablas, aislamiento y persistencia al reabrir',
    () async {
      final user = await helper.registrar(
        nombre: 'Ana',
        correo: 'ana@example.com',
        password: 'clave1234',
      );
      final values = <String, Map<String, Object?>>{
        'tareas': {'titulo': 'Tarea', 'hora': '10:00'},
        'habitos': {'nombre': 'Agua', 'meta': 8, 'unidad': 'vasos'},
        'eventos': {
          'titulo': 'Clase',
          'fecha': '2026-09-22T00:00:00.000',
          'hora': '11:00',
        },
      };
      final ids = <String, int>{};
      for (final entry in values.entries) {
        await helper.guardar(entry.key, entry.value);
        ids[entry.key] = (await helper.obtener(entry.key)).single['id'] as int;
      }
      await helper.guardar('tareas', {
        'titulo': 'Editada',
        'completada': 1,
      }, id: ids['tareas']);
      await helper.guardar('habitos', {
        'nombre': 'Editado',
        'progreso': 8,
      }, id: ids['habitos']);
      await helper.guardar('eventos', {
        'titulo': 'Editado',
        'completado': 1,
      }, id: ids['eventos']);
      await helper.registrar(
        nombre: 'Luis',
        correo: 'luis@example.com',
        password: 'clave5678',
      );
      for (final entry in values.entries) {
        expect(await helper.obtener(entry.key), isEmpty);
        await expectLater(
          helper.guardar(entry.key, entry.value, id: ids[entry.key]),
          throwsA(isA<AccesoDenegadoException>()),
        );
        await expectLater(
          helper.eliminar(entry.key, ids[entry.key]!),
          throwsA(isA<AccesoDenegadoException>()),
        );
        await helper.guardar(entry.key, entry.value);
      }
      await helper.close();
      helper = DatabaseHelper.forTesting(
        databaseFactoryFfi,
        join(temp.path, 'lifesync.db'),
      );
      expect(
        (await helper.iniciarSesion('ana@example.com', 'clave1234'))?.id,
        user.id,
      );
      expect((await helper.obtener('tareas')).single['completada'], 1);
      expect((await helper.obtener('tareas')).single['titulo'], 'Editada');
      expect((await helper.obtener('habitos')).single['progreso'], 8);
      expect((await helper.obtener('eventos')).single['completado'], 1);
      for (final table in values.keys) {
        await helper.eliminar(table, ids[table]!);
        expect(await helper.obtener(table), isEmpty);
      }
      await helper.iniciarSesion('luis@example.com', 'clave5678');
      for (final table in values.keys) {
        expect((await helper.obtener(table)).length, 1);
      }
      final db = await helper.database;
      await expectLater(
        db.insert('tareas', {
          'usuario_id': 9999,
          'titulo': 'Inválida',
          'hora': '12:00',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('Migración v1 conserva datos, normaliza correo y protege contraseña', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      join(temp.path, 'lifesync.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE usuarios(id INTEGER PRIMARY KEY, nombre TEXT, correo TEXT UNIQUE, password TEXT, rol TEXT, proveedor TEXT)',
          );
          await db.execute(
            'CREATE TABLE tareas(id INTEGER PRIMARY KEY, usuario_id INTEGER, titulo TEXT, hora TEXT, completada INTEGER)',
          );
          await db.execute(
            'CREATE TABLE habitos(id INTEGER PRIMARY KEY, usuario_id INTEGER, nombre TEXT, meta INTEGER, unidad TEXT, progreso INTEGER)',
          );
          await db.execute(
            'CREATE TABLE eventos(id INTEGER PRIMARY KEY, usuario_id INTEGER, titulo TEXT, fecha TEXT, hora TEXT)',
          );
          await db.insert('usuarios', {
            'id': 7,
            'nombre': 'Anterior',
            'correo': 'Antigua@Example.com',
            'password': '1234',
            'rol': 'usuario',
            'proveedor': 'correo',
          });
          await db.insert('tareas', {
            'id': 9,
            'usuario_id': 7,
            'titulo': 'Conservar',
            'hora': '9:00',
            'completada': 1,
          });
          await db.insert('habitos', {
            'id': 4,
            'usuario_id': 7,
            'nombre': 'Caminar',
            'meta': 10,
            'unidad': 'min',
            'progreso': 3,
          });
          await db.insert('eventos', {
            'id': 2,
            'usuario_id': 7,
            'titulo': 'Reunión',
            'fecha': '2026-09-22',
            'hora': '10:00',
          });
        },
      ),
    );
    await legacy.close();
    final user = await helper.iniciarSesion('antigua@example.com', '1234');
    expect(user?.id, 7);
    expect(user?.esAdmin, isFalse);
    expect((await helper.obtener('tareas')).single['id'], 9);
    expect((await helper.obtener('habitos')).single['progreso'], 3);
    expect((await helper.obtener('eventos')).single['completado'], 0);
    expect(
      await (await helper.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  });
}
