import 'dart:async';

import 'package:appmovil/main.dart';
import 'package:appmovil/modelos/usuario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Espera la sesión sin mostrar el acceso y abre Inicio', (tester) async {
    final pendiente = Completer<Usuario?>();
    await tester.pumpWidget(MyApp(restaurarSesion: () => pendiente.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(RegistroPage), findsNothing);
    pendiente.complete(Usuario(id: 42, nombre: 'Ana', correo: 'ana@example.com'));
    await tester.pumpAndSettle();
    expect(find.byType(InicioTelefono), findsOneWidget);
    expect(find.byType(RegistroPage), findsNothing);
    expect(tester.widget<InicioTelefono>(find.byType(InicioTelefono)).usuario.id, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sin sesión guardada abre el formulario de acceso', (tester) async {
    await tester.pumpWidget(MyApp(restaurarSesion: () async => null));
    await tester.pumpAndSettle();
    expect(find.byType(RegistroPage), findsOneWidget);
    expect(find.byType(InicioTelefono), findsNothing);
  });

  testWidgets('Un error al restaurar permite reintentar sin asumir cierre de sesión', (tester) async {
    var intentos = 0;
    await tester.pumpWidget(MyApp(restaurarSesion: () async {
      if (++intentos == 1) throw StateError('Base temporalmente ocupada');
      return null;
    }));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo recuperar tu sesión.'), findsOneWidget);
    expect(find.byType(RegistroPage), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(intentos, 2);
    expect(find.byType(RegistroPage), findsOneWidget);
  });
}
