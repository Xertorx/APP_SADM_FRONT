import 'dart:js_interop';
import 'dart:typed_data';

// Declaraciones mínimas de la API del navegador (evita depender del paquete `web`).

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> partes, JSObject opciones);
}

@JS('URL')
extension type _Url._(JSObject _) implements JSObject {
  external static String createObjectURL(JSObject blob);
  external static void revokeObjectURL(String url);
}

extension type _Elemento._(JSObject _) implements JSObject {
  external set href(String valor);
  external set download(String valor);
  external void click();
  external void remove();
  external void appendChild(_Elemento hijo);
}

extension type _Documento._(JSObject _) implements JSObject {
  external _Elemento createElement(String etiqueta);
  external _Elemento get body;
}

@JS('document')
external _Documento get _documento;

const bool descargaDisponible = true;

/// Descarga [bytes] como archivo [nombre] (Blob + enlace temporal).
void descargarArchivo(Uint8List bytes, String nombre, String tipo) {
  final blob = _Blob(<JSAny>[bytes.toJS].toJS, {'type': tipo}.jsify() as JSObject);
  final url = _Url.createObjectURL(blob);
  final enlace = _documento.createElement('a')
    ..href = url
    ..download = nombre;
  _documento.body.appendChild(enlace);
  enlace.click();
  enlace.remove();
  _Url.revokeObjectURL(url);
}
