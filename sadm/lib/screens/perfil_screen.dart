import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/perfil.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/perfil_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/geolocalizacion.dart';
import '../utils/perfil_validators.dart';
import 'home_screen.dart';
import 'ubicacion_referencia_seccion.dart';

/// HU04 — "Mi perfil": consulta y edición de datos de contacto, foto y contraseña.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, this.service, this.ubicacionService, this.proveedorUbicacion});

  final PerfilService? service;

  /// HU10: para simular la ubicación de referencia y el GPS en los tests.
  final UbicacionService? ubicacionService;
  final ProveedorUbicacion? proveedorUbicacion;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

enum _Estado { cargando, idle, guardando, exito }

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PerfilService _service = widget.service ?? PerfilService();
  final _picker = ImagePicker();

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  _Estado _estado = _Estado.cargando;
  String? _errorCarga;
  String? _errorGuardar;
  String? _errorFoto;

  /// Foto que se está mostrando (la del servidor o la recién elegida).
  Uint8List? _fotoMostrada;

  /// Foto nueva pendiente de subir al guardar.
  XFile? _fotoNueva;
  Uint8List? _bytesFotoNueva;
  bool _quitarFoto = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _apellidoCtrl,
      _correoCtrl,
      _telefonoCtrl,
      _ubicacionCtrl,
      _actualCtrl,
      _nuevaCtrl,
      _confirmarCtrl,
    ]) {
      c.dispose();
    }
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = _Estado.cargando;
      _errorCarga = null;
    });
    if (!AuthSession.autenticado) {
      setState(() {
        _estado = _Estado.idle;
        _errorCarga = 'Inicia sesión para ver tu perfil.';
      });
      return;
    }
    try {
      final perfil = await _service.obtener();
      final foto = perfil.tieneFoto ? await _service.descargarFoto() : null;
      if (!mounted) return;
      _nombreCtrl.text = perfil.nombre;
      _apellidoCtrl.text = perfil.apellido;
      _correoCtrl.text = perfil.correo;
      _telefonoCtrl.text = perfil.telefono;
      _ubicacionCtrl.text = perfil.ubicacion;
      setState(() {
        _fotoMostrada = foto;
        _fotoNueva = null;
        _bytesFotoNueva = null;
        _quitarFoto = false;
        _estado = _Estado.idle;
      });
    } on NoAutenticadoException catch (e) {
      _sesionExpirada(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _Estado.idle;
        _errorCarga = e.message;
      });
    }
  }

  void _sesionExpirada(String mensaje) {
    if (!mounted) return;
    AuthSession.limpiar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _cambiarFoto() async {
    final XFile? elegida = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 75,
    );
    if (elegida == null) return;
    final bytes = await elegida.readAsBytes();
    final error = PerfilValidators.foto(
      nombreArchivo: elegida.name,
      tipo: elegida.mimeType,
      bytes: bytes.length,
    );
    if (!mounted) return;
    setState(() {
      _errorFoto = error;
      if (error == null) {
        _fotoNueva = elegida;
        _bytesFotoNueva = bytes;
        _fotoMostrada = bytes;
        _quitarFoto = false;
      }
    });
  }

  void _quitarFotoActual() {
    setState(() {
      _errorFoto = null;
      _fotoNueva = null;
      _bytesFotoNueva = null;
      _fotoMostrada = null;
      _quitarFoto = true;
    });
  }

  Future<void> _guardar() async {
    if (_estado == _Estado.guardando) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _estado = _Estado.guardando;
      _errorGuardar = null;
    });
    try {
      await _service.actualizar(
        PerfilActualizacion(
          nombre: _nombreCtrl.text,
          apellido: _apellidoCtrl.text,
          telefono: _telefonoCtrl.text,
          ubicacion: _ubicacionCtrl.text,
          contrasenaActual: _actualCtrl.text,
          contrasenaNueva: _nuevaCtrl.text,
          confirmarContrasena: _confirmarCtrl.text,
          quitarFoto: _quitarFoto,
        ),
        foto: _fotoNueva,
        bytesFoto: _bytesFotoNueva,
      );
      if (!mounted) return;
      _actualCtrl.clear();
      _nuevaCtrl.clear();
      _confirmarCtrl.clear();
      setState(() => _estado = _Estado.exito);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tus cambios se guardaron correctamente')),
      );
      await _cargar();
    } on NoAutenticadoException catch (e) {
      _sesionExpirada(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _Estado.idle;
        _errorGuardar = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _cuerpo(context),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_estado == _Estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorCarga!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final guardando = _estado == _Estado.guardando;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _fotoSeccion(theme, guardando),
          const Divider(height: 32),
          TextFormField(
            controller: _nombreCtrl,
            enabled: !guardando,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: PerfilValidators.nombre,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _apellidoCtrl,
            enabled: !guardando,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: PerfilValidators.apellido,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _correoCtrl,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Correo',
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Solo lectura'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppPalette.mint.withValues(alpha: 0.5),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
              helperText: 'El correo no se puede modificar',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefonoCtrl,
            enabled: !guardando,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            validator: PerfilValidators.telefono,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ubicacionCtrl,
            enabled: !guardando,
            decoration: const InputDecoration(labelText: 'Ubicación'),
            validator: PerfilValidators.ubicacion,
          ),
          // HU10: ubicación de referencia (respaldo de la búsqueda por cercanía); se guarda aparte.
          const Divider(height: 40),
          UbicacionReferenciaSeccion(
            onSesionExpirada: _sesionExpirada,
            service: widget.ubicacionService,
            proveedor: widget.proveedorUbicacion,
          ),
          const Divider(height: 40),
          Text(
            'Cambiar contraseña',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _passwordField(
            controlador: _actualCtrl,
            etiqueta: 'Contraseña actual',
            guardando: guardando,
            validator: (v) => PerfilValidators.contrasenaActual(
              v,
              _nuevaCtrl.text,
              _confirmarCtrl.text,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.peach.withValues(alpha: 0.35),
              border: Border.all(color: AppPalette.peachDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppPalette.peachDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requerida para validar antes de cambiar la contraseña',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _passwordField(
            controlador: _nuevaCtrl,
            etiqueta: 'Nueva contraseña',
            ayuda: 'Mín. 8 caracteres, una mayúscula y un número',
            guardando: guardando,
            validator: (v) => PerfilValidators.contrasenaNueva(
              _actualCtrl.text,
              v,
              _confirmarCtrl.text,
            ),
          ),
          const SizedBox(height: 14),
          _passwordField(
            controlador: _confirmarCtrl,
            etiqueta: 'Confirmar',
            guardando: guardando,
            validator: (v) => PerfilValidators.confirmar(
              _actualCtrl.text,
              _nuevaCtrl.text,
              v,
            ),
          ),
          if (_errorGuardar != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorGuardar!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const Divider(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                ),
                child: guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: guardando ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fotoSeccion(ThemeData theme, bool guardando) {
    final bytes = _fotoMostrada;
    return Row(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: AppPalette.mint,
          backgroundImage: bytes == null ? null : MemoryImage(bytes),
          child: bytes == null
              ? const Icon(Icons.person, size: 56, color: AppPalette.mintDark)
              : null,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: guardando ? null : _cambiarFoto,
                child: const Text('Cambiar foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: guardando || bytes == null ? null : _quitarFotoActual,
                child: const Text('Quitar foto'),
              ),
              if (_errorFoto != null) ...[
                const SizedBox(height: 8),
                Text(_errorFoto!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controlador,
    required String etiqueta,
    required bool guardando,
    required FormFieldValidator<String> validator,
    String? ayuda,
  }) {
    return TextFormField(
      controller: controlador,
      enabled: !guardando,
      obscureText: true,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
      validator: validator,
    );
  }
}
