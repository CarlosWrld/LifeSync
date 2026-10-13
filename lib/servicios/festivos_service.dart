import 'dart:convert';
import 'package:http/http.dart' as http;
import '../modelos/festivo.dart';

class FestivosService {
  FestivosService({http.Client? client}) : _client = client ?? http.Client();
  static final instance = FestivosService();
  final http.Client _client;
  final _cache = <int, ({DateTime guardado, List<Festivo> datos})>{};
  final _pendientes = <int, Future<List<Festivo>>>{};

  Future<List<Festivo>> obtener(int year) {
    final anterior = _cache[year];
    if (anterior != null &&
        DateTime.now().difference(anterior.guardado) <
            const Duration(hours: 12)) {
      return Future.value(anterior.datos);
    }
    return _pendientes.putIfAbsent(
      year,
      () => _consultar(year).whenComplete(() => _pendientes.remove(year)),
    );
  }

  Future<List<Festivo>> _consultar(int year) async {
    final respuesta = await _client
        .get(Uri.https('date.nager.at', '/api/v3/PublicHolidays/$year/MX'))
        .timeout(const Duration(seconds: 12));
    if (respuesta.statusCode != 200) {
      throw const FormatException('Servicio de festivos no disponible');
    }
    final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
    if (json is! List) {
      throw const FormatException('Respuesta de festivos inválida');
    }
    final datos = <Festivo>[];
    for (final item in json) {
      if (item is! Map<String, dynamic> ||
          item['countryCode'] != 'MX' ||
          item['types'] is! List) {
        throw const FormatException('Respuesta de festivos inválida');
      }
      // Mostrar únicamente festivos públicos nacionales, no observancias regionales.
      if (item['global'] != true || !(item['types'] as List).contains('Public')) {
        continue;
      }
      final festivo = Festivo.fromJson(item);
      if (festivo.fecha.year != year) {
        throw const FormatException('Año incorrecto');
      }
      datos.add(festivo);
    }
    datos.sort((a, b) => a.fecha.compareTo(b.fecha));
    final resultado = List<Festivo>.unmodifiable(datos);
    _cache[year] = (guardado: DateTime.now(), datos: resultado);
    return resultado;
  }

  Future<List<Festivo>> proximos(DateTime fecha) async {
    final hoy = DateTime(fecha.year, fecha.month, fecha.day);
    final actuales = (await obtener(
      hoy.year,
    )).where((f) => !f.fecha.isBefore(hoy)).toList();
    if (actuales.isNotEmpty) return actuales;
    return obtener(hoy.year + 1);
  }

  void close() => _client.close();
}
