import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/mascota.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/mascota_service.dart';
import '../theme/app_theme.dart';
import '../utils/mascota_validators.dart';
import '../utils/foto_url.dart';

const _especies = ['PERRO', 'GATO', 'OTRO'];
const _tamanos = ['PEQUENO', 'MEDIANO', 'GRANDE'];
const _sexos = ['MACHO', 'HEMBRA'];
const _unidadesEdad = ['MESES', 'ANIOS'];
const _temperamentos = [
  'JUGUETON',
  'TRANQUILO',
  'TIMIDO',
  'SOCIABLE',
  'PROTECTOR',
  'ENERGICO',
  'CARINOSO',
];

const _etiquetas = {
  'PERRO': 'Perro',
  'GATO': 'Gato',
  'OTRO': 'Otro',
  'PEQUENO': 'Pequeño',
  'MEDIANO': 'Mediano',
  'GRANDE': 'Grande',
  'MACHO': 'Macho',
  'HEMBRA': 'Hembra',
  'MESES': 'Meses',
  'ANIOS': 'Años',
  'JUGUETON': 'Juguetón',
  'TRANQUILO': 'Tranquilo',
  'TIMIDO': 'Tímido',
  'SOCIABLE': 'Sociable',
  'PROTECTOR': 'Protector',
  'ENERGICO': 'Enérgico',
  'CARINOSO': 'Cariñoso',
};

const _maxFotos = 6;
const _maxBytesPorFoto = 5 * 1024 * 1024;

class MascotaFormScreen extends StatefulWidget {
  const MascotaFormScreen({super.key, this.mascotaId, this.service});

  /// Si se indica, el formulario edita la mascota publicada con ese id.
  final int? mascotaId;
  final MascotaService? service;

  @override
  State<MascotaFormScreen> createState() => _MascotaFormScreenState();
}

enum _SubmitStatus { idle, loading, success }

class _MascotaFormScreenState extends State<MascotaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final MascotaService _service = widget.service ?? MascotaService();
  final _picker = ImagePicker();

  bool get _edicion => widget.mascotaId != null;

  // El dador es el usuario logueado; solo se pide el id si el token no lo trae.
  final int? _usuarioId = AuthSession.usuarioId;
  final _idDadorCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _historialSaludCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();

  String? _especie;
  String? _unidadEdad;
  String? _tamano;
  String? _sexo;
  final Set<String> _temperamentoSeleccionado = {};
  final List<XFile> _fotos = [];

  // Solo en modo edición.
  bool _cargando = false;
  String? _errorCarga;
  int? _idDador;
  bool _tienePostulacionesActivas = false;
  List<String> _fotosActuales = const [];

  _SubmitStatus _status = _SubmitStatus.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_edicion) {
      _cargando = true;
      _cargarParaEditar();
    }
  }

  @override
  void dispose() {
    _idDadorCtrl.dispose();
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _edadCtrl.dispose();
    _historialSaludCtrl.dispose();
    _ubicacionCtrl.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargarParaEditar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    if (!AuthSession.autenticado) {
      setState(() {
        _cargando = false;
        _errorCarga = 'Inicia sesión para editar tus publicaciones.';
      });
      return;
    }

    try {
      final edicion = await _service.obtenerParaEditar(widget.mascotaId!);
      if (!mounted) return;
      final mascota = edicion.mascota;

      final dador = mascota.idDador;
      if (dador != null && _usuarioId != null && dador != _usuarioId) {
        setState(() {
          _cargando = false;
          _errorCarga = _mensajeSoloPropietario;
        });
        return;
      }

      String? opcion(String? valor, List<String> opciones) {
        final normalizado = valor?.toUpperCase();
        return opciones.contains(normalizado) ? normalizado : null;
      }

      _idDador = dador;
      _nombreCtrl.text = mascota.nombre;
      _razaCtrl.text = mascota.raza ?? '';
      _edadCtrl.text = mascota.edad?.toString() ?? '';
      _historialSaludCtrl.text = mascota.historialSalud ?? '';
      _ubicacionCtrl.text = mascota.ubicacion ?? '';
      setState(() {
        _especie = opcion(mascota.especie, _especies);
        _unidadEdad = opcion(mascota.unidadEdad, _unidadesEdad);
        _tamano = opcion(mascota.tamano, _tamanos);
        _sexo = opcion(mascota.sexo, _sexos);
        _temperamentoSeleccionado
          ..clear()
          ..addAll(
            mascota.temperamento.map((t) => t.toUpperCase()).where(_temperamentos.contains),
          );
        _fotosActuales = mascota.galeria;
        _tienePostulacionesActivas = edicion.tienePostulacionesActivas;
        _cargando = false;
      });
    } on SinPermisosException {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = _mensajeSoloPropietario;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.message;
      });
    }
  }

  static const _mensajeSoloPropietario =
      'Solo el dador propietario puede editar esta publicación.';

  Future<void> _agregarFoto() async {
    if (_fotos.length >= _maxFotos) return;

    final foto = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (foto == null) return;

    final tamanoBytes = await foto.length();
    if (tamanoBytes > _maxBytesPorFoto) {
      setState(() => _errorMessage = 'Cada foto debe pesar máximo 5 MB.');
      return;
    }

    setState(() {
      _fotos.add(foto);
      _errorMessage = null;
    });
  }

  void _quitarFoto(int index) {
    setState(() => _fotos.removeAt(index));
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    final formOk = _formKey.currentState?.validate() ?? false;
    final temperamentoError = MascotaValidators.temperamento(
      _temperamentoSeleccionado.toList(),
    );
    final fotosError = _edicion
        ? MascotaValidators.fotosEdicion(_fotos.length)
        : MascotaValidators.fotos(_fotos.length);

    if (!formOk || temperamentoError != null || fotosError != null) {
      setState(() => _errorMessage = fotosError ?? temperamentoError);
      return;
    }

    setState(() => _status = _SubmitStatus.loading);

    final mascota = Mascota(
      idDador: _idDador ?? _usuarioId ?? int.parse(_idDadorCtrl.text.trim()),
      nombre: _nombreCtrl.text.trim(),
      especie: _especie!,
      raza: _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
      edad: int.parse(_edadCtrl.text.trim()),
      unidadEdad: _unidadEdad!,
      tamano: _tamano!,
      sexo: _sexo!,
      temperamento: _temperamentoSeleccionado.toList(),
      historialSalud: _historialSaludCtrl.text.trim().isEmpty
          ? null
          : _historialSaludCtrl.text.trim(),
      ubicacion: _ubicacionCtrl.text.trim(),
    );

    try {
      if (_edicion) {
        await _service.actualizar(widget.mascotaId!, mascota, _fotos);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      await _service.crear(mascota, _fotos);
      if (!mounted) return;
      setState(() => _status = _SubmitStatus.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SubmitStatus.idle;
        _errorMessage = e is SinPermisosException && _edicion ? _mensajeSoloPropietario : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _SubmitStatus.idle;
        _errorMessage = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _idDadorCtrl.clear();
    _nombreCtrl.clear();
    _razaCtrl.clear();
    _edadCtrl.clear();
    _historialSaludCtrl.clear();
    _ubicacionCtrl.clear();
    setState(() {
      _especie = null;
      _unidadEdad = null;
      _tamano = null;
      _sexo = null;
      _temperamentoSeleccionado.clear();
      _fotos.clear();
      _status = _SubmitStatus.idle;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _SubmitStatus.success) {
      return _SuccessView(onPublishAnother: _resetForm);
    }

    final isLoading = _status == _SubmitStatus.loading;
    final titulo = _edicion ? 'Editar mascota' : 'Publicar mascota';

    if (_edicion && (_cargando || _errorCarga != null)) {
      return Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: Center(
          child: _cargando
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(_errorCarga!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      if (_errorCarga != _mensajeSoloPropietario &&
                          AuthSession.autenticado)
                        TextButton.icon(
                          onPressed: _cargarParaEditar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                    ],
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderBanner(edicion: _edicion),
                    if (_edicion && _tienePostulacionesActivas) ...[
                      const SizedBox(height: 16),
                      const _AdvertenciaPostulaciones(),
                    ],
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('Datos de la mascota'),
                            const SizedBox(height: 12),
                            if (_usuarioId == null && _idDador == null) ...[
                              _buildTextField(
                                controller: _idDadorCtrl,
                                label: '(temporal) ID del dador',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: MascotaValidators.idDador,
                                enabled: !isLoading,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _buildTextField(
                              controller: _nombreCtrl,
                              label: 'Nombre',
                              icon: Icons.pets_outlined,
                              validator: MascotaValidators.nombre,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildDropdown(
                              label: 'Especie',
                              icon: Icons.category_outlined,
                              value: _especie,
                              options: _especies,
                              enabled: !isLoading,
                              validator: MascotaValidators.especie,
                              onChanged: (v) => setState(() => _especie = v),
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _razaCtrl,
                              label: 'Raza (opcional)',
                              icon: Icons.badge_outlined,
                              validator: MascotaValidators.raza,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _edadCtrl,
                                    label: 'Edad',
                                    icon: Icons.cake_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: MascotaValidators.edad,
                                    enabled: !isLoading,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDropdown(
                                    label: 'Unidad',
                                    icon: Icons.schedule_outlined,
                                    value: _unidadEdad,
                                    options: _unidadesEdad,
                                    enabled: !isLoading,
                                    validator: MascotaValidators.unidadEdad,
                                    onChanged: (v) => setState(() => _unidadEdad = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildDropdown(
                              label: 'Tamaño',
                              icon: Icons.straighten_outlined,
                              value: _tamano,
                              options: _tamanos,
                              enabled: !isLoading,
                              validator: MascotaValidators.tamano,
                              onChanged: (v) => setState(() => _tamano = v),
                            ),
                            const SizedBox(height: 14),
                            _buildDropdown(
                              label: 'Sexo',
                              icon: Icons.wc_outlined,
                              value: _sexo,
                              options: _sexos,
                              enabled: !isLoading,
                              validator: MascotaValidators.sexo,
                              onChanged: (v) => setState(() => _sexo = v),
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Temperamento'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _temperamentos.map((t) {
                                final selected = _temperamentoSeleccionado.contains(t);
                                return FilterChip(
                                  label: Text(_etiquetas[t] ?? t),
                                  selected: selected,
                                  onSelected: isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value) {
                                              _temperamentoSeleccionado.add(t);
                                            } else {
                                              _temperamentoSeleccionado.remove(t);
                                            }
                                          });
                                        },
                                  selectedColor: AppPalette.mint,
                                  checkmarkColor: AppPalette.textDark,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Más información'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _historialSaludCtrl,
                              label: 'Historial de salud (opcional)',
                              icon: Icons.medical_information_outlined,
                              maxLength: 1000,
                              maxLines: 4,
                              validator: MascotaValidators.historialSalud,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _ubicacionCtrl,
                              label: 'Ubicación',
                              icon: Icons.location_on_outlined,
                              validator: MascotaValidators.ubicacion,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Fotos'),
                            const SizedBox(height: 10),
                            if (_edicion && _fotosActuales.isNotEmpty) ...[
                              _FotosActuales(urls: _fotosActuales),
                              const SizedBox(height: 14),
                            ],
                            _FotosSelector(
                              fotos: _fotos,
                              enabled: !isLoading,
                              onAgregar: _agregarFoto,
                              onQuitar: _quitarFoto,
                              opcional: _edicion,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(_edicion ? 'Guardar cambios' : 'Publicar'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Servidor: ${AppConfig.baseUrl}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppPalette.textDark.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        counterText: '',
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required bool enabled,
    required String? Function(String?) validator,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(_etiquetas[o] ?? o)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({this.edicion = false});

  final bool edicion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.peach.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Icon(Icons.pets, color: AppPalette.peachDark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edicion ? 'Edita tu publicación' : 'Publica una mascota',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  edicion
                      ? 'Actualiza los datos de tu mascota y guarda los cambios.'
                      : 'Ayúdale a encontrar un hogar. Tu publicación quedará pendiente de aprobación.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppPalette.peachDark,
          ),
    );
  }
}

class _FotosSelector extends StatelessWidget {
  const _FotosSelector({
    required this.fotos,
    required this.enabled,
    required this.onAgregar,
    required this.onQuitar,
    this.opcional = false,
  });

  final List<XFile> fotos;
  final bool enabled;
  final bool opcional;
  final VoidCallback onAgregar;
  final void Function(int index) onQuitar;

  @override
  Widget build(BuildContext context) {
    final puedeAgregar = enabled && fotos.length < _maxFotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...fotos.asMap().entries.map((entry) {
              final index = entry.key;
              final foto = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: FutureBuilder<Uint8List>(
                        future: foto.readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ColoredBox(color: Colors.black12);
                          }
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: InkWell(
                      onTap: enabled ? () => onQuitar(index) : null,
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (puedeAgregar)
              InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppPalette.mintDark.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppPalette.mintDark),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          opcional
              ? '${fotos.length}/$_maxFotos fotos nuevas · Opcional · JPG/PNG · 5 MB c/u'
              : '${fotos.length}/$_maxFotos fotos · Mín. 1 · JPG/PNG · 5 MB c/u',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppPalette.textDark.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _AdvertenciaPostulaciones extends StatelessWidget {
  const _AdvertenciaPostulaciones();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.6)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppPalette.textDark, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Esta mascota tiene postulaciones activas. Los cambios que guardes '
                'serán visibles para quienes ya se postularon.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FotosActuales extends StatelessWidget {
  const _FotosActuales({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotos actuales',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textDark.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final url in urls)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Image.network(
                    resolverUrlFoto(url) ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onPublishAnother});

  final VoidCallback onPublishAnother;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar mascota')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppPalette.mint.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppPalette.mintDark,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¡Publicación enviada!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu publicación fue enviada y está en revisión por el administrador',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    onPressed: onPublishAnother,
                    child: const Text('Publicar otra mascota'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
