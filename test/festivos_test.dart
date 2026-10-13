import 'dart:convert';
import 'package:appmovil/servicios/festivos_service.dart';
import 'package:appmovil/pantallas/festivos_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> festivo(String fecha, {bool nacional = true}) => {
  'date': fecha,
  'localName': 'Año Nuevo',
  'countryCode': 'MX',
  'global': nacional,
  'types': ['Public'],
};
http.Response respuesta(List<Object> datos) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), 200);

void main() {
  test(
    'Consulta México, filtra regionales, ordena y reutiliza la petición',
    () async {
      var llamadas = 0;
      final service = FestivosService(
        client: MockClient((request) async {
          llamadas++;
          expect(
            request.url.toString(),
            'https://date.nager.at/api/v3/PublicHolidays/2026/MX',
          );
          return respuesta([
            festivo('2026-09-16'),
            festivo('2026-01-01'),
            festivo('2026-03-01', nacional: false),
          ]);
        }),
      );
      addTearDown(service.close);
      final resultados = await Future.wait([
        service.obtener(2026),
        service.obtener(2026),
      ]);
      expect(resultados.first, hasLength(2));
      expect(resultados.first.first.nombre, 'Año Nuevo');
      expect(resultados.first.first.fecha, DateTime(2026, 1, 1));
      await service.obtener(2026);
      expect(llamadas, 1);
    },
  );
  test('Incluye hoy y busca el siguiente año al terminar diciembre', () async {
    final service = FestivosService(
      client: MockClient((request) async {
        final year = int.parse(request.url.pathSegments[3]);
        return respuesta([festivo('$year-01-01')]);
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.proximos(DateTime(2026, 1, 1, 20))).first.fecha,
      DateTime(2026, 1, 1),
    );
    expect(
      (await service.proximos(DateTime(2026, 12, 31))).first.fecha,
      DateTime(2027, 1, 1),
    );
  });
  test('Un error no se guarda en caché y permite reintentar', () async {
    var llamadas = 0;
    final service = FestivosService(
      client: MockClient(
        (_) async => ++llamadas == 1
            ? http.Response('error', 503)
            : respuesta([festivo('2026-01-01')]),
      ),
    );
    addTearDown(service.close);
    await expectLater(service.obtener(2026), throwsFormatException);
    expect(await service.obtener(2026), hasLength(1));
  });
  test('Rechaza fechas inválidas y respuestas inesperadas', () async {
    for (final body in [
      '{}',
      jsonEncode([festivo('2026-02-31')]),
    ]) {
      final service = FestivosService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(service.obtener(2026), throwsFormatException);
      service.close();
    }
  });
  testWidgets('El aviso cambia al elegir otra fecha', (tester) async {
    final service = FestivosService(
      client: MockClient((_) async => respuesta([festivo('2026-01-01')])),
    );
    addTearDown(service.close);
    Widget panel(DateTime fecha) => MaterialApp(
      home: Scaffold(
        body: FestivosPanel(
          vista: VistaFestivos.aviso,
          fecha: fecha,
          service: service,
        ),
      ),
    );
    await tester.pumpWidget(panel(DateTime(2026, 1, 1)));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Esta fecha coincide con un día festivo. Puedes guardar el evento.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(panel(DateTime(2026, 1, 2)));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay festivos nacionales reportados para esta fecha.'),
      findsOneWidget,
    );
  });
}
