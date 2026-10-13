import 'package:flutter/material.dart';
import '../modelos/usuario.dart';
import '../servicios/database_helper.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<Usuario>> usuarios;

  @override
  void initState() {
    super.initState();
    usuarios = DatabaseHelper.instance.obtenerUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel administrador')),
      body: FutureBuilder<List<Usuario>>(
        future: usuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final denied = snapshot.error is AccesoDenegadoException;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    denied
                        ? 'Acceso exclusivo para administradores'
                        : 'No se pudieron cargar los usuarios',
                  ),
                  if (!denied)
                    TextButton(
                      onPressed: () => setState(
                        () => usuarios = DatabaseHelper.instance
                            .obtenerUsuarios(),
                      ),
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            );
          }
          final lista = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Usuarios registrados (${lista.length})',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              for (final usuario in lista)
                Card(
                  child: ListTile(
                    leading: Icon(
                      usuario.esAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(usuario.nombre),
                    subtitle: Text(
                      '${usuario.correo}\nRol: ${usuario.rol} · Proveedor: ${usuario.proveedor}',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
