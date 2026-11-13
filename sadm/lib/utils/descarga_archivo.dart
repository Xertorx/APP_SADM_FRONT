// HU30: descarga de archivos en el navegador. Import condicional:
//  - Web (dart.library.js_interop): crea un Blob y hace clic en un enlace <a download>.
//  - Otras plataformas: no disponible (la pantalla muestra "La exportación está disponible en la versión web").
// Se usa dart:js_interop del SDK, sin agregar paquetes al pubspec.yaml.
export 'descarga_archivo_stub.dart' if (dart.library.js_interop) 'descarga_archivo_web.dart';
