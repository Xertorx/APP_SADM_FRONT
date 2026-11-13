import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config/geolocalizacion_textos.dart';

/// HU10: resultado de pedir la ubicación al navegador o al dispositivo.
sealed class ResultadoUbicacion {
  const ResultadoUbicacion();
}

/// Se obtuvieron las coordenadas.
class UbicacionObtenida extends ResultadoUbicacion {
  const UbicacionObtenida(this.latitud, this.longitud);

  final double latitud;
  final double longitud;
}

/// El usuario negó el permiso (o lo bloqueó).
class PermisoNegado extends ResultadoUbicacion {
  const PermisoNegado();
}

/// Servicio de ubicación apagado, tiempo agotado u otro fallo.
class UbicacionNoDisponible extends ResultadoUbicacion {
  const UbicacionNoDisponible();
}

/// Origen de las coordenadas del usuario. Es una interfaz para poder simularla en los tests.
abstract class ProveedorUbicacion {
  Future<ResultadoUbicacion> obtener();
}

/// Implementación real sobre `geolocator` (funciona en web: en Chrome solo en localhost o https).
class GeolocatorProveedor implements ProveedorUbicacion {
  const GeolocatorProveedor();

  static const tiempoMaximo = Duration(seconds: 10);

  @override
  Future<ResultadoUbicacion> obtener() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const UbicacionNoDisponible();
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        return const PermisoNegado();
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: tiempoMaximo,
        ),
      ).timeout(tiempoMaximo);
      return UbicacionObtenida(posicion.latitude, posicion.longitude);
    } on PermissionDeniedException {
      return const PermisoNegado();
    } catch (_) {
      // TimeoutException, servicio apagado, plataforma sin soporte...
      return const UbicacionNoDisponible();
    }
  }
}

/// "2.5 km" (1 decimal), "< 1 km" si es menor a 1, "Distancia no disponible" si no hay dato.
String formatearDistancia(double? km) {
  if (km == null) return GeolocalizacionTextos.distanciaNoDisponible;
  if (km < 1) return GeolocalizacionTextos.distanciaMenosDeUno;
  return '${km.toStringAsFixed(1)} km';
}
