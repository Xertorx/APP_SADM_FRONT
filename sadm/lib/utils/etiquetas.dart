const _especiales = {
  'PEQUENO': 'Pequeño',
  'ANIOS': 'Años',
  'JUGUETON': 'Juguetón',
  'TIMIDO': 'Tímido',
  'ENERGICO': 'Enérgico',
  'CARINOSO': 'Cariñoso',
};

/// Converts backend codes (`ETAPA_1_EN_CURSO`, `PEQUENO`) into readable text.
String humanizar(String codigo) {
  final especial = _especiales[codigo.toUpperCase()];
  if (especial != null) return especial;

  final texto = codigo.replaceAll('_', ' ').trim().toLowerCase();
  if (texto.isEmpty) return texto;
  return texto[0].toUpperCase() + texto.substring(1);
}
