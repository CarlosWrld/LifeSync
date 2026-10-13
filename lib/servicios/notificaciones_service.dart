import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../modelos/evento.dart';
import '../modelos/tarea.dart';
import 'horarios.dart';

enum EstadoRecordatorios {
  activos,
  sinPermiso,
  horaAproximada,
  limiteAlcanzado,
  noDisponible,
}

/// El sistema operativo entrega los avisos aunque LifeSync no esté abierta.
class NotificacionesService {
  NotificacionesService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String> Function()? zonaHoraria,
    DateTime Function()? reloj,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _zonaHoraria = zonaHoraria ?? _zonaDelTelefono,
       _reloj = reloj ?? DateTime.now;

  static final instance = NotificacionesService();
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _zonaHoraria;
  final DateTime Function() _reloj;
  Future<void> _cola = Future.value();
  bool _inicializado = false;
  final _idsConocidos = <int>{};

  bool get disponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<String> _zonaDelTelefono() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  // Evita que una sincronización pendiente vuelva a crear avisos tras salir.
  Future<T> _enCola<T>(Future<T> Function() accion) {
    final resultado = _cola.then((_) => accion());
    _cola = resultado.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return resultado;
  }

  Future<void> _inicializar() async {
    if (_inicializado) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _inicializado = true;
  }

  Future<EstadoRecordatorios> sincronizar({
    required int usuarioId,
    required List<Tarea> tareas,
    required List<Evento> eventos,
    bool solicitarPermisos = false,
  }) => _enCola(() async {
    if (!disponible) return EstadoRecordatorios.noDisponible;
    await _inicializar();
    final zona = tz.getLocation(await _zonaHoraria());
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool permitido = true;
    bool exacto = true;
    if (android != null) {
      if (solicitarPermisos) {
        await android.requestNotificationsPermission();
      }
      permitido = await android.areNotificationsEnabled() ?? false;
      exacto = await android.canScheduleExactNotifications() ?? false;
      if (permitido && !exacto && solicitarPermisos) {
        await android.requestExactAlarmsPermission();
        exacto = await android.canScheduleExactNotifications() ?? false;
      }
    } else if (ios != null) {
      if (solicitarPermisos) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
      permitido = (await ios.checkPermissions())?.isEnabled ?? false;
    }

    // Los diálogos de permisos pueden permanecer abiertos varios minutos.
    final ahora = tz.TZDateTime.from(_reloj(), zona);
    final planes = planificarRecordatorios(tareas, eventos, ahora);
    final pendientes = await _plugin.pendingNotificationRequests();
    final limite = defaultTargetPlatform == TargetPlatform.iOS ? 64 : 500;
    final seleccionados = planes.take(limite).toList();
    final idsDeseados = seleccionados.map((p) => p.id).toSet();
    final idsAnteriores = {
      ..._idsConocidos,
      ...pendientes.map((p) => p.id),
      ...tareas.where((t) => t.completada).map((t) => t.id * 2),
      ...eventos.where((e) => e.completado).map((e) => e.id * 2 + 1),
    };
    for (final id in idsAnteriores.difference(idsDeseados)) {
      await _plugin.cancel(id: id);
    }
    _idsConocidos
      ..clear()
      ..addAll(idsDeseados);

    final modo = exacto
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final plan in seleccionados) {
      // La huella diaria omite el día: no se reinicia un aviso sin cambios.
      final huella = jsonEncode({
        'usuario': usuarioId,
        'id': plan.id,
        'texto': plan.texto,
        'fecha': plan.diario
            ? '${plan.fecha.hour}:${plan.fecha.minute}'
            : plan.fecha.toIso8601String(),
        'zona': zona.name,
        'exacto': exacto,
      });
      if (pendientes.any((p) => p.id == plan.id && p.payload == huella)) {
        continue;
      }
      // Elimina también un aviso ya visible si su contenido cambió.
      await _plugin.cancel(id: plan.id);
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.diario ? 'Es hora de tu tarea' : 'Es hora de tu evento',
        body: plan.texto,
        scheduledDate: plan.fecha,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'recordatorios_v1',
            'Tareas y eventos',
            channelDescription: 'Avisos a la hora de tus tareas y eventos',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
            styleInformation: BigTextStyleInformation(plan.texto),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: modo,
        matchDateTimeComponents: plan.diario ? DateTimeComponents.time : null,
        payload: huella,
      );
    }
    if (!permitido) return EstadoRecordatorios.sinPermiso;
    if (!exacto) return EstadoRecordatorios.horaAproximada;
    if (planes.length > limite) return EstadoRecordatorios.limiteAlcanzado;
    return EstadoRecordatorios.activos;
  });

  Future<void> cancelarTodos() => _enCola(() async {
    if (!disponible) return;
    await _inicializar();
    await _plugin.cancelAll();
    _idsConocidos.clear();
  });

  Future<void> abrirAjustes() => _enCola(() async {
    if (!disponible) return;
    await _inicializar();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
  });
}

class RecordatorioProgramado {
  const RecordatorioProgramado(this.id, this.texto, this.fecha, this.diario);
  final int id;
  final String texto;
  final tz.TZDateTime fecha;
  final bool diario;
}

/// IDs pares para tareas e impares para eventos: las tablas tienen IDs propios.
List<RecordatorioProgramado> planificarRecordatorios(
  List<Tarea> tareas,
  List<Evento> eventos,
  tz.TZDateTime ahora,
) {
  final planes = <RecordatorioProgramado>[];
  for (final tarea in tareas.where((t) => !t.completada)) {
    final minutos = minutosDeHora(tarea.hora);
    if (minutos == null) continue;
    var fecha = tz.TZDateTime(
      ahora.location,
      ahora.year,
      ahora.month,
      ahora.day,
      minutos ~/ 60,
      minutos % 60,
    );
    if (!fecha.isAfter(ahora)) {
      // Día de calendario, no 24 horas: conserva la hora al cambiar el DST.
      fecha = tz.TZDateTime(
        ahora.location,
        ahora.year,
        ahora.month,
        ahora.day + 1,
        minutos ~/ 60,
        minutos % 60,
      );
    }
    planes.add(RecordatorioProgramado(tarea.id * 2, tarea.titulo, fecha, true));
  }
  for (final evento in eventos.where((e) => !e.completado)) {
    final minutos = minutosDeHora(evento.hora);
    if (minutos == null) continue;
    final fecha = tz.TZDateTime(
      ahora.location,
      evento.fecha.year,
      evento.fecha.month,
      evento.fecha.day,
      minutos ~/ 60,
      minutos % 60,
    );
    if (fecha.isAfter(ahora)) {
      planes.add(
        RecordatorioProgramado(evento.id * 2 + 1, evento.titulo, fecha, false),
      );
    }
  }
  planes.sort((a, b) => a.fecha.compareTo(b.fecha));
  return planes;
}
