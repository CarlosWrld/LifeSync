# API externa de días festivos

LifeSync consume Nager.Date mediante HTTP GET:

`https://date.nager.at/api/v3/PublicHolidays/{año}/MX`

La consulta real para México de 2026 respondió HTTP 200 durante la integración.
No se envían correos, contraseñas ni información de las tareas: solo año y país.

- `lib/servicios/festivos_service.dart`: petición HTTP, lectura del JSON UTF-8,
  validación, filtro de festivos públicos nacionales y orden por fecha.
- `lib/modelos/festivo.dart`: modelo con fecha y nombre en español (`localName`).
- `lib/pantallas/festivos_panel.dart`: próximo festivo en Inicio, listado por año
  en Calendario y aviso informativo en el formulario de eventos.

El próximo festivo incluye el día actual y consulta el siguiente año si hace falta.
Calendario permite consultar desde el año anterior hasta dos años después del actual.
Los resultados se reutilizan en memoria durante 12 horas; no hay caché persistente
sin conexión. Las solicitudes simultáneas del mismo año comparten la petición.
La consulta tiene un límite de espera de 12 segundos y muestra Reintentar si falla.
Un error de red no impide guardar tareas ni eventos. Los festivos no se insertan
como eventos personales ni ocupan horarios.

Para demostrar la integración: abrir Calendario, cambiar de año y crear un evento
en una de las fechas mostradas. Para probar el error, reiniciar la app sin conexión.

Documentación del proveedor: https://date.nager.at/Api

Pruebas: `flutter test test/festivos_test.dart`.
