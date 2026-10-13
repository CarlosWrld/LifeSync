import 'modelos/usuario.dart';
import 'modelos/tarea.dart';
import 'modelos/habito.dart';
import 'modelos/evento.dart';
import 'pantallas/admin_page.dart';
import 'pantallas/festivos_panel.dart';
import 'pantallas/auth_design.dart';
import 'pantallas/editar_perfil_page.dart';
import 'servicios/database_helper.dart';
import 'servicios/horarios.dart';
import 'servicios/google_auth_service.dart';
import 'servicios/notificaciones_service.dart';

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.restaurarSesion});

  final Future<Usuario?> Function()? restaurarSesion;

  @override
  State<MyApp> createState() => _LifeSyncAppState();
}

class _LifeSyncAppState extends State<MyApp> {
  Usuario? usuario;
  bool recuperandoSesion = true;
  bool errorSesion = false;

  @override
  void initState() {
    super.initState();
    recuperarSesion();
  }

  Future<void> recuperarSesion() async {
    setState(() {
      recuperandoSesion = true;
      errorSesion = false;
    });
    try {
      final restaurar =
          widget.restaurarSesion ?? DatabaseHelper.instance.restaurarSesion;
      final guardado = await restaurar();
      if (mounted) setState(() => usuario = guardado);
    } catch (_) {
      if (mounted) setState(() => errorSesion = true);
    } finally {
      if (mounted) setState(() => recuperandoSesion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080B16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3BFF),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF12182A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF12182A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF27304A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF8B5CFF), width: 2),
          ),
        ),
      ),
      home: recuperandoSesion || errorSesion
          ? Scaffold(
              body: Center(
                child: recuperandoSesion
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No se pudo recuperar tu sesión.'),
                          TextButton(
                            onPressed: recuperarSesion,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
              ),
            )
          : usuario == null
          ? RegistroPage(
              onRegistro: (nuevoUsuario) {
                setState(() => usuario = nuevoUsuario);
              },
            )
          : InicioTelefono(
              usuario: usuario!,
              onPerfilActualizado: (actualizado) {
                setState(() => usuario = actualizado);
              },
              onCerrarSesion: () async {
                final esGoogle = usuario?.proveedor == 'google';
                await DatabaseHelper.instance.cerrarSesion();
                if (esGoogle) {
                  try {
                    await GoogleAuthService.instance.cerrarSesion();
                  } catch (_) {
                    // La sesión local ya está cerrada aunque falle el SDK.
                  }
                }
                if (mounted) setState(() => usuario = null);
              },
            ),
    );
  }
}

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key, required this.onRegistro});

  final ValueChanged<Usuario> onRegistro;

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final formKey = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final contrasena = TextEditingController();
  bool ocultar = true;
  bool registro = false;
  bool ocupado = false;
  String? error;

  Future<void> entrarConGoogle() async {
    if (ocupado) return;
    FocusScope.of(context).unfocus();
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final usuario = await DatabaseHelper.instance.iniciarSesionGoogle();
      if (mounted && usuario != null) widget.onRegistro(usuario);
    } on CorreoRegistradoException {
      if (mounted) {
        setState(
          () => error =
              'Este correo ya tiene una cuenta local. Entra con su contraseña.',
        );
      }
    } on GoogleAuthException catch (e) {
      if (mounted) setState(() => error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo completar el acceso con Google. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    contrasena.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (ocupado) return;
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final db = DatabaseHelper.instance;
      final user = registro
          ? await db.registrar(
              nombre: nombre.text,
              correo: correo.text,
              password: contrasena.text,
            )
          : await db.iniciarSesion(correo.text, contrasena.text);
      if (!mounted) return;
      if (user == null) {
        setState(() => error = 'Correo o contraseña incorrectos');
      } else {
        widget.onRegistro(user);
      }
    } on CorreoRegistradoException {
      if (mounted) setState(() => error = 'Este correo ya está registrado');
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo acceder a la base local. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: const Color(0xFF111522),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 23,
                      ),
                      labelStyle: const TextStyle(
                        color: Color(0xFF9696AA),
                        fontSize: 17,
                      ),
                      prefixIconColor: const Color(0xFFB2B4C6),
                      suffixIconColor: const Color(0xFFB2B4C6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF191B2C)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFF8B5CFF),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthBrand(),
                        const SizedBox(height: 15),
                        Text(
                          registro ? 'Crear cuenta' : 'Iniciar sesión',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFB9B9C5),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (registro)
                          TextFormField(
                            controller: nombre,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (valor) =>
                                valor == null || valor.trim().isEmpty
                                ? 'Escribe tu nombre'
                                : null,
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: correo,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (valor) {
                            final texto = valor?.trim() ?? '';
                            if (texto.isEmpty) return 'Escribe tu correo';
                            if (!RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(texto)) {
                              return 'Escribe un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: contrasena,
                          obscureText: ocultar,
                          onFieldSubmitted: (_) => entrar(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => ocultar = !ocultar),
                              icon: Icon(
                                ocultar
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (valor) =>
                              (valor?.length ?? 0) < (registro ? 8 : 1)
                              ? (registro
                                    ? 'Usa al menos 8 caracteres'
                                    : 'Escribe tu contraseña')
                              : null,
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Color(0xFFFF6B85)),
                            ),
                          ),
                        const SizedBox(height: 24),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: authGradient,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: FilledButton(
                            onPressed: ocupado ? null : entrar,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: Text(
                              ocupado
                                  ? 'Procesando...'
                                  : registro
                                  ? 'Registrarse'
                                  : 'Entrar a LifeSync',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: ocupado ? null : entrarConGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: Color(0xFF666A80)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: const Text('Continuar con Google'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          registro
                              ? '¿Ya tienes cuenta?'
                              : '¿Aún no tienes cuenta?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFA9A8B8),
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: ocupado
                              ? null
                              : () => setState(() {
                                  registro = !registro;
                                  error = null;
                                  formKey.currentState?.reset();
                                }),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFA676E2),
                            textStyle: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            registro
                                ? 'Ya tengo cuenta. Iniciar sesión'
                                : 'Crear una cuenta',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InicioTelefono extends StatefulWidget {
  const InicioTelefono({
    super.key,
    required this.usuario,
    required this.onPerfilActualizado,
    required this.onCerrarSesion,
  });

  final Usuario usuario;
  final ValueChanged<Usuario> onPerfilActualizado;
  final Future<void> Function() onCerrarSesion;

  @override
  State<InicioTelefono> createState() => _InicioTelefonoState();
}

class _InicioTelefonoState extends State<InicioTelefono>
    with WidgetsBindingObserver {
  int pagina = 0;
  bool cargando = true;
  bool guardando = false;
  String? errorCarga;
  final tareas = <Tarea>[];
  final habitos = <Habito>[];
  final eventos = <Evento>[];
  final db = DatabaseHelper.instance;
  final notificaciones = NotificacionesService.instance;
  String estadoNotificaciones = 'Preparando recordatorios…';
  int sincronizaciones = 0;
  bool cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cargarDatos(solicitarPermisos: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !cargando &&
        !guardando &&
        !cerrandoSesion &&
        sincronizaciones == 0 &&
        errorCarga == null) {
      actualizarRecordatorios();
    }
  }

  Future<void> actualizarRecordatorios({bool solicitarPermisos = false}) async {
    if (!mounted || cerrandoSesion) return;
    sincronizaciones++;
    try {
      final estado = await notificaciones.sincronizar(
        usuarioId: widget.usuario.id,
        tareas: List.of(tareas),
        eventos: List.of(eventos),
        solicitarPermisos: solicitarPermisos,
      );
      final mensaje = switch (estado) {
        EstadoRecordatorios.activos => 'Avisos activados a la hora elegida',
        EstadoRecordatorios.sinPermiso =>
          'Activa las notificaciones de LifeSync en los ajustes del teléfono',
        EstadoRecordatorios.horaAproximada =>
          'Permite alarmas y recordatorios para recibir avisos a la hora exacta',
        EstadoRecordatorios.limiteAlcanzado =>
          'Se alcanzó el límite del teléfono. Se programaron los avisos más cercanos',
        EstadoRecordatorios.noDisponible =>
          'Los recordatorios están disponibles en Android y iPhone',
      };
      if (!mounted || cerrandoSesion) return;
      final cambio = estadoNotificaciones != mensaje;
      setState(() => estadoNotificaciones = mensaje);
      if (cambio &&
          estado != EstadoRecordatorios.activos &&
          estado != EstadoRecordatorios.noDisponible) {
        aviso(mensaje);
      }
    } catch (error, stack) {
      debugPrint('No se pudieron programar los recordatorios: $error\n$stack');
      if (!mounted || cerrandoSesion) return;
      const mensaje =
          'Tus datos están guardados, pero no se pudieron programar los avisos. Reintenta desde Perfil.';
      setState(() => estadoNotificaciones = mensaje);
      aviso(mensaje);
    } finally {
      sincronizaciones--;
    }
  }

  Future<void> configurarRecordatorios() async {
    if (sincronizaciones > 0) return;
    await actualizarRecordatorios(solicitarPermisos: true);
  }

  Future<void> abrirAjustesNotificaciones() async {
    try {
      await notificaciones.abrirAjustes();
    } catch (_) {
      aviso('Abre Ajustes del teléfono > LifeSync > Notificaciones.');
    }
  }

  Future<void> cargarDatos({bool solicitarPermisos = false}) async {
    try {
      final t = await db.obtener('tareas');
      final h = await db.obtener('habitos');
      final e = await db.obtener('eventos');
      if (!mounted) return;
      setState(() {
        tareas
          ..clear()
          ..addAll(
            t.map(
              (r) => Tarea(
                id: r['id'] as int,
                titulo: r['titulo'] as String,
                hora: r['hora'] as String,
                completada: r['completada'] == 1,
              ),
            ),
          );
        habitos
          ..clear()
          ..addAll(
            h.map(
              (r) => Habito(
                id: r['id'] as int,
                nombre: r['nombre'] as String,
                meta: r['meta'] as int,
                unidad: r['unidad'] as String,
                progreso: r['progreso'] as int,
              ),
            ),
          );
        eventos
          ..clear()
          ..addAll(
            e.map(
              (r) => Evento(
                id: r['id'] as int,
                titulo: r['titulo'] as String,
                fecha: DateTime.parse(r['fecha'] as String),
                hora: r['hora'] as String,
                completado: r['completado'] == 1,
              ),
            ),
          );
        errorCarga = null;
      });
      await actualizarRecordatorios(solicitarPermisos: solicitarPermisos);
    } catch (_) {
      if (mounted) {
        setState(() => errorCarga = 'No se pudieron cargar tus datos locales.');
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> modificar(Future<void> Function() operacion) async {
    if (guardando) return;
    setState(() => guardando = true);
    try {
      await operacion();
      await cargarDatos();
    } on HorarioOcupadoException catch (error) {
      aviso(error.mensaje);
    } catch (_) {
      aviso('No se pudo guardar el cambio. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> abrirFormularioTarea({Tarea? tarea}) async {
    final resultado = await Navigator.of(context).push<DatosTarea>(
      MaterialPageRoute(
        builder: (_) => FormularioTarea(tarea: tarea, tareas: tareas),
      ),
    );
    if (!mounted || resultado == null) return;
    await modificar(
      () => db.guardar('tareas', {
        'titulo': resultado.titulo,
        'hora': resultado.hora,
      }, id: tarea?.id),
    );
  }

  Future<void> abrirFormularioHabito({Habito? habito}) async {
    final resultado = await Navigator.of(context).push<DatosHabito>(
      MaterialPageRoute(builder: (_) => FormularioHabito(habito: habito)),
    );
    if (!mounted || resultado == null) return;
    await modificar(
      () => db.guardar('habitos', {
        'nombre': resultado.nombre,
        'meta': resultado.meta,
        'unidad': resultado.unidad,
        'progreso': (habito?.progreso ?? 0).clamp(0, resultado.meta),
      }, id: habito?.id),
    );
  }

  Future<void> abrirFormularioEvento({Evento? evento}) async {
    final resultado = await Navigator.of(context).push<DatosEvento>(
      MaterialPageRoute(
        builder: (_) => FormularioEvento(evento: evento, eventos: eventos),
      ),
    );
    if (!mounted || resultado == null) return;
    await modificar(
      () => db.guardar('eventos', {
        'titulo': resultado.titulo,
        'fecha': resultado.fecha.toIso8601String(),
        'hora': resultado.hora,
      }, id: evento?.id),
    );
  }

  void progresoHabito(Habito habito, int progreso) {
    modificar(
      () => db.guardar('habitos', {
        'progreso': progreso.clamp(0, habito.meta),
      }, id: habito.id),
    );
  }

  void aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      paginaInicio(),
      paginaTareas(),
      paginaCalendario(),
      paginaHabitos(),
      paginaPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LifeSync',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : errorCarga != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorCarga!),
                  TextButton(
                    onPressed: cargarDatos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : AbsorbPointer(
              absorbing: guardando,
              child: Stack(
                children: [
                  IndexedStack(index: pagina, children: pantallas),
                  if (guardando) const LinearProgressIndicator(),
                ],
              ),
            ),
      floatingActionButton: cargando || guardando || errorCarga != null
          ? null
          : switch (pagina) {
              1 => FloatingActionButton.extended(
                onPressed: () => abrirFormularioTarea(),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Nueva tarea'),
              ),
              2 => FloatingActionButton.extended(
                onPressed: () => abrirFormularioEvento(),
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Nuevo evento'),
              ),
              3 => FloatingActionButton.extended(
                onPressed: () => abrirFormularioHabito(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo hábito'),
              ),
              _ => null,
            },
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: (valor) => setState(() => pagina = valor),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_rounded),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_rounded),
            label: 'Hábitos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget paginaInicio() {
    final completadas = tareas.where((tarea) => tarea.completada).length;
    final habitosCompletos = habitos
        .where((habito) => habito.completado)
        .length;
    final pendientes = tareas.where((tarea) => !tarea.completada).toList();
    final eventosHoy = eventos
        .where((evento) => mismaFecha(evento.fecha, DateTime.now()))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Text(
          '¡Hola, ${widget.usuario.nombre.split(' ').first}! 👋',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tu organización personal, siempre contigo',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7A3CFF), Color(0xFF1677FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu progreso de hoy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  indicadorResumen('$completadas/${tareas.length}', 'Tareas'),
                  indicadorResumen(
                    '$habitosCompletos/${habitos.length}',
                    'Hábitos',
                  ),
                  indicadorResumen('${eventosHoy.length}', 'Eventos'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FestivosPanel(vista: VistaFestivos.proximo, fecha: DateTime.now()),
        const SizedBox(height: 18),
        encabezadoSeccion(
          'Tareas pendientes',
          () => setState(() => pagina = 1),
        ),
        if (pendientes.isEmpty)
          tarjetaVacia('No tienes tareas pendientes', Icons.task_alt_rounded)
        else
          ...pendientes.take(3).map(tarjetaTarea),
        const SizedBox(height: 18),
        encabezadoSeccion('Hábitos', () => setState(() => pagina = 3)),
        ...habitos.take(3).map(tarjetaHabitoCompacta),
        const SizedBox(height: 18),
        encabezadoSeccion('Eventos de hoy', () => setState(() => pagina = 2)),
        if (eventosHoy.isEmpty)
          tarjetaVacia('No hay eventos para hoy', Icons.event_available_rounded)
        else
          ...eventosHoy.map(tarjetaEvento),
      ],
    );
  }

  Widget paginaTareas() {
    final pendientes = tareas.where((tarea) => !tarea.completada).toList();
    final completadas = tareas.where((tarea) => tarea.completada).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      children: [
        tituloSeccion('Mis tareas'),
        const Text(
          'Crea, edita, completa y elimina tus tareas.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 18),
        if (pendientes.isEmpty)
          tarjetaVacia('No hay tareas pendientes', Icons.task_alt_rounded)
        else ...[
          subtitulo('Pendientes'),
          ...pendientes.map(tarjetaTarea),
        ],
        if (completadas.isNotEmpty) ...[
          const SizedBox(height: 18),
          subtitulo('Completadas'),
          ...completadas.map(tarjetaTarea),
        ],
      ],
    );
  }

  Widget paginaCalendario() {
    final lista = [...eventos]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      children: [
        tituloSeccion('Calendario'),
        const Text(
          'Consulta tus próximos eventos y agrega recordatorios básicos.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E55D9), Color(0xFF6D37E8)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreMes(DateTime.now().month),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DateTime.now().day} de ${nombreMes(DateTime.now().month)} de ${DateTime.now().year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FestivosPanel(vista: VistaFestivos.calendario, fecha: DateTime.now()),
        const SizedBox(height: 20),
        subtitulo('Próximos eventos'),
        if (lista.isEmpty)
          tarjetaVacia('Todavía no agregas eventos', Icons.event_busy_rounded)
        else
          ...lista.map(tarjetaEvento),
      ],
    );
  }

  Widget paginaHabitos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis hábitos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const Text(
          'Agrega hábitos, define una meta y registra tu progreso.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 18),
        if (habitos.isEmpty)
          tarjetaVacia(
            'Todavía no agregas hábitos',
            Icons.local_fire_department_rounded,
          )
        else
          ...habitos.map(tarjetaHabito),
      ],
    );
  }

  Future<void> editarPerfil() async {
    if (guardando || cerrandoSesion) return;
    final actualizado = await Navigator.of(context).push<Usuario>(
      MaterialPageRoute(
        builder: (_) => EditarPerfilPage(usuario: widget.usuario),
      ),
    );
    if (!mounted || actualizado == null) return;
    widget.onPerfilActualizado(actualizado);
    aviso('Perfil actualizado');
  }

  Widget paginaPerfil() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        tituloSeccion('Perfil'),
        if (widget.usuario.esAdmin)
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Panel administrador'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AdminPage())),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                AvatarPerfil(
                  nombre: widget.usuario.nombre,
                  foto: widget.usuario.foto,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.usuario.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.usuario.correo,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar perfil'),
                subtitle: const Text('Cambia tu nombre y foto'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: guardando || cerrandoSesion ? null : editarPerfil,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Recordatorios de tareas y eventos'),
                subtitle: Text(estadoNotificaciones),
                onTap: configurarRecordatorios,
                trailing: IconButton(
                  tooltip: 'Ajustes de notificaciones',
                  onPressed: abrirAjustesNotificaciones,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Acerca de LifeSync'),
                subtitle: const Text('Organización personal en tu móvil'),
                onTap: mostrarAcercaDe,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: confirmarCerrarSesion,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF6B85),
            side: const BorderSide(color: Color(0xFFFF6B85)),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget indicadorResumen(String valor, String etiqueta) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        Text(etiqueta, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget encabezadoSeccion(String titulo, VoidCallback accion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(onPressed: accion, child: const Text('Ver todo')),
        ],
      ),
    );
  }

  Widget tituloSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    );
  }

  Widget subtitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget tarjetaVacia(String texto, IconData icono) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icono, size: 36, color: Colors.white38),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaTarea(Tarea tarea) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: tarea.completada,
              onChanged: (valor) => modificar(
                () => db.guardar('tareas', {
                  'completada': valor == true ? 1 : 0,
                }, id: tarea.id),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea.titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: tarea.completada
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tarea.hora} · ${tarea.completada ? 'Completada' : 'Pendiente'}',
                    style: TextStyle(
                      color: tarea.completada
                          ? const Color(0xFF4ADE80)
                          : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (accion) {
                if (accion == 'editar') abrirFormularioTarea(tarea: tarea);
                if (accion == 'eliminar') {
                  modificar(() => db.eliminar('tareas', tarea.id));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaHabitoCompacta(Habito habito) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF332368),
          child: Icon(
            habito.completado
                ? Icons.check_rounded
                : Icons.local_fire_department_rounded,
            color: habito.completado
                ? const Color(0xFF4ADE80)
                : const Color(0xFFA78BFA),
          ),
        ),
        title: Text(habito.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${habito.progreso}/${habito.meta} ${habito.unidad}'),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: habito.porcentaje),
          ],
        ),
      ),
    );
  }

  Widget tarjetaHabito(Habito habito) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  habito.completado
                      ? Icons.check_circle_rounded
                      : Icons.local_fire_department_rounded,
                  color: habito.completado
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFA78BFA),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habito.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (accion) {
                    if (accion == 'editar') {
                      abrirFormularioHabito(habito: habito);
                    }
                    if (accion == 'eliminar') {
                      modificar(() => db.eliminar('habitos', habito.id));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            Text(
              '${habito.progreso}/${habito.meta} ${habito.unidad}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: habito.porcentaje,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: habito.progreso <= 0
                      ? null
                      : () => progresoHabito(habito, habito.progreso - 1),
                  child: const Text('-1'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: habito.completado
                      ? null
                      : () => progresoHabito(habito, habito.progreso + 1),
                  child: const Text('+1'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => progresoHabito(
                    habito,
                    habito.completado ? 0 : habito.meta,
                  ),
                  child: Text(habito.completado ? 'Reiniciar' : 'Completar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaEvento(Evento evento) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2A205A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${evento.fecha.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                nombreMesCorto(evento.fecha.month),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        title: Text(evento.titulo),
        subtitle: Text(
          '${evento.hora} · ${evento.completado ? 'Completado' : 'Pendiente'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (accion) {
            if (accion == 'completar') {
              modificar(
                () => db.guardar('eventos', {
                  'completado': evento.completado ? 0 : 1,
                }, id: evento.id),
              );
            }
            if (accion == 'editar') abrirFormularioEvento(evento: evento);
            if (accion == 'eliminar') {
              modificar(() => db.eliminar('eventos', evento.id));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'completar',
              child: Text(evento.completado ? 'Marcar pendiente' : 'Completar'),
            ),
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }

  void mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: 'LifeSync',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.sync_rounded,
        size: 42,
        color: Color(0xFF8B5CFF),
      ),
      children: const [
        Text(
          'LifeSync organiza tus tareas, hábitos y eventos con almacenamiento local en este dispositivo.',
        ),
      ],
    );
  }

  Future<void> confirmarCerrarSesion() async {
    if (cerrandoSesion || guardando) return;
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir de LifeSync?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || cerrar != true) return;
    setState(() {
      cerrandoSesion = true;
      guardando = true;
    });
    try {
      await notificaciones.cancelarTodos();
      if (mounted) await widget.onCerrarSesion();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        cerrandoSesion = false;
        guardando = false;
      });
      aviso('No se pudo cerrar tu sesión. Intenta de nuevo.');
    }
  }

  bool mismaFecha(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String nombreMes(int mes) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes - 1];
  }

  String nombreMesCorto(int mes) {
    const meses = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return meses[mes - 1];
  }
}

class DatosTarea {
  const DatosTarea(this.titulo, this.hora);
  final String titulo;
  final String hora;
}

class FormularioTarea extends StatefulWidget {
  const FormularioTarea({super.key, this.tarea, this.tareas = const []});
  final List<Tarea> tareas;
  final Tarea? tarea;

  @override
  State<FormularioTarea> createState() => _FormularioTareaState();
}

class _FormularioTareaState extends State<FormularioTarea> {
  late final TextEditingController titulo;
  late final TextEditingController hora;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    titulo = TextEditingController(text: widget.tarea?.titulo ?? '');
    hora = TextEditingController(text: widget.tarea?.hora ?? '');
  }

  @override
  void dispose() {
    titulo.dispose();
    hora.dispose();
    super.dispose();
  }

  void guardar() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    Navigator.of(context).pop(DatosTarea(titulo.text.trim(), hora.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tarea == null ? 'Nueva tarea' : 'Editar tarea'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titulo,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tarea',
                prefixIcon: Icon(Icons.task_alt_rounded),
              ),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Escribe un nombre'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: hora,
              readOnly: true,
              onTap: () async {
                final minutos = minutosDeHora(hora.text);
                final elegida = await showTimePicker(
                  context: context,
                  initialTime: minutos == null
                      ? TimeOfDay.now()
                      : TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60),
                  initialEntryMode: TimePickerEntryMode.dialOnly,
                  helpText: 'Selecciona la hora',
                  cancelText: 'Cancelar',
                  confirmText: 'Aceptar',
                );
                if (elegida != null && mounted) {
                  hora.text =
                      '${elegida.hour.toString().padLeft(2, '0')}:${elegida.minute.toString().padLeft(2, '0')}';
                }
              },
              decoration: const InputDecoration(
                labelText: 'Hora',
                hintText: 'Toca para elegir la hora',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              validator: (valor) {
                final minutos = minutosDeHora(valor ?? '');
                if (minutos == null) return 'Selecciona una hora';
                if (widget.tareas.any(
                  (otro) =>
                      otro.id != widget.tarea?.id &&
                      minutosDeHora(otro.hora) == minutos,
                )) {
                  return 'Ya tienes una tarea a esa hora';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar tarea'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatosHabito {
  const DatosHabito(this.nombre, this.meta, this.unidad);
  final String nombre;
  final int meta;
  final String unidad;
}

class FormularioHabito extends StatefulWidget {
  const FormularioHabito({super.key, this.habito});
  final Habito? habito;

  @override
  State<FormularioHabito> createState() => _FormularioHabitoState();
}

class _FormularioHabitoState extends State<FormularioHabito> {
  late final TextEditingController nombre;
  late final TextEditingController meta;
  late final TextEditingController unidad;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nombre = TextEditingController(text: widget.habito?.nombre ?? '');
    meta = TextEditingController(text: widget.habito?.meta.toString() ?? '');
    unidad = TextEditingController(text: widget.habito?.unidad ?? 'veces');
  }

  @override
  void dispose() {
    nombre.dispose();
    meta.dispose();
    unidad.dispose();
    super.dispose();
  }

  void guardar() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      DatosHabito(
        nombre.text.trim(),
        int.parse(meta.text.trim()),
        unidad.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habito == null ? 'Nuevo hábito' : 'Editar hábito'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: nombre,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del hábito',
                prefixIcon: Icon(Icons.local_fire_department_rounded),
              ),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Escribe un nombre'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: meta,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Meta',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (valor) {
                final numero = int.tryParse(valor?.trim() ?? '');
                return numero == null || numero <= 0
                    ? 'Escribe una meta válida'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: unidad,
              onFieldSubmitted: (_) => guardar(),
              decoration: const InputDecoration(
                labelText: 'Unidad',
                hintText: 'vasos, minutos, veces...',
                prefixIcon: Icon(Icons.straighten_rounded),
              ),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Escribe una unidad'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar hábito'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatosEvento {
  const DatosEvento(this.titulo, this.fecha, this.hora);
  final String titulo;
  final DateTime fecha;
  final String hora;
}

class FormularioEvento extends StatefulWidget {
  const FormularioEvento({super.key, this.evento, this.eventos = const []});
  final List<Evento> eventos;
  final Evento? evento;

  @override
  State<FormularioEvento> createState() => _FormularioEventoState();
}

class _FormularioEventoState extends State<FormularioEvento> {
  late final TextEditingController titulo;
  late final TextEditingController hora;
  late DateTime fecha;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    titulo = TextEditingController(text: widget.evento?.titulo ?? '');
    hora = TextEditingController(text: widget.evento?.hora ?? '');
    fecha = widget.evento?.fecha ?? DateTime.now();
  }

  @override
  void dispose() {
    titulo.dispose();
    hora.dispose();
    super.dispose();
  }

  Future<void> seleccionarFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (elegida != null && mounted) setState(() => fecha = elegida);
  }

  void guardar() {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop(DatosEvento(titulo.text.trim(), fecha, hora.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.evento == null ? 'Nuevo evento' : 'Editar evento'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titulo,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del evento',
                prefixIcon: Icon(Icons.event_note_rounded),
              ),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Escribe un nombre'
                  : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: const Color(0xFF12182A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Fecha'),
              subtitle: Text('${fecha.day}/${fecha.month}/${fecha.year}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: seleccionarFecha,
            ),
            FestivosPanel(vista: VistaFestivos.aviso, fecha: fecha),
            const SizedBox(height: 16),
            TextFormField(
              controller: hora,
              readOnly: true,
              onTap: () async {
                final minutos = minutosDeHora(hora.text);
                final elegida = await showTimePicker(
                  context: context,
                  initialTime: minutos == null
                      ? TimeOfDay.now()
                      : TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60),
                  initialEntryMode: TimePickerEntryMode.dialOnly,
                  helpText: 'Selecciona la hora',
                  cancelText: 'Cancelar',
                  confirmText: 'Aceptar',
                );
                if (elegida != null && mounted) {
                  hora.text =
                      '${elegida.hour.toString().padLeft(2, '0')}:${elegida.minute.toString().padLeft(2, '0')}';
                }
              },
              decoration: const InputDecoration(
                labelText: 'Hora',
                hintText: 'Toca para elegir la hora',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              validator: (valor) {
                final minutos = minutosDeHora(valor ?? '');
                if (minutos == null) return 'Selecciona una hora';
                if (widget.eventos.any(
                  (otro) =>
                      otro.id != widget.evento?.id &&
                      mismoDia(otro.fecha, fecha) &&
                      minutosDeHora(otro.hora) == minutos,
                )) {
                  return 'Ya tienes un evento en esa fecha y hora';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar evento'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
