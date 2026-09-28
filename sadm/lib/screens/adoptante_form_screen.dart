import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/adoptante.dart';
import '../services/adoptante_service.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class AdoptanteFormScreen extends StatefulWidget {
  const AdoptanteFormScreen({super.key});

  @override
  State<AdoptanteFormScreen> createState() => _AdoptanteFormScreenState();
}

enum _SubmitStatus { idle, loading, success }

class _AdoptanteFormScreenState extends State<AdoptanteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AdoptanteService();

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _identificacionCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _obscurePassword = true;
  _SubmitStatus _status = _SubmitStatus.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _identificacionCtrl.dispose();
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickFechaNacimiento() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    final formOk = _formKey.currentState?.validate() ?? false;
    final fechaError = Validators.fechaNacimiento(_fechaNacimiento);
    if (fechaError != null) {
      setState(() => _errorMessage = fechaError);
    }
    if (!formOk || fechaError != null) return;

    setState(() => _status = _SubmitStatus.loading);

    final adoptante = Adoptante(
      nombre: _nombreCtrl.text.trim(),
      apellido: _apellidoCtrl.text.trim(),
      identificacion: int.parse(_identificacionCtrl.text.trim()),
      fechaNacimiento: _fechaNacimiento!,
      correo: _correoCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text,
      telefono: _telefonoCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      // Siempre se registran como adoptantes activos; no son editables desde la UI.
      tipoUsuario: AppConstants.defaultTipoUsuario,
      estado: AppConstants.defaultEstado,
    );

    try {
      await _service.crear(adoptante);
      if (!mounted) return;
      setState(() => _status = _SubmitStatus.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SubmitStatus.idle;
        _errorMessage = e.message;
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
    _nombreCtrl.clear();
    _apellidoCtrl.clear();
    _identificacionCtrl.clear();
    _correoCtrl.clear();
    _contrasenaCtrl.clear();
    _telefonoCtrl.clear();
    _direccionCtrl.clear();
    setState(() {
      _fechaNacimiento = null;
      _status = _SubmitStatus.idle;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _SubmitStatus.success) {
      return _SuccessView(onRegisterAnother: _resetForm);
    }

    final isLoading = _status == _SubmitStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de adoptante'),
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
                    const _HeaderBanner(),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('Datos personales'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _nombreCtrl,
                              label: 'Nombre',
                              icon: Icons.badge_outlined,
                              validator: (v) => Validators.nombreApellido(v, 'nombre'),
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _apellidoCtrl,
                              label: 'Apellido',
                              icon: Icons.badge_outlined,
                              validator: (v) => Validators.nombreApellido(v, 'apellido'),
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _identificacionCtrl,
                              label: 'Identificación',
                              icon: Icons.numbers_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: Validators.identificacion,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _DatePickerField(
                              value: _fechaNacimiento,
                              enabled: !isLoading,
                              onTap: _pickFechaNacimiento,
                            ),
                            const SizedBox(height: 20),
                            const _SectionTitle('Contacto'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _correoCtrl,
                              label: 'Correo',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 254,
                              validator: Validators.correo,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _contrasenaCtrl,
                              label: 'Contraseña',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              maxLength: 72,
                              validator: Validators.contrasena,
                              enabled: !isLoading,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _telefonoCtrl,
                              label: 'Teléfono',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                                LengthLimitingTextInputFormatter(16),
                              ],
                              validator: Validators.telefono,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _direccionCtrl,
                              label: 'Dirección',
                              icon: Icons.home_outlined,
                              maxLength: 150,
                              maxLines: 2,
                              validator: Validators.direccion,
                              enabled: !isLoading,
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
                          : const Text('Registrar adoptante'),
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
    bool obscureText = false,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        counterText: '',
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Icon(Icons.pets, color: AppPalette.mintDark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sé un nuevo adoptante',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completa tus datos para unirte a nuestra comunidad.',
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

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.value,
    required this.onTap,
    required this.enabled,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '' : DateFormat('yyyy-MM-dd').format(value!);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de nacimiento',
          prefixIcon: Icon(Icons.cake_outlined, size: 20),
        ),
        child: Text(
          text.isEmpty ? 'Selecciona una fecha' : text,
          style: TextStyle(
            color: text.isEmpty ? Colors.grey : AppPalette.textDark,
          ),
        ),
      ),
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
  const _SuccessView({required this.onRegisterAnother});

  final VoidCallback onRegisterAnother;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de adoptante')),
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
                    '¡Registro exitoso!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El adoptante fue registrado correctamente.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRegisterAnother,
                    child: const Text('Registrar otro adoptante'),
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
