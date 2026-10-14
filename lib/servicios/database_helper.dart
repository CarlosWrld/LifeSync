import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../modelos/usuario.dart';
import 'password_service.dart';
import 'horarios.dart';
import 'google_auth_service.dart';

class HorarioOcupadoException implements Exception {
  HorarioOcupadoException(this.mensaje);
  final String mensaje;
}

class CorreoRegistradoException implements Exception {}

class AccesoDenegadoException implements Exception {}

class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  DatabaseHelper.forTesting(DatabaseFactory factory, String path)
    : _factory = factory,
      _path = path;
  DatabaseFactory? _factory;
  String? _path;
  Future<Database>? _opening;
  Usuario? _session;
  Usuario? get usuarioActual => _session;

  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      final factory = _factory ?? databaseFactory;
      final path =
          _path ?? join(await factory.getDatabasesPath(), 'lifesync.db');
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await _create(db);
            await _configurarAdmin(db);
            await _crearTablaSesion(db);
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _migrateV1(db);
            if (oldVersion < 3) await _configurarAdmin(db);
            if (oldVersion >= 2 && oldVersion < 4) {
              final columnas = await db.rawQuery('PRAGMA table_info(usuarios)');
              if (!columnas.any((c) => c['name'] == 'google_id')) {
                await db.execute(
                  'ALTER TABLE usuarios ADD COLUMN google_id TEXT',
                );
              }
              await db.execute(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_google ON usuarios(google_id)',
              );
            }
            if (oldVersion >= 2 && oldVersion < 5) {
              final columnas = await db.rawQuery('PRAGMA table_info(usuarios)');
              if (!columnas.any((c) => c['name'] == 'foto')) {
                await db.execute('ALTER TABLE usuarios ADD COLUMN foto BLOB');
              }
            }
            if (oldVersion < 6) await _crearTablaSesion(db);
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> _crearTablaSesion(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS sesion_activa (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE
    )
  ''');

  Future<void> _guardarSesion(DatabaseExecutor db, int usuarioId) async {
    // Solo recuerda la cuenta ya autenticada; no almacena tokens ni contraseñas.
    await db.insert('sesion_activa', {
      'id': 1,
      'usuario_id': usuarioId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Usuario?> restaurarSesion() async {
    final rows = await (await database).rawQuery('''
      SELECT usuarios.* FROM usuarios
      INNER JOIN sesion_activa ON sesion_activa.usuario_id = usuarios.id
      WHERE sesion_activa.id = 1
    ''');
    return _session = rows.isEmpty ? null : Usuario.fromMap(rows.single);
  }

  // Se ejecuta una sola vez al crear o actualizar la base local.
  // La contraseña inicial se almacena únicamente como hash PBKDF2.
  Future<void> _configurarAdmin(DatabaseExecutor db) async {
    const correo = 'cp448570@gmail.com';
    final existentes = await db.query(
      'usuarios',
      where: 'correo = ?',
      whereArgs: [correo],
    );
    await db.update('usuarios', {'rol': 'usuario'});
    final datos = <String, Object?>{
      'nombre': 'Carlos Pérez',
      'correo': correo,
      'password':
          'pbkdf2-sha256:600000:qBaif/lal9bmPcRfybW0gQ==:H+IhrEZPmVUoPKQFSYA8i4YEfBestiiT/UMJi2gVVoY=',
      'rol': 'admin',
      'proveedor': 'correo',
    };
    if (existentes.isEmpty) {
      await db.insert('usuarios', datos);
    } else {
      // Conserva el ID y los datos asociados si la cuenta ya existía.
      await db.update(
        'usuarios',
        datos,
        where: 'id = ?',
        whereArgs: [existentes.single['id']],
      );
    }
  }

  Future<void> _create(DatabaseExecutor db) async {
    await db.execute("""CREATE TABLE usuarios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      correo TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password TEXT NOT NULL,
      rol TEXT NOT NULL DEFAULT 'usuario' CHECK (rol IN ('usuario', 'admin')),
      proveedor TEXT NOT NULL DEFAULT 'correo',
      google_id TEXT,
      foto BLOB
    )""");
    await db.execute(
      'CREATE UNIQUE INDEX idx_usuarios_google ON usuarios(google_id)',
    );
    await db.execute("""CREATE TABLE tareas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      titulo TEXT NOT NULL, hora TEXT NOT NULL,
      completada INTEGER NOT NULL DEFAULT 0 CHECK(completada IN (0,1))
    )""");
    await db.execute("""CREATE TABLE habitos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      nombre TEXT NOT NULL, meta INTEGER NOT NULL CHECK(meta > 0),
      unidad TEXT NOT NULL,
      progreso INTEGER NOT NULL DEFAULT 0 CHECK(progreso >= 0 AND progreso <= meta)
    )""");
    await db.execute("""CREATE TABLE eventos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      titulo TEXT NOT NULL, fecha TEXT NOT NULL, hora TEXT NOT NULL,
      completado INTEGER NOT NULL DEFAULT 0 CHECK(completado IN (0,1))
    )""");
    for (final table in _tables) {
      await db.execute(
        'CREATE INDEX idx_${table}_usuario ON $table(usuario_id)',
      );
    }
  }

  // Conserva IDs y combina correos equivalentes bajo la cuenta más antigua.
  Future<void> _migrateV1(Database db) async {
    for (final table in [..._tables, 'usuarios']) {
      await db.execute('ALTER TABLE $table RENAME TO ${table}_v1');
    }
    await _create(db);
    final owners = <int, int>{};
    final seen = <String, int>{};
    final rows = await db.query('usuarios_v1', orderBy: 'id ASC');
    for (final row in rows) {
      final id = row['id'] as int;
      final email = (row['correo'] as String).trim().toLowerCase();
      if (seen.containsKey(email)) {
        owners[id] = seen[email]!;
        continue;
      }
      owners[id] = id;
      seen[email] = id;
      await db.insert('usuarios', {
        ...row,
        'correo': email,
        'password': await PasswordService.hash(
          row['password'] as String? ?? '',
        ),
        'rol': 'usuario',
      });
    }
    for (final table in _tables) {
      for (final row in await db.query('${table}_v1')) {
        final owner = owners[row['usuario_id']];
        if (owner == null) {
          throw StateError('Existen datos sin usuario en la base anterior.');
        }
        await db.insert(table, {...row, 'usuario_id': owner});
      }
      await db.execute('DROP TABLE ${table}_v1');
    }
    await db.execute('DROP TABLE usuarios_v1');
  }

  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final email = correo.trim().toLowerCase();
    if (nombre.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.length < 8) {
      throw ArgumentError('Datos de registro inválidos');
    }
    final db = await database;
    final hash = await PasswordService.hash(password);
    final user = await db.transaction((txn) async {
      if ((await txn.query(
        'usuarios',
        columns: ['id'],
        where: 'correo = ?',
        whereArgs: [email],
      )).isNotEmpty) {
        throw CorreoRegistradoException();
      }
      final values = <String, Object?>{
        'nombre': nombre.trim(),
        'correo': email,
        'password': hash,
        'rol': 'usuario',
        'proveedor': 'correo',
      };
      final id = await txn.insert('usuarios', values);
      await _guardarSesion(txn, id);
      return Usuario.fromMap({...values, 'id': id});
    });
    _session = user;
    return user;
  }

  Future<Usuario?> iniciarSesion(String correo, String password) async {
    await cerrarSesion();
    final db = await database;
    final rows = await db.query(
      'usuarios',
      where: 'correo = ?',
      whereArgs: [correo.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty ||
        !await PasswordService.verify(
          password,
          rows.first['password'] as String,
        )) {
      return null;
    }
    final usuario = Usuario.fromMap(rows.first);
    await _guardarSesion(db, usuario.id);
    return _session = usuario;
  }

  Future<Usuario?> iniciarSesionGoogle() async {
    await cerrarSesion();
    final cuenta = await GoogleAuthService.instance.autenticar();
    if (cuenta == null) return null;
    try {
      return await guardarSesionGoogle(
        googleId: cuenta.id,
        correo: cuenta.email,
        nombre: cuenta.displayName ?? cuenta.email.split('@').first,
      );
    } catch (_) {
      try {
        await GoogleAuthService.instance.cerrarSesion();
      } catch (_) {
        // Conserva el error original del guardado local.
      }
      rethrow;
    }
  }

  /// Solo se llama después de autenticar la cuenta con el SDK nativo de Google.
  Future<Usuario> guardarSesionGoogle({
    required String googleId,
    required String correo,
    required String nombre,
  }) async {
    await cerrarSesion();
    if (googleId.isEmpty || correo.trim().isEmpty) {
      throw AccesoDenegadoException();
    }
    final db = await database;
    final usuario = await db.transaction((txn) async {
      final existentes = await txn.query(
        'usuarios',
        where: 'google_id = ?',
        whereArgs: [googleId],
      );
      if (existentes.isNotEmpty) {
        final usuario = Usuario.fromMap(existentes.single);
        await _guardarSesion(txn, usuario.id);
        return usuario;
      }
      final email = correo.trim().toLowerCase();
      if ((await txn.query(
        'usuarios',
        where: 'correo = ?',
        whereArgs: [email],
      )).isNotEmpty) {
        // No vincular cuentas locales (ni al administrador) solo por el correo.
        throw CorreoRegistradoException();
      }
      final datos = <String, Object?>{
        'nombre': nombre.trim().isEmpty
            ? email.split('@').first
            : nombre.trim(),
        'correo': email,
        'password': '', // No hay contraseña local para una cuenta de Google.
        'rol': 'usuario',
        'proveedor': 'google',
        'google_id': googleId,
      };
      final id = await txn.insert('usuarios', datos);
      await _guardarSesion(txn, id);
      return Usuario.fromMap({...datos, 'id': id});
    });
    return _session = usuario;
  }

  Future<Usuario> actualizarPerfil({
    required int usuarioId,
    required String nombre,
    required Uint8List? foto,
  }) async {
    final sesion = _session;
    if (_owner() != usuarioId) throw AccesoDenegadoException();
    final limpio = nombre.trim();
    if (limpio.isEmpty || limpio.length > 80) {
      throw ArgumentError('Escribe un nombre de entre 1 y 80 caracteres');
    }
    if (foto != null && (foto.isEmpty || foto.length > Usuario.maxFotoBytes)) {
      throw ArgumentError('La foto debe pesar como máximo 1 MB');
    }
    final db = await database;
    final actualizado = await db.transaction((txn) async {
      if (!identical(_session, sesion)) throw AccesoDenegadoException();
      final count = await txn.update(
        'usuarios',
        {'nombre': limpio, 'foto': foto},
        where: 'id = ?',
        whereArgs: [usuarioId],
      );
      if (count != 1) throw AccesoDenegadoException();
      final rows = await txn.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );
      return Usuario.fromMap(rows.single);
    });
    if (identical(_session, sesion)) _session = actualizado;
    return actualizado;
  }

  Future<void> cerrarSesion() async {
    await (await database).delete('sesion_activa');
    _session = null;
  }

  int _owner() {
    if (_session == null) throw AccesoDenegadoException();
    return _session!.id;
  }

  Future<List<Usuario>> obtenerUsuarios() async {
    final id = _owner();
    final db = await database;
    final actor = await db.query(
      'usuarios',
      columns: ['rol'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (actor.isEmpty || actor.first['rol'] != 'admin') {
      throw AccesoDenegadoException();
    }
    return (await db.query(
      'usuarios',
      columns: ['id', 'nombre', 'correo', 'rol', 'proveedor'],
      orderBy: 'id DESC',
    )).map(Usuario.fromMap).toList();
  }

  static const _tables = ['tareas', 'habitos', 'eventos'];
  void _checkTable(String table) {
    if (!_tables.contains(table)) throw ArgumentError('Tabla inválida');
  }

  Future<List<Map<String, Object?>>> obtener(String table) async {
    _checkTable(table);
    final id = _owner();
    return (await database).query(
      table,
      where: 'usuario_id = ?',
      whereArgs: [id],
      orderBy: table == 'eventos' ? 'fecha ASC, id ASC' : 'id DESC',
    );
  }

  Future<void> guardar(
    String table,
    Map<String, Object?> values, {
    int? id,
  }) async {
    _checkTable(table);
    final owner = _owner();
    final db = await database;
    final safeValues = Map<String, Object?>.of(values)
      ..remove('id')
      ..remove('usuario_id');
    await db.transaction((txn) async {
      if ((table == 'tareas' || table == 'eventos') &&
          (id == null ||
              safeValues.containsKey('hora') ||
              safeValues.containsKey('fecha'))) {
        final rows = await txn.query(
          table,
          where: 'usuario_id = ?',
          whereArgs: [owner],
        );
        final actual = id == null
            ? <String, Object?>{}
            : rows.where((r) => r['id'] == id).firstOrNull;
        if (actual == null) throw AccesoDenegadoException();
        final datos = {...actual, ...safeValues};
        final minutos = minutosDeHora(datos['hora'] as String? ?? '');
        if (minutos == null) throw ArgumentError('Hora inválida');
        safeValues['hora'] =
            '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';
        final fecha = table == 'eventos'
            ? DateTime.parse(datos['fecha'] as String)
            : null;
        if (rows.any(
          (r) =>
              r['id'] != id &&
              minutosDeHora(r['hora'] as String) == minutos &&
              (fecha == null ||
                  mismoDia(DateTime.parse(r['fecha'] as String), fecha)),
        )) {
          throw HorarioOcupadoException(
            table == 'tareas'
                ? 'Ya tienes una tarea a esa hora'
                : 'Ya tienes un evento en esa fecha y hora',
          );
        }
      }
      if (id == null) {
        await txn.insert(table, {...safeValues, 'usuario_id': owner});
      } else {
        final count = await txn.update(
          table,
          safeValues,
          where: 'id = ? AND usuario_id = ?',
          whereArgs: [id, owner],
        );
        if (count != 1) throw AccesoDenegadoException();
      }
    });
  }

  Future<void> eliminar(String table, int id) async {
    _checkTable(table);
    final owner = _owner();
    final count = await (await database).delete(
      table,
      where: 'id = ? AND usuario_id = ?',
      whereArgs: [id, owner],
    );
    if (count != 1) throw AccesoDenegadoException();
  }

  Future<void> close() async {
    _session = null;
    final pending = _opening;
    _opening = null;
    if (pending != null) await (await pending).close();
  }
}
