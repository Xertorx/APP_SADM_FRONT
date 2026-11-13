import 'dart:typed_data';

/// Fuera de la web no hay descarga por navegador.
const bool descargaDisponible = false;

void descargarArchivo(Uint8List bytes, String nombre, String tipo) {
  throw UnsupportedError('La descarga de archivos solo está disponible en la versión web');
}
