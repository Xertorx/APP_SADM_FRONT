import 'package:flutter/material.dart';

import '../config/estadisticas_textos.dart';
import '../theme/app_theme.dart';

/// Gráfico de barras horizontales de usuarios activos por rol (HU30), hecho con widgets propios:
/// cada fila es etiqueta + barra proporcional al total + "cifra (porcentaje)". Sin paquetes de gráficos.
class GraficoBarrasRoles extends StatelessWidget {
  const GraficoBarrasRoles({super.key, required this.datos});

  /// rol del backend (USUARIO / FUNDACION / ADMINISTRADOR) → cantidad de usuarios activos.
  final Map<String, int> datos;

  static const _orden = ['USUARIO', 'FUNDACION', 'ADMINISTRADOR'];

  static const _colores = <String, Color>{
    'USUARIO': AppPalette.mintDark,
    'FUNDACION': AppPalette.peachDark,
    'ADMINISTRADOR': AppPalette.textDark,
  };

  /// Porcentaje entero de [valor] sobre [total] (0 si no hay datos).
  static int porcentaje(int valor, int total) => total == 0 ? 0 : (valor * 100 / total).round();

  @override
  Widget build(BuildContext context) {
    final total = datos.values.fold(0, (a, b) => a + b);
    // Primero los roles conocidos en orden fijo; luego cualquier otro que llegue del backend.
    final roles = [..._orden, ...datos.keys.where((r) => !_orden.contains(r))];

    return Column(
      children: [
        for (final rol in roles) ...[
          _FilaRol(
            rol: rol,
            valor: datos[rol] ?? 0,
            total: total,
            color: _colores[rol] ?? AppPalette.mint,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FilaRol extends StatelessWidget {
  const _FilaRol({required this.rol, required this.valor, required this.total, required this.color});

  final String rol;
  final int valor;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraccion = total == 0 ? 0.0 : valor / total;
    final etiqueta = EstadisticasTextos.rolEtiqueta(rol);
    final porcentaje = GraficoBarrasRoles.porcentaje(valor, total);

    return Semantics(
      label: '$etiqueta: $valor ($porcentaje%)',
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(etiqueta, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 22,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraccion,
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              '$valor ($porcentaje%)',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
