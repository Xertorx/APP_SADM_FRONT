import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/configuracion_seleccion.dart';
import '../utils/configuracion_validators.dart';

/// Límites con los que se valida el puntaje de un elemento dentro de su etapa.
class CapacidadEtapa {
  const CapacidadEtapa({required this.maximo, required this.asignadoOtros});

  /// Puntaje máximo de la etapa.
  final int maximo;

  /// Suma de los puntajes de los demás elementos de la etapa.
  final int asignadoOtros;

  int get disponible => maximo - asignadoOtros;

  /// Valida el puntaje de un elemento: rango 0-100 y dentro de lo que queda en la etapa.
  String? validar(String? value) {
    final error = ConfiguracionValidators.puntaje(value);
    if (error != null) return error;
    if (int.parse(value!.trim()) > disponible) {
      return disponible <= 0
          ? 'La etapa no tiene puntos disponibles (máximo $maximo)'
          : 'Supera el máximo de la etapa: quedan $disponible pts de $maximo';
    }
    return null;
  }
}

final _soloEnteros = FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,4}'));

Widget _campoPuntaje(
  TextEditingController controller,
  CapacidadEtapa capacidad, {
  String label = 'Puntaje',
}) {
  return TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    inputFormatters: [_soloEnteros],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      helperText: 'Disponible en la etapa: ${capacidad.disponible < 0 ? 0 : capacidad.disponible} '
          'de ${capacidad.maximo} pts',
      prefixIcon: const Icon(Icons.stars_outlined),
    ),
    validator: capacidad.validar,
  );
}

class _DialogoBase extends StatelessWidget {
  const _DialogoBase({
    required this.titulo,
    required this.formKey,
    required this.hijos,
    required this.onGuardar,
  });

  final String titulo;
  final GlobalKey<FormState> formKey;
  final List<Widget> hijos;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: hijos,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: onGuardar, child: const Text('Guardar')),
      ],
    );
  }
}

/// Alta o edición de una pregunta de la etapa "Preguntas".
class PreguntaDialog extends StatefulWidget {
  const PreguntaDialog({super.key, this.pregunta, required this.capacidad});

  final PreguntaSeleccion? pregunta;
  final CapacidadEtapa capacidad;

  @override
  State<PreguntaDialog> createState() => _PreguntaDialogState();
}

class _PreguntaDialogState extends State<PreguntaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _texto = TextEditingController(text: widget.pregunta?.texto);
  late final _puntaje = TextEditingController(text: widget.pregunta?.puntaje.toString());
  late final List<TextEditingController> _opciones = [
    for (final o in widget.pregunta?.opciones ?? const <String>[]) TextEditingController(text: o),
  ];
  late TipoRespuesta _tipo = widget.pregunta?.tipoRespuesta ?? TipoRespuesta.texto;
  String? _errorOpciones;

  @override
  void dispose() {
    _texto.dispose();
    _puntaje.dispose();
    for (final c in _opciones) {
      c.dispose();
    }
    super.dispose();
  }

  void _cambiarTipo(TipoRespuesta tipo) {
    setState(() {
      _tipo = tipo;
      _errorOpciones = null;
      if (tipo.requiereOpciones) {
        while (_opciones.length < 2) {
          _opciones.add(TextEditingController());
        }
      }
    });
  }

  void _guardar() {
    final textos = _opciones.map((c) => c.text.trim()).toList();
    final errorOpciones = ConfiguracionValidators.opciones(_tipo, textos);
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _errorOpciones = errorOpciones);
    if (!formOk || errorOpciones != null) return;

    Navigator.of(context).pop(
      PreguntaSeleccion(
        id: widget.pregunta?.id,
        texto: _texto.text.trim(),
        tipoRespuesta: _tipo,
        puntaje: int.parse(_puntaje.text.trim()),
        opciones: _tipo.requiereOpciones ? textos : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogoBase(
      titulo: widget.pregunta == null ? 'Agregar pregunta' : 'Editar pregunta',
      formKey: _formKey,
      onGuardar: _guardar,
      hijos: [
        TextFormField(
          controller: _texto,
          maxLines: 2,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Pregunta',
            prefixIcon: Icon(Icons.help_outline),
          ),
          validator: (v) => ConfiguracionValidators.textoObligatorio(v, campo: 'la pregunta'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<TipoRespuesta>(
          initialValue: _tipo,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo de respuesta',
            prefixIcon: Icon(Icons.checklist_outlined),
          ),
          items: [
            for (final tipo in TipoRespuesta.values)
              DropdownMenuItem(value: tipo, child: Text(tipo.etiqueta)),
          ],
          onChanged: (tipo) {
            if (tipo != null) _cambiarTipo(tipo);
          },
        ),
        if (_tipo.requiereOpciones) ...[
          const SizedBox(height: 14),
          Text('Opciones de respuesta', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _opciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _opciones[i],
                      decoration: InputDecoration(labelText: 'Opción ${i + 1}'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar opción ${i + 1}',
                    icon: const Icon(Icons.close),
                    onPressed: _opciones.length <= 2
                        ? null
                        : () => setState(() => _opciones.removeAt(i).dispose()),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _opciones.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar opción'),
            ),
          ),
          if (_errorOpciones != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _errorOpciones!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _campoPuntaje(_puntaje, widget.capacidad),
      ],
    );
  }
}

/// Alta o edición de un documento de la etapa "Documentos".
class DocumentoDialog extends StatefulWidget {
  const DocumentoDialog({super.key, this.documento, required this.capacidad});

  final DocumentoSeleccion? documento;
  final CapacidadEtapa capacidad;

  @override
  State<DocumentoDialog> createState() => _DocumentoDialogState();
}

class _DocumentoDialogState extends State<DocumentoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.documento?.nombre);
  late final _descripcion = TextEditingController(text: widget.documento?.descripcion);
  late final _puntaje = TextEditingController(text: widget.documento?.puntajeMaximo.toString());
  late bool _obligatorio = widget.documento?.obligatorio ?? true;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _puntaje.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      DocumentoSeleccion(
        id: widget.documento?.id,
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        obligatorio: _obligatorio,
        puntajeMaximo: int.parse(_puntaje.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogoBase(
      titulo: widget.documento == null ? 'Agregar documento' : 'Editar documento',
      formKey: _formKey,
      onGuardar: _guardar,
      hijos: [
        TextFormField(
          controller: _nombre,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Nombre del documento',
            prefixIcon: Icon(Icons.description_outlined),
          ),
          validator: (v) =>
              ConfiguracionValidators.textoObligatorio(v, campo: 'el nombre', max: 200),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descripcion,
          maxLines: 2,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
          validator: (v) => ConfiguracionValidators.textoObligatorio(v, campo: 'la descripción'),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Obligatorio'),
          subtitle: Text(_obligatorio
              ? 'El adoptante debe adjuntarlo'
              : 'El adoptante puede omitirlo'),
          value: _obligatorio,
          onChanged: (v) => setState(() => _obligatorio = v),
        ),
        const SizedBox(height: 8),
        _campoPuntaje(_puntaje, widget.capacidad, label: 'Puntaje máximo'),
      ],
    );
  }
}

/// Alta de un criterio de evaluación (entrevista o visita domiciliaria).
class CriterioDialog extends StatefulWidget {
  const CriterioDialog({super.key, required this.etapa, required this.capacidad});

  final EtapaSeleccion etapa;
  final CapacidadEtapa capacidad;

  @override
  State<CriterioDialog> createState() => _CriterioDialogState();
}

class _CriterioDialogState extends State<CriterioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _puntaje = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    _puntaje.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CriterioSeleccion(
        descripcion: _descripcion.text.trim(),
        puntajeMaximo: int.parse(_puntaje.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogoBase(
      titulo: 'Agregar criterio · ${widget.etapa.nombreLargo}',
      formKey: _formKey,
      onGuardar: _guardar,
      hijos: [
        TextFormField(
          controller: _descripcion,
          maxLines: 2,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Descripción del criterio',
            prefixIcon: Icon(Icons.fact_check_outlined),
          ),
          validator: (v) => ConfiguracionValidators.textoObligatorio(v, campo: 'la descripción'),
        ),
        const SizedBox(height: 14),
        _campoPuntaje(_puntaje, widget.capacidad, label: 'Puntaje máximo'),
      ],
    );
  }
}
