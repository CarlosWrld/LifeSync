import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:appmovil/modelos/usuario.dart';
import 'package:appmovil/pantallas/editar_perfil_page.dart';
import 'package:appmovil/servicios/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PerfilDatabaseFake implements DatabaseHelper {
  int guardados = 0;
  bool falla = false;
  Usuario? resultado;
  Completer<void>? pendiente;

  @override
  Future<Usuario> actualizarPerfil({
    required int usuarioId,
    required String nombre,
    required Uint8List? foto,
  }) async {
    guardados++;
    if (pendiente != null) await pendiente!.future;
    if (falla) throw StateError('Sin espacio');
    return resultado = Usuario(
      id: usuarioId,
      nombre: nombre.trim(),
      correo: 'ana@example.com',
      foto: foto,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final foto = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQFwcdLl4wmwAAAAtJREFUCNdjYAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
  );
  late PerfilDatabaseFake db;
  Usuario? devuelto;

  Future<void> abrir(
    WidgetTester tester, {
    Uint8List? inicial,
    Future<Uint8List?> Function()? seleccionar,
  }) async {
    db = PerfilDatabaseFake();
    devuelto = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                devuelto = await Navigator.of(context).push<Usuario>(
                  MaterialPageRoute(
                    builder: (_) => EditarPerfilPage(
                      usuario: Usuario(
                        id: 7,
                        nombre: 'Ana',
                        correo: 'ana@example.com',
                        foto: inicial,
                      ),
                      database: db,
                      seleccionarFoto: seleccionar,
                    ),
                  ),
                );
              },
              child: const Text('Abrir perfil'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir perfil'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Valida el nombre y devuelve el perfil guardado con la foto original',
    (tester) async {
      await abrir(tester, inicial: foto);
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu nombre'), findsOneWidget);
      expect(db.guardados, 0);
      await tester.enterText(find.byType(TextFormField), '  Ana López  ');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(devuelto?.nombre, 'Ana López');
      expect(devuelto?.foto, orderedEquals(foto));
      expect(find.text('Abrir perfil'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancelar descarta el nombre y quitar foto sin guardar', (
    tester,
  ) async {
    await abrir(tester, inicial: foto);
    await tester.enterText(find.byType(TextFormField), 'Otro nombre');
    await tester.tap(find.text('Quitar foto'));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(db.guardados, 0);
    expect(devuelto, isNull);
  });

  testWidgets('Cancelar la galería conserva la foto; quitarla guarda null', (
    tester,
  ) async {
    await abrir(tester, inicial: foto, seleccionar: () async => null);
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Quitar foto'));
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(devuelto?.nombre, 'Ana');
    expect(devuelto?.foto, isNull);
  });

  testWidgets('Elegir foto muestra vista previa y guarda sus bytes', (
    tester,
  ) async {
    await abrir(tester, seleccionar: () async => foto);
    await tester.runAsync(() async {
      final boton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Elegir foto'),
      );
      // Espera la decodificación real, fuera del reloj simulado del test.
      await (boton.onPressed! as Future<void> Function())();
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(devuelto?.foto, orderedEquals(foto));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Error de selección conserva la foto anterior', (tester) async {
    await abrir(
      tester,
      inicial: foto,
      seleccionar: () async => Uint8List(Usuario.maxFotoBytes + 1),
    );
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.text('Elige una foto válida de hasta 1 MB.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(db.guardados, 0);
  });

  testWidgets('Bloquea guardados duplicados y permite reintentar si falla', (
    tester,
  ) async {
    await abrir(tester);
    db.falla = true;
    db.pendiente = Completer<void>();
    await tester.enterText(find.byType(TextFormField), 'Nombre nuevo');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(db.guardados, 1);
    db.pendiente!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo guardar el perfil. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Nombre nuevo'), findsOneWidget);
    db.falla = false;
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(devuelto?.nombre, 'Nombre nuevo');
  });
}
