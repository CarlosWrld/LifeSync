import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../modelos/usuario.dart';
import '../servicios/database_helper.dart';

class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({
    super.key,
    required this.nombre,
    required this.foto,
    this.radio = 34,
  });

  final String nombre;
  final Uint8List? foto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    final iniciales = partes.first.isEmpty
        ? 'LS'
        : '${partes.first.characters.first}${partes.length > 1 ? partes.last.characters.first : ''}'
              .toUpperCase();
    final respaldo = Center(
      child: Text(
        iniciales,
        style: TextStyle(
          fontSize: radio * .65,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    return Semantics(
      label: 'Foto de perfil',
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radio * 2,
          child: ColoredBox(
            color: const Color(0xFF7145FF),
            child: foto == null
                ? respaldo
                : Image.memory(
                    foto!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, error, stackTrace) => respaldo,
                  ),
          ),
        ),
      ),
    );
  }
}

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({
    super.key,
    required this.usuario,
    this.database,
    this.seleccionarFoto,
  });

  final Usuario usuario;
  final DatabaseHelper? database;
  final Future<Uint8List?> Function()? seleccionarFoto;

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nombre;
  Uint8List? foto;
  bool guardando = false;
  bool eligiendo = false;
  String? error;

  bool get ocupado => guardando || eligiendo;

  @override
  void initState() {
    super.initState();
    nombre = TextEditingController(text: widget.usuario.nombre);
    foto = widget.usuario.foto;
  }

  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  Future<Uint8List?> elegirDeGaleria() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (archivo == null) return null;
    if (await archivo.length() > Usuario.maxFotoBytes) {
      throw const FormatException('Elige una foto de hasta 1 MB.');
    }
    return archivo.readAsBytes();
  }

  Future<void> cambiarFoto() async {
    if (ocupado) return;
    setState(() {
      eligiendo = true;
      error = null;
    });
    try {
      final elegida = await (widget.seleccionarFoto ?? elegirDeGaleria)();
      if (elegida == null) return;
      if (elegida.isEmpty || elegida.length > Usuario.maxFotoBytes) {
        throw const FormatException('Elige una foto válida de hasta 1 MB.');
      }
      // Comprueba que Flutter puede mostrarla antes de reemplazar la foto.
      final codec = await ui.instantiateImageCodec(
        elegida,
        targetWidth: 1024,
        targetHeight: 1024,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => foto = elegida);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => error =
              e.code == 'photo_access_denied' ||
                  e.code == 'photo_access_restricted'
              ? 'Permite el acceso a tus fotos desde los ajustes del teléfono.'
              : 'No se pudo abrir la galería. Intenta de nuevo.',
        );
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo leer la foto. Prueba con otra imagen.',
        );
      }
    } finally {
      if (mounted) setState(() => eligiendo = false);
    }
  }

  Future<void> guardar() async {
    if (ocupado) return;
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    setState(() {
      guardando = true;
      error = null;
    });
    Usuario? actualizado;
    try {
      actualizado = await (widget.database ?? DatabaseHelper.instance)
          .actualizarPerfil(
            usuarioId: widget.usuario.id,
            nombre: nombre.text,
            foto: foto,
          );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo guardar el perfil. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
    if (mounted && actualizado != null) {
      // Deja que PopScope habilite la salida tras terminar el guardado.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(actualizado);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !ocupado,
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: AvatarPerfil(nombre: nombre.text, foto: foto, radio: 56),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: ocupado ? null : cambiarFoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(eligiendo ? 'Cargando foto…' : 'Elegir foto'),
                ),
              ),
              if (foto != null)
                Center(
                  child: TextButton(
                    onPressed: ocupado
                        ? null
                        : () => setState(() => foto = null),
                    child: const Text('Quitar foto'),
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nombre,
                enabled: !ocupado,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => guardar(),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (valor) => valor == null || valor.trim().isEmpty
                    ? 'Escribe tu nombre'
                    : valor.trim().length > 80
                    ? 'Usa como máximo 80 caracteres'
                    : null,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: ocupado ? null : guardar,
                icon: guardando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(guardando ? 'Guardando…' : 'Guardar cambios'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: ocupado ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
