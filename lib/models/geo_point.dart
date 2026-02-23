/// Modelo de coordenada geográfica independiente de proveedor de mapas.
///
/// Reemplaza el uso de `LatLng` de `google_maps_flutter` para desacoplar
/// la lógica de negocio de un SDK de mapas específico.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
