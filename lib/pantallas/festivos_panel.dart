import 'package:flutter/material.dart';
import '../modelos/festivo.dart';
import '../servicios/festivos_service.dart';
import '../servicios/horarios.dart';

enum VistaFestivos { proximo, calendario, aviso }

class FestivosPanel extends StatefulWidget {
  const FestivosPanel({
    super.key,
    required this.vista,
    required this.fecha,
    this.service,
  });
  final VistaFestivos vista;
  final DateTime fecha;
  final FestivosService? service;
  @override
  State<FestivosPanel> createState() => _FestivosPanelState();
}

class _FestivosPanelState extends State<FestivosPanel> {
  late Future<List<Festivo>> datos;
  late int year;
  FestivosService get service => widget.service ?? FestivosService.instance;

  @override
  void initState() {
    super.initState();
    year = widget.fecha.year;
    cargar();
  }

  void cargar() {
    datos = widget.vista == VistaFestivos.proximo
        ? service.proximos(widget.fecha)
        : service.obtener(year);
  }

  @override
  void didUpdateWidget(covariant FestivosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mismoDia(oldWidget.fecha, widget.fecha) ||
        oldWidget.vista != widget.vista ||
        oldWidget.service != widget.service) {
      year = widget.fecha.year;
      cargar();
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF182331),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (widget.vista) {
              VistaFestivos.proximo => 'Próximo día festivo · México',
              VistaFestivos.calendario => 'Días festivos · México',
              VistaFestivos.aviso => 'Festivos en la fecha elegida',
            },
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF70DFCE),
            ),
          ),
          if (widget.vista == VistaFestivos.calendario)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Año anterior',
                  onPressed: year > widget.fecha.year - 1
                      ? () => setState(() {
                          year--;
                          cargar();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$year'),
                IconButton(
                  tooltip: 'Año siguiente',
                  onPressed: year < widget.fecha.year + 2
                      ? () => setState(() {
                          year++;
                          cargar();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          const SizedBox(height: 8),
          FutureBuilder<List<Festivo>>(
            future: datos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Text('Consultando días festivos…');
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vista == VistaFestivos.aviso
                          ? 'No pudimos comprobar los festivos. Puedes guardar tu evento de todos modos.'
                          : 'No pudimos consultar los festivos. Revisa tu conexión.',
                    ),
                    TextButton(
                      onPressed: () => setState(cargar),
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              final lista = snapshot.data ?? [];
              final visibles = switch (widget.vista) {
                VistaFestivos.proximo => lista.take(1).toList(),
                VistaFestivos.calendario => lista,
                VistaFestivos.aviso =>
                  lista.where((f) => mismoDia(f.fecha, widget.fecha)).toList(),
              };
              if (visibles.isEmpty) {
                return Text(
                  widget.vista == VistaFestivos.aviso
                      ? 'No hay festivos nacionales reportados para esta fecha.'
                      : 'No hay festivos reportados para este período.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.vista == VistaFestivos.aviso)
                    const Text(
                      'Esta fecha coincide con un día festivo. Puedes guardar el evento.',
                    ),
                  for (final f in visibles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.celebration_outlined,
                            color: Color(0xFF70DFCE),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${f.nombre}\n${f.fecha.day}/${f.fecha.month}/${f.fecha.year}',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Fuente: Nager.Date',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
