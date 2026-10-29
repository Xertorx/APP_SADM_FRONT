import '../config/app_config.dart';

/// Resolves a photo path returned by the backend into an absolute URL.
/// Relative paths are resolved against the backend host.
String? resolverUrlFoto(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final origen = Uri.parse(AppConfig.baseUrl).origin;
  return url.startsWith('/') ? '$origen$url' : '$origen/$url';
}
