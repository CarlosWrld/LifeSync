import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appmovil/main.dart';
import 'package:appmovil/pantallas/admin_page.dart';

void main() {
  testWidgets('Login y registro conservan tema y validan los campos', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(restaurarSesion: () async => null));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Nombre completo'), findsNothing);
    await tester.ensureVisible(find.text('Entrar a LifeSync'));
    await tester.tap(find.text('Entrar a LifeSync'));
    await tester.pump();
    expect(find.text('Escribe tu correo'), findsOneWidget);
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El panel rechaza una sesión no autenticada', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPage()));
    await tester.pumpAndSettle();
    expect(find.text('Acceso exclusivo para administradores'), findsOneWidget);
  });
}
