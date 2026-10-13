import 'package:appmovil/modelos/evento.dart';
import 'package:appmovil/modelos/tarea.dart';
import 'package:appmovil/servicios/notificaciones_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final mexico = tz.getLocation('America/Mexico_City');

  test('Conserva texto, hora local, fecha del evento e IDs distintos', () {
    final planes = planificarRecordatorios(
      [Tarea(id: 1, titulo: 'Hacer la tarea de matemáticas', hora: '6:30 PM')],
      [
        Evento(
          id: 1,
          titulo: 'Boda',
          fecha: DateTime(2030, 9, 28),
          hora: '12:00',
        ),
      ],
      tz.TZDateTime(mexico, 2030, 9, 27, 10),
    );
    expect(planes[0].texto, 'Hacer la tarea de matemáticas');
    expect(planes[0].fecha, tz.TZDateTime(mexico, 2030, 9, 27, 18, 30));
    expect(planes[0].diario, isTrue);
    expect(planes[1].texto, 'Boda');
    expect(planes[1].fecha, tz.TZDateTime(mexico, 2030, 9, 28, 12));
    expect(planes[1].diario, isFalse);
    expect(planes.map((p) => p.id).toSet(), hasLength(2));
  });

  test('Hora pasada pasa a mañana; omite eventos pasados y completados', () {
    final planes = planificarRecordatorios(
      [
        Tarea(id: 1, titulo: 'Medianoche', hora: '00:00'),
        Tarea(id: 2, titulo: 'Lista', hora: '10:00', completada: true),
        Tarea(id: 3, titulo: 'Hora inválida', hora: '24:90'),
      ],
      [
        Evento(
          id: 1,
          titulo: 'Pasado',
          fecha: DateTime(2030, 9, 26),
          hora: '12:00',
        ),
        Evento(
          id: 2,
          titulo: 'Ya empezó',
          fecha: DateTime(2030, 9, 27),
          hora: '12:00',
        ),
        Evento(
          id: 3,
          titulo: 'Listo',
          fecha: DateTime(2030, 9, 28),
          hora: '12:00',
          completado: true,
        ),
      ],
      tz.TZDateTime(mexico, 2030, 9, 27, 12),
    );
    expect(planes, hasLength(1));
    expect(planes.single.fecha, tz.TZDateTime(mexico, 2030, 9, 28));
  });

  test('Conserva la hora de mañana al cambiar el horario de verano', () {
    final zona = tz.getLocation('America/New_York');
    final ahora = tz.TZDateTime(zona, 2030, 11, 2, 9);
    final plan = planificarRecordatorios(
      [Tarea(id: 1, titulo: 'Leer', hora: '09:00')],
      [],
      ahora,
    ).single;
    expect(plan.fecha, tz.TZDateTime(zona, 2030, 11, 3, 9));
    expect(plan.fecha.difference(ahora).inHours, 25);
  });

  group('Programación en el teléfono', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final llamadas = <MethodCall>[];
    final pendientes = <int, Map<String, Object?>>{};
    late NotificacionesService servicio;
    var permiso = true;
    var exacto = true;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      llamadas.clear();
      pendientes.clear();
      permiso = true;
      exacto = true;
      servicio = NotificacionesService(
        zonaHoraria: () async => 'America/Mexico_City',
        reloj: () => DateTime.utc(2030, 9, 27, 16),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            llamadas.add(call);
            switch (call.method) {
              case 'initialize':
              case 'requestNotificationsPermission':
              case 'requestExactAlarmsPermission':
                return true;
              case 'areNotificationsEnabled':
                return permiso;
              case 'canScheduleExactNotifications':
                return exacto;
              case 'pendingNotificationRequests':
                return pendientes.values.toList();
              case 'zonedSchedule':
                final args = Map<String, Object?>.from(call.arguments as Map);
                pendientes[args['id'] as int] = {
                  'id': args['id'],
                  'title': args['title'],
                  'body': args['body'],
                  'payload': args['payload'],
                };
                return null;
              case 'cancel':
                pendientes.remove((call.arguments as Map)['id']);
                return null;
              case 'cancelAll':
                pendientes.clear();
                return null;
            }
            return null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'Programa, evita duplicados, edita, completa y elimina avisos',
      () async {
        final tarea = Tarea(id: 1, titulo: 'Matemáticas', hora: '18:30');
        final evento = Evento(
          id: 1,
          titulo: 'Boda',
          fecha: DateTime(2030, 9, 28),
          hora: '12:00',
        );
        Future<EstadoRecordatorios> sincronizar() => servicio.sincronizar(
          usuarioId: 1,
          tareas: [tarea],
          eventos: [evento],
        );
        expect(await sincronizar(), EstadoRecordatorios.activos);
        expect(
          pendientes.values.map((p) => p['body']),
          containsAll(['Matemáticas', 'Boda']),
        );
        final programados = llamadas
            .where((c) => c.method == 'zonedSchedule')
            .toList();
        expect(programados, hasLength(2));
        expect(
          (programados[0].arguments as Map)['timeZoneName'],
          'America/Mexico_City',
        );
        expect(
          (programados[0].arguments as Map)['matchDateTimeComponents'],
          isNotNull,
        );
        expect(
          (programados[1].arguments as Map)['matchDateTimeComponents'],
          isNull,
        );
        llamadas.clear();
        await sincronizar();
        expect(llamadas.where((c) => c.method == 'zonedSchedule'), isEmpty);

        tarea.titulo = 'Estudiar álgebra';
        tarea.hora = '19:00';
        evento.fecha = DateTime(2030, 10, 2);
        await sincronizar();
        expect(pendientes[2]!['body'], 'Estudiar álgebra');
        expect(
          llamadas.where((c) => c.method == 'zonedSchedule'),
          hasLength(2),
        );
        tarea.completada = true;
        await sincronizar();
        expect(pendientes.containsKey(2), isFalse);
        await servicio.sincronizar(usuarioId: 1, tareas: [], eventos: []);
        expect(pendientes, isEmpty);
      },
    );

    test(
      'Permisos denegados no impiden guardar y permiten avisos aproximados',
      () async {
        permiso = false;
        exacto = false;
        final tareas = [Tarea(id: 1, titulo: 'Leer', hora: '18:00')];
        expect(
          await servicio.sincronizar(
            usuarioId: 1,
            tareas: tareas,
            eventos: [],
            solicitarPermisos: true,
          ),
          EstadoRecordatorios.sinPermiso,
        );
        expect(
          llamadas.any((c) => c.method == 'requestNotificationsPermission'),
          isTrue,
        );
        expect(
          llamadas.any((c) => c.method == 'requestExactAlarmsPermission'),
          isFalse,
        );
        permiso = true;
        expect(
          await servicio.sincronizar(usuarioId: 1, tareas: tareas, eventos: []),
          EstadoRecordatorios.horaAproximada,
        );
        expect(pendientes, hasLength(1));
        exacto = true;
        llamadas.clear();
        expect(
          await servicio.sincronizar(usuarioId: 1, tareas: tareas, eventos: []),
          EstadoRecordatorios.activos,
        );
        expect(
          llamadas.where((c) => c.method == 'zonedSchedule'),
          hasLength(1),
        );
      },
    );

    test('Salir espera la sincronización y cancela todos los avisos', () async {
      final sincronizacion = servicio.sincronizar(
        usuarioId: 1,
        tareas: [Tarea(id: 1, titulo: 'Leer', hora: '18:00')],
        eventos: [],
      );
      final salida = servicio.cancelarTodos();
      await Future.wait([sincronizacion, salida]);
      expect(pendientes, isEmpty);
      expect(llamadas.last.method, 'cancelAll');
    });

    test(
      'Al cambiar de cuenta se eliminan los avisos de la anterior',
      () async {
        await servicio.sincronizar(
          usuarioId: 1,
          tareas: [Tarea(id: 1, titulo: 'Personal', hora: '18:00')],
          eventos: [],
        );
        await servicio.sincronizar(
          usuarioId: 2,
          tareas: [Tarea(id: 2, titulo: 'Otra cuenta', hora: '19:00')],
          eventos: [],
        );
        expect(pendientes, hasLength(1));
        expect(pendientes.values.single['body'], 'Otra cuenta');
      },
    );
  });
}
