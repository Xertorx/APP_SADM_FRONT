import 'package:flutter/material.dart';

import '../models/configuracion_seleccion.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/configuracion_seleccion_service.dart';
import '../theme/app_theme.dart';
import '../utils/configuracion_validators.dart';
import 'configuracion_elemento_dialogs.dart';
import 'distribucion_puntajes.dart';

/// Estado de la mascota en el que la configuración todavía se puede editar.
const estadoBorradorConfiguracion = 'BORRADOR_CONFIGURACION';

/// HU12: configuración del proceso de selección de una mascota (preguntas, documentos,
/// entrevista y visita domiciliaria) con la distribución de los 100 puntos.
///
/// Se muestra al terminar de crear la mascota y desde "Dar en adopción". Al salir devuelve
/// `true` si la mascota fue enviada a revisión.
class ConfiguracionSeleccionScreen extends StatefulWidget {
  const ConfiguracionSeleccionScreen({
    super.key,
    required this.mascotaId,
    this.nombreMascota,
    this.soloLectura = false,
    this.service,
  });

  final int mascotaId;
  final String? nombreMascota;

  /// La configuración se bloquea cuando la mascota ya salió del estado borrador.
  final bool soloLectura;
  final ConfiguracionSeleccionService? service;

  @override
  State<ConfiguracionSeleccionScreen> createState() => _ConfiguracionSeleccionScreenState();
}

enum _Operacion { ninguna, guardando, finalizando, publicando }

class _ConfiguracionSeleccionScreenState extends State<ConfiguracionSeleccionScreen> {
  late final ConfiguracionSeleccionService _service =
      widget.service ?? ConfiguracionSeleccionService();

  ConfiguracionSeleccion? _config;
  bool _cargando = true;
  String? _errorCarga;

  EtapaSeleccion _etapa = EtapaSeleccion.preguntas;
  _Operacion _operacion = _Operacion.ninguna;
  bool _sucio = false;
  bool _enviadaARevision = false;
  String? _errorAccion;
  String? _exito;

  bool get _soloLectura => widget.soloLectura || _enviadaARevision;
  bool get _ocupado => _operacion != _Operacion.ninguna;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    if (!AuthSession.autenticado) {
      setState(() {
        _cargando = false;
        _errorCarga = 'Inicia sesión para configurar el proceso de selección.';
      });
      return;
    }

    try {
      final config = await _service.obtener(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _config = config;
        _sucio = false;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.message;
      });
    }
  }

  void _editar(ConfiguracionSeleccion Function(ConfiguracionSeleccion actual) cambio) {
    setState(() {
      _config = cambio(_config!).copyWith(definitiva: false);
      _sucio = true;
      _errorAccion = null;
      _exito = null;
    });
  }

  ConfiguracionSeleccion _conMaximo(ConfiguracionSeleccion c, EtapaSeleccion etapa, int valor) =>
      switch (etapa) {
        EtapaSeleccion.preguntas => c.copyWith(preguntas: c.preguntas.conPuntajeMaximo(valor)),
        EtapaSeleccion.documentos => c.copyWith(documentos: c.documentos.conPuntajeMaximo(valor)),
        EtapaSeleccion.entrevista => c.copyWith(entrevista: c.entrevista.conPuntajeMaximo(valor)),
        EtapaSeleccion.visita =>
          c.copyWith(visitaDomiciliaria: c.visitaDomiciliaria.conPuntajeMaximo(valor)),
      };

  ConfiguracionSeleccion _conElementos(
    ConfiguracionSeleccion c,
    EtapaSeleccion etapa,
    List<ElementoSeleccion> lista,
  ) =>
      switch (etapa) {
        EtapaSeleccion.preguntas =>
          c.copyWith(preguntas: c.preguntas.conElementos(lista.cast<PreguntaSeleccion>())),
        EtapaSeleccion.documentos =>
          c.copyWith(documentos: c.documentos.conElementos(lista.cast<DocumentoSeleccion>())),
        EtapaSeleccion.entrevista =>
          c.copyWith(entrevista: c.entrevista.conElementos(lista.cast<CriterioSeleccion>())),
        EtapaSeleccion.visita => c.copyWith(
            visitaDomiciliaria:
                c.visitaDomiciliaria.conElementos(lista.cast<CriterioSeleccion>()),
          ),
      };

  /// Alta ([existente] nulo) o edición de un elemento de la etapa actual.
  Future<void> _abrirDialogo({ElementoSeleccion? existente}) async {
    final etapa = _etapa;
    final datos = _config!.datosDe(etapa);
    final capacidad = CapacidadEtapa(
      maximo: datos.puntajeMaximo,
      asignadoOtros: datos.puntajeAsignado - (existente?.puntaje ?? 0),
    );

    final resultado = await showDialog<ElementoSeleccion>(
      context: context,
      builder: (_) => switch (etapa) {
        EtapaSeleccion.preguntas =>
            PreguntaDialog(pregunta: existente as PreguntaSeleccion?, capacidad: capacidad),
        EtapaSeleccion.documentos =>
            DocumentoDialog(documento: existente as DocumentoSeleccion?, capacidad: capacidad),
        _ => CriterioDialog(etapa: etapa, capacidad: capacidad),
      },
    );
    if (resultado == null || !mounted) return;

    _editar((c) {
      final lista = [...c.datosDe(etapa).elementos];
      final indice = existente == null ? -1 : lista.indexOf(existente);
      if (indice >= 0) {
        lista[indice] = resultado;
      } else {
        lista.add(resultado);
      }
      return _conElementos(c, etapa, lista);
    });
  }

  void _eliminar(ElementoSeleccion elemento) {
    final etapa = _etapa;
    _editar((c) {
      final lista = [...c.datosDe(etapa).elementos]..remove(elemento);
      return _conElementos(c, etapa, lista);
    });
  }

  Future<void> _ejecutar(_Operacion operacion, Future<void> Function() accion) async {
    setState(() {
      _operacion = operacion;
      _errorAccion = null;
      _exito = null;
    });
    try {
      await accion();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorAccion = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorAccion = 'Ocurrió un error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _operacion = _Operacion.ninguna);
    }
  }

  Future<void> _guardar() async {
    if (ConfiguracionValidators.paraGuardar(_config!).isNotEmpty) {
      setState(() => _errorAccion = 'Corrige los puntajes señalados antes de guardar.');
      return;
    }
    await _ejecutar(_Operacion.guardando, () async {
      final guardada = await _service.guardar(_config!);
      if (!mounted) return;
      setState(() {
        _config = guardada;
        _sucio = false;
        _exito = 'Configuración guardada como borrador.';
      });
    });
  }

  Future<void> _finalizar() async {
    if (ConfiguracionValidators.paraFinalizar(_config!).isNotEmpty) return;
    await _ejecutar(_Operacion.finalizando, () async {
      if (_sucio) {
        final guardada = await _service.guardar(_config!);
        if (!mounted) return;
        setState(() {
          _config = guardada;
          _sucio = false;
        });
      }
      final finalizada = await _service.finalizar(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _config = finalizada;
        _exito = finalizada.definitiva
            ? 'Configuración finalizada. Ya puedes enviar la mascota a revisión.'
            : 'La configuración se guardó, pero el servidor no la marcó como definitiva.';
      });
    });
  }

  Future<void> _publicar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar a revisión'),
        content: const Text(
          'La mascota se enviará a revisión del administrador y la configuración quedará '
          'bloqueada para edición. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await _ejecutar(_Operacion.publicando, () async {
      await _service.publicar(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _enviadaARevision = true;
        _exito = 'Tu publicación fue enviada y está en revisión por el administrador.';
      });
    });
  }

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('Tienes cambios en la configuración que no se han guardado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop(_enviadaARevision);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sucio || _soloLectura,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proceso de selección'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(_enviadaARevision),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppPalette.mintDark),
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_errorCarga!, textAlign: TextAlign.center)),
              if (AuthSession.autenticado) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final config = _config!;
    final editable = !_soloLectura && !_ocupado;
    final erroresFinalizar = ConfiguracionValidators.paraFinalizar(config);
    final listaParaPublicar = config.definitiva && !_sucio && !_soloLectura;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Encabezado(nombre: widget.nombreMascota),
        const SizedBox(height: 16),
        if (_soloLectura) ...[
          const _Aviso(
            tipo: _TipoAviso.info,
            mensaje: 'La configuración está bloqueada porque la mascota ya fue enviada a revisión.',
          ),
          const SizedBox(height: 16),
        ],
        DistribucionPuntajes(
          config: config,
          habilitado: editable,
          onCambiarMaximo: (etapa, valor) => _editar((c) => _conMaximo(c, etapa, valor)),
        ),
        const SizedBox(height: 16),
        _SelectorEtapas(
          config: config,
          actual: _etapa,
          onSeleccionar: (e) => setState(() => _etapa = e),
        ),
        const SizedBox(height: 12),
        _PanelEtapa(
          etapa: _etapa,
          datos: config.datosDe(_etapa),
          editable: editable,
          onAgregar: () => _abrirDialogo(),
          onEditar: (e) => _abrirDialogo(existente: e),
          onEliminar: _eliminar,
        ),
        const SizedBox(height: 16),
        if (!_soloLectura && erroresFinalizar.isNotEmpty) ...[
          _Aviso(
            tipo: _TipoAviso.advertencia,
            titulo: 'Para finalizar la configuración',
            mensaje: erroresFinalizar.map((e) => '• $e').join('\n'),
          ),
          const SizedBox(height: 16),
        ],
        if (_errorAccion != null) ...[
          _Aviso(tipo: _TipoAviso.error, mensaje: _errorAccion!),
          const SizedBox(height: 16),
        ],
        if (_exito != null) ...[
          _Aviso(tipo: _TipoAviso.exito, mensaje: _exito!),
          const SizedBox(height: 16),
        ],
        if (!_soloLectura) ...[
          if (_sucio)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Hay cambios sin guardar.', textAlign: TextAlign.center),
            ),
          OutlinedButton.icon(
            onPressed: editable && _sucio ? _guardar : null,
            icon: _operacion == _Operacion.guardando ? const _Spinner() : const Icon(Icons.save_outlined),
            label: const Text('Guardar borrador'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 12),
          if (listaParaPublicar)
            ElevatedButton.icon(
              onPressed: _ocupado ? null : _publicar,
              icon: _operacion == _Operacion.publicando
                  ? const _Spinner()
                  : const Icon(Icons.send_outlined),
              label: const Text('Enviar a revisión'),
            )
          else
            ElevatedButton.icon(
              onPressed: editable && erroresFinalizar.isEmpty ? _finalizar : null,
              icon: _operacion == _Operacion.finalizando
                  ? const _Spinner()
                  : const Icon(Icons.task_alt_outlined),
              label: const Text('Finalizar configuración'),
            ),
        ] else if (_enviadaARevision) ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Volver'),
          ),
        ],
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({this.nombre});

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppPalette.mintDark, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre == null || nombre!.isEmpty
                      ? 'Configura las etapas'
                      : 'Proceso de selección de $nombre',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Define preguntas, documentos, entrevista y visita, y reparte los '
                  '$puntajeTotalSeleccion puntos entre las etapas.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorEtapas extends StatelessWidget {
  const _SelectorEtapas({
    required this.config,
    required this.actual,
    required this.onSeleccionar,
  });

  final ConfiguracionSeleccion config;
  final EtapaSeleccion actual;
  final ValueChanged<EtapaSeleccion> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (:etapa, :datos) in config.etapas)
          ChoiceChip(
            key: Key('etapa-${etapa.name}'),
            selected: etapa == actual,
            showCheckmark: false,
            avatar: Icon(
              ConfiguracionValidators.etapa(etapa, datos).isEmpty
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 18,
              color: colorDeEtapa(etapa),
            ),
            label: Text('${etapa.index + 1}. ${etapa.titulo} · ${datos.elementos.length}'),
            onSelected: (_) => onSeleccionar(etapa),
          ),
      ],
    );
  }
}

class _PanelEtapa extends StatelessWidget {
  const _PanelEtapa({
    required this.etapa,
    required this.datos,
    required this.editable,
    required this.onAgregar,
    required this.onEditar,
    required this.onEliminar,
  });

  final EtapaSeleccion etapa;
  final DatosEtapa<ElementoSeleccion> datos;
  final bool editable;
  final VoidCallback onAgregar;
  final ValueChanged<ElementoSeleccion> onEditar;
  final ValueChanged<ElementoSeleccion> onEliminar;

  String get _textoAgregar => switch (etapa) {
        EtapaSeleccion.preguntas => 'Agregar pregunta',
        EtapaSeleccion.documentos => 'Agregar documento',
        _ => 'Agregar criterio',
      };

  /// Entrevista y visita solo permiten agregar y eliminar criterios.
  bool get _editaElementos =>
      etapa == EtapaSeleccion.preguntas || etapa == EtapaSeleccion.documentos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asignado = datos.puntajeAsignado;
    final maximo = datos.puntajeMaximo;
    final excede = asignado > maximo;
    final progreso = maximo <= 0 ? (asignado > 0 ? 1.0 : 0.0) : (asignado / maximo).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                etapa.nombreLargo,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(etapa.subtitulo, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Asignado a $_nombreElementos',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  '$asignado / $maximo pts',
                  key: const Key('asignado-etapa'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: excede ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                color: excede ? theme.colorScheme.error : colorDeEtapa(etapa),
                backgroundColor: AppPalette.mint.withValues(alpha: 0.35),
              ),
            ),
            if (excede)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Los $_nombreElementos superan el máximo de la etapa en '
                  '${asignado - maximo} pts.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            if (datos.elementos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Aún no hay $_nombreElementos en esta etapa.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final elemento in datos.elementos)
                _ElementoTile(
                  elemento: elemento,
                  editable: editable,
                  puedeEditar: _editaElementos,
                  onEditar: () => onEditar(elemento),
                  onEliminar: () => onEliminar(elemento),
                ),
            if (editable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAgregar,
                icon: const Icon(Icons.add),
                label: Text(_textoAgregar),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _nombreElementos => switch (etapa) {
        EtapaSeleccion.preguntas => 'preguntas',
        EtapaSeleccion.documentos => 'documentos',
        _ => 'criterios',
      };
}

class _ElementoTile extends StatelessWidget {
  const _ElementoTile({
    required this.elemento,
    required this.editable,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final ElementoSeleccion elemento;
  final bool editable;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  String get _detalle {
    final e = elemento;
    return switch (e) {
      PreguntaSeleccion() => [
          e.tipoRespuesta.etiqueta,
          '${e.puntaje} pts',
          if (e.opciones.isNotEmpty) e.opciones.join(' / '),
        ].join(' · '),
      DocumentoSeleccion() => [
          e.obligatorio ? 'Obligatorio' : 'Opcional',
          '${e.puntaje} pts',
          if (e.descripcion.isNotEmpty) e.descripcion,
        ].join(' · '),
      CriterioSeleccion() => '${e.puntaje} pts',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(elemento.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_detalle),
      trailing: editable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (puedeEditar)
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEditar,
                  ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onEliminar,
                ),
              ],
            )
          : null,
    );
  }
}

enum _TipoAviso { info, advertencia, error, exito }

class _Aviso extends StatelessWidget {
  const _Aviso({required this.tipo, required this.mensaje, this.titulo});

  final _TipoAviso tipo;
  final String mensaje;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final (color, icono) = switch (tipo) {
      _TipoAviso.info => (AppPalette.mintDark, Icons.info_outline),
      _TipoAviso.advertencia => (AppPalette.peachDark, Icons.warning_amber_rounded),
      _TipoAviso.error => (Colors.redAccent, Icons.error_outline),
      _TipoAviso.exito => (AppPalette.mintDark, Icons.check_circle_outline),
    };

    return Semantics(
      liveRegion: tipo == _TipoAviso.error || tipo == _TipoAviso.exito,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo != null)
                    Text(titulo!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(mensaje),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
}
