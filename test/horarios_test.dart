import 'package:appmovil/main.dart';
import 'package:appmovil/modelos/tarea.dart';
import 'package:appmovil/modelos/evento.dart';
import 'package:appmovil/servicios/horarios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Horas equivalentes y límites de medianoche y mediodía', () {
    expect(minutosDeHora('6:30 PM'), minutosDeHora('18:30'));
    expect(minutosDeHora('12:00 a. m.'), 0);
    expect(minutosDeHora('12:00 PM'), 720);
    expect(minutosDeHora('24:00'), isNull);
    expect(minutosDeHora('9:60'), isNull);
  });

  testWidgets('Tareas: reloj, cancelar y conflicto al editar', (tester) async {
    final tarea = Tarea(id: 1, titulo: 'Leer', hora: '18:30');
    await tester.pumpWidget(
      MaterialApp(
        home: FormularioTarea(
          tarea: tarea,
          tareas: [
            tarea,
            Tarea(id: 2, titulo: 'Estudiar', hora: '6:30 PM'),
          ],
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextFormField, '18:30'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialEntryMode,
      TimePickerEntryMode.dialOnly,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('18:30'), findsOneWidget);
    await tester.tap(find.text('Guardar tarea'));
    await tester.pumpAndSettle();
    expect(find.text('Ya tienes una tarea a esa hora'), findsOneWidget);
  });

  testWidgets('Eventos: conflicto por día, excluyendo el propio evento', (
    tester,
  ) async {
    final evento = Evento(
      id: 1,
      titulo: 'Clase',
      fecha: DateTime(2026, 9, 23),
      hora: '10:00',
    );
    final otro = Evento(
      id: 2,
      titulo: 'Cita',
      fecha: DateTime(2026, 9, 23, 15),
      hora: '10:00 AM',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormularioEvento(evento: evento, eventos: [evento, otro]),
      ),
    );
    await tester.tap(find.text('Guardar evento'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ya tienes un evento en esa fecha y hora'),
      findsOneWidget,
    );
    otro.fecha = DateTime(2026, 9, 24);
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isTrue);
    await tester.pump();
    expect(find.text('Ya tienes un evento en esa fecha y hora'), findsNothing);
  });
}
