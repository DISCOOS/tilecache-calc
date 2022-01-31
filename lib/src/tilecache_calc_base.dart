import 'dart:collection';
import 'dart:math';
import 'package:dart_jts/dart_jts.dart' as jts;
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:utm/utm.dart';

@immutable
class TileResult {
  TileResult(Map<int, List<Tile>> zooms) : _zooms = zooms;
  final Map<int, List<Tile>> _zooms;

  /// flat list of all tiles
  List<Tile> toList() => _zooms.values.fold(<Tile>[], (previous, tiles) => previous + tiles);

  /// key: zoom, value: tiles
  Map<int, List<Tile>> toZoom() => Map.unmodifiable(_zooms);

  /// key: zoom, value: count of tiles per Zoom
  Map<int, int> toZoomCount() {
    var _map = <int, int>{};
    _zooms.forEach((key, value) {
      _map[key] = value.length;
    });
    return _map;
  }

  /// key: radius, value: tiles
  Map<double, List<Tile>> toRadius() => {};
}

class TileEstimateResult {
  TileEstimateResult(Map<int, int> tileCounts) : _tileCounts = tileCounts;
  final Map<int, int> _tileCounts;

  /// key: zoom, value: tileCount
  Map<int, int> toZoomCount() => Map.unmodifiable(_tileCounts);

  /// key: zoom, value: count of tiles per Zoom
  int totalCount() {
    var _totalCount = 0;
    for (final value in _tileCounts.values) {
      _totalCount = _totalCount + value;
    }
    return _totalCount;
  }

  /// key: radius, value: tiles
  Map<double, List<Tile>> toRadius() => {};
}

class TileCalc {
  static TileEstimateResult estimateTileCount(
    LatLng centerPoint, {
    required Map<int, double> radiuses,
  }) {
    // Verify input - centerPoint.
    _pointIsWithinWebMercator(centerPoint);

    // Sort radiuses, starting with the widest radius.
    var _sortedRadiuses = _sortRadiusBuffers(radiuses);

    // Verify if widest radius will be outside Web Mercator.
    _isOutsideWebMercator(centerPoint, radiuses.values.first);

    // Verify input - radiuses (both zoom and radius) and setting minZoom.
    var minZoom = _checkRadiusBuffersAndReturnMinZoom(_sortedRadiuses);

    // Remove radiuses that have already been covered by a wider radius.
    _sortedRadiuses = _removeUnusedRadiusBuffers(_sortedRadiuses);

    // The map where we keep the results to be returned.
    var _map = <int, int>{};

    // Iterate through the radiuses starting with widest.
    var _currentZoom = minZoom;
    for (var _radius in _sortedRadiuses) {
      // Iterate through the relevant zoom level for the current radius add calculated tiles to the result.
      while (_currentZoom <= _radius.key) {
        _map[_currentZoom] = _estimateTileCount(centerPoint, _currentZoom, _radius.value);
        _currentZoom++;
      }
    }
    return TileEstimateResult(_map);
  }

  /// The listTilesWithinRadius will calculate tiles for one or more circles on a map with the same center point.
  ///
  /// The tiles will be returned in a "TileResult" object, sorted on Zoom level and distance from the center point.
  /// The center point must be a point in LatLong format valid in the Web Mercator projection.
  /// The circles is shall be listed as pairs in a Map with Zoom and Radius.
  /// The function will do the following:
  /// - Verify all input values (center point, Zoom levels and radiuses)
  /// - Sort the circles starting with the widest
  /// - If the widest circle is not given the smallest Zoom level in the input, the function will override the given
  ///   input and download tiles for the widest circle using the smallest Zoom level in the input.
  /// - For each circle with a given Zoom level, the function will also download all tiles covering from lower Zoom levels down
  ///   to the smallest Zoom level in the input that covers the circle.
  static TileResult listTilesWithinRadius(
    LatLng centerPoint, {
    required Map<int, double> radiuses,
  }) {
    // Verify input - centerPoint
    _pointIsWithinWebMercator(centerPoint);

    // Sort radiuses, starting with the widest radius.
    var _sortedRadiuses = _sortRadiusBuffers(radiuses);

    // Verify input - radiuses (both zoom and radius) and setting minZoom.
    var minZoom = _checkRadiusBuffersAndReturnMinZoom(_sortedRadiuses);

    // Remove radiuses that have already been covered by a wider radius.
    _sortedRadiuses = _removeUnusedRadiusBuffers(_sortedRadiuses);

    // The list where we keep the results to be returned.
    final _result = <int, List<Tile>>{};

    // Iterate through the radiuses starting with widest.
    final _tilesForZoomLevel = TilesForZoomLevel();
    var _currentZoom = minZoom;
    for (var _radius in _sortedRadiuses) {
      // Iterate through the relevant zoom level for the current radius add calculated tiles to the result.
      while (_currentZoom <= _radius.key) {
        _result[_currentZoom] = _tilesForZoomLevel.fillTilesForZoomLevel(centerPoint, _radius.value, _currentZoom);
        _currentZoom++;
      }
    }
    return TileResult(_result);
  }

  /// The listTilesForPointGeometry will calculate tiles for a Geometry object of type POINT.
  ///
  /// The tiles will be returned in a "TileResult" object, sorted on Zoom level and distance from the Point or
  /// a point in the  given by the user in LatLng format. The user needs to provide a minimum and maximum Zoom level
  /// for tiles to be listed.
  /// As an option, the user can provide a map of buffers with Zoom levels. The function will download tiles for the
  /// given buffer up to the given Zoom level. If a Zoom level from a buffer is outside the given minimum og maximum
  /// Zoom level, the Zoom level from the buffer will override.
  ///
  /// The function does currently not support buffers that spans over equator, the date line or far outside it's UTM
  /// zone.
  static TileResult listTilesForPointGeometry(List<LatLng> _vertices, int _minZoom, int _maxZoom,
      {LatLng? sortFromPoint, Map<int, double> buffers = const {}}) {
    final _tilesForGeometry = TilesForGeometry();
    return _tilesForGeometry.listTilesForGeometry('POINT', _vertices, _minZoom, _maxZoom,
        sortFromPoint: sortFromPoint, buffers: buffers);
  }

  /// The listTilesForPointGeometry will calculate tiles for a Geometry object of type LINESTRING.
  ///
  /// The tiles will be returned in a "TileResult" object, sorted on Zoom level and distance from the center of the
  /// LINESTRING or a point in the  given by the user in LatLng format. The user needs to provide a minimum and maximum
  /// Zoom level for tiles to be listed.
  /// As an option, the user can provide a map of buffers with Zoom levels. The function will download tiles for the
  /// given buffer up to the given Zoom level. If a Zoom level from a buffer is outside the given minimum og maximum
  /// Zoom level, the Zoom level from the buffer will override.
  ///
  /// The function does currently not support linestring or buffers that spans over equator, the date line or far outside it's UTM
  /// zone.
  static TileResult listTilesForLinestringGeometry(List<LatLng> _vertices, int _minZoom, int _maxZoom,
      {LatLng? sortFromPoint, Map<int, double> buffers = const {}}) {
    final _tilesForGeometry = TilesForGeometry();
    return _tilesForGeometry.listTilesForGeometry('LINESTRING', _vertices, _minZoom, _maxZoom,
        sortFromPoint: sortFromPoint, buffers: buffers);
  }

  /// The listTilesForPointGeometry will calculate tiles for a Geometry object of type POLYGON.
  ///
  /// The tiles will be returned in a "TileResult" object, sorted on Zoom level and distance from the center of the
  /// POLYGON or a point in the  given by the user in LatLng format. The user needs to provide a minimum and maximum
  /// Zoom level for tiles to be listed.
  /// As an option, the user can provide a map of buffers with Zoom levels. The function will download tiles for the
  /// given buffer up to the given Zoom level. If a Zoom level from a buffer is outside the given minimum og maximum
  /// Zoom level, the Zoom level from the buffer will override.
  ///
  /// The function does currently not support polygon or buffers that spans over equator, the date line or far outside it's UTM
  /// zone.
  static TileResult listTilesForPolygonGeometry(List<LatLng> _vertices, int _minZoom, int _maxZoom,
      {LatLng? sortFromPoint, Map<int, double> buffers = const {}}) {
    final _tilesForGeometry = TilesForGeometry();
    return _tilesForGeometry.listTilesForGeometry('POLYGON', _vertices, _minZoom, _maxZoom,
        sortFromPoint: sortFromPoint, buffers: buffers);
  }
}

class Tile implements Comparable<Tile> {
  final int tileX;
  final int tileY;
  final int zoom;

  Tile(
    this.tileX,
    this.tileY,
    this.zoom,
  );

  @override
  int compareTo(Tile other) {
    var zoomDifference = zoom - other.zoom;
    var tileXDifference = tileX - other.tileX;
    var tileYDifference = tileY - other.tileY;
    return (zoomDifference != 0)
        ? zoomDifference
        : (tileYDifference != 0)
            ? tileYDifference
            : tileXDifference;
  }

  void printTile() => print('Tile x=' + tileX.toString() + ', y=' + tileY.toString() + ', z=' + zoom.toString());

  String toWorldCoordinateWKT() {
    final tileSize = 256; //TileSize
    final northWestX = tileSize * tileX / pow(2, zoom);
    final northWestY = tileSize * tileY / pow(2, zoom);
    final southEastX = tileSize * (tileX + 1) / pow(2, zoom);
    final southEastY = tileSize * (tileY + 1) / pow(2, zoom);

    return 'POLYGON ((' +
        northWestX.toString() +
        ' ' +
        northWestY.toString() +
        ', ' +
        southEastX.toString() +
        ' ' +
        northWestY.toString() +
        ', ' +
        southEastX.toString() +
        ' ' +
        southEastY.toString() +
        ', ' +
        northWestX.toString() +
        ' ' +
        southEastY.toString() +
        ', ' +
        northWestX.toString() +
        ' ' +
        northWestY.toString() +
        ' ))';
  }

  jts.Geometry toWorldCoordinateGeometry() {
    final rdr = jts.WKTReader();
    return rdr.read(toWorldCoordinateWKT())!;
  }

  bool tileIsWithinPolygon(jts.Geometry _polygon) {
    return toWorldCoordinateGeometry().within(_polygon);
  }

  bool tileOverlapsPolygon(jts.Geometry _polygon) {
    return toWorldCoordinateGeometry().overlaps(_polygon);
  }

  bool tileIntersectsPolygon(jts.Geometry _polygon) {
    return toWorldCoordinateGeometry().intersects(_polygon);
  }
}

class TilesForZoomLevel {
  var _crossWest = false;
  var _crossEast = false;

  List<Tile> fillTilesForZoomLevel(LatLng centerPoint, double radius, int zoom) {
    // 'results' will store the tiles before filtering and sorting
    var results = SplayTreeSet<Tile>((a, b) => a.compareTo(b));

    // The function will decided if a tile is inside the circle by checking if it's corners are inside the given radius.
    // As the circle can tangent the top, left, right and bottom tiles without any of their corners being inside the
    // circle, these tiles are added separately. They will also be used as outer limits.
    final distance = Distance();
    final centerTile = _latlng2tile(centerPoint, zoom);
    final northTile = _setNorthTile(centerPoint, radius, zoom);
    final southTile = _setSouthTile(centerPoint, radius, zoom);
    final westTile = _latlng2tile(distance.offset(centerPoint, radius, 270), zoom);
    final eastTile = _latlng2tile(distance.offset(centerPoint, radius, 90), zoom);

    results.add(northTile);
    results.add(southTile);
    results.add(westTile);
    results.add(eastTile);

    // Variables used to iterate from North to South, from West to East.
    var currentY = northTile.tileY;
    var currentWestX = northTile.tileX;
    var currentEastX = northTile.tileX;

    // Iterating through circle given by radius.
    while (currentY <= southTile.tileY) {
      currentWestX = _updateCurrentWestX(centerPoint, radius, zoom, currentY, currentWestX, centerTile.tileX);
      currentEastX = _updateCurrentEastX(centerPoint, radius, zoom, currentY, currentEastX, centerTile.tileX);

      // If the radiuses crosses X=0 from both sides, all tiles on that Y-level should be included. This means that we
      // have gone around the globe, therefore currentWestX/currentEastX values are set to start searching from the
      // opposite side of the globe.
      if (_crossWest && _crossEast) {
        for (var x = 0; x < pow(2, zoom); x++) {
          results.add(Tile(x, currentY, zoom));
        }
        currentWestX = centerTile.tileX + pow(2, zoom) ~/ 2 + 1;
        currentEastX = centerTile.tileX + pow(2, zoom) ~/ 2 - 1;
        if (currentWestX >= pow(2, zoom)) currentWestX = currentWestX - pow(2, zoom) as int;
        if (currentEastX >= pow(2, zoom)) currentEastX = currentEastX - pow(2, zoom) as int;
      } else if (currentWestX <= currentEastX) {
        for (var x = currentWestX; x <= currentEastX; x++) {
          results.add(Tile(x, currentY, zoom));
        }
      } else {
        for (var x = currentWestX; x < pow(2, zoom); x++) {
          results.add(Tile(x, currentY, zoom));
        }
        for (var x = 0; x <= currentEastX; x++) {
          results.add(Tile(x, currentY, zoom));
        }
      }
      _crossWest = false;
      _crossEast = false;
      currentY++;
    }

    // Sorting output
    var sortingMap = <Tile, int>{};
    for (var tile in results) {
      sortingMap[tile] = pow((tile.tileY - centerTile.tileY), 2) + pow((tile.tileX - centerTile.tileX), 2) as int;
    }
    var sortedResult = sortingMap.keys.toList(growable: false)
      ..sort((k1, k2) => sortingMap[k1]!.compareTo(sortingMap[k2]!));

    return sortedResult;
  }

  Tile _setNorthTile(LatLng centerPoint, double radius, int zoom) {
    final distance = Distance();
    final northPoint = LatLng(85.0511, centerPoint.longitude);
    if (radius < distance.distance(centerPoint, northPoint)) {
      return _latlng2tile(distance.offset(centerPoint, radius, 0), zoom);
    } else {
      return Tile(_latlng2tile(northPoint, zoom).tileX, 0, zoom);
    }
  }

  Tile _setSouthTile(LatLng centerPoint, double radius, int zoom) {
    final distance = Distance();
    var southPoint = LatLng(-85.0511, centerPoint.longitude);
    if (radius < distance.distance(centerPoint, southPoint)) {
      return _latlng2tile(distance.offset(centerPoint, radius, 180), zoom);
    } else {
      return Tile(_latlng2tile(southPoint, zoom).tileX, pow(2, zoom) - 1 as int, zoom);
    }
  }

  int _updateCurrentWestX(LatLng centerPoint, double radius, int zoom, int currentY, int currentWestX, midX) {
    var _xInside = -pow(2, zoom);
    var _xOutside = _xInside;

    // Go one tile west, and adjust if x is outside projection.
    if (zoom != 0) currentWestX--;
    if (currentWestX == -1) currentWestX = _adjustX(pow(2, zoom) - 1 as int);
    if (currentWestX == pow(2, zoom)) currentWestX = _adjustX(0);

    do {
      if (_isWithinRadius(centerPoint, _tile2latlng(currentWestX + 1, currentY, zoom), radius) ||
          _isWithinRadius(centerPoint, _tile2latlng(currentWestX + 1, currentY + 1, zoom), radius)) {
        _xInside = currentWestX;
        currentWestX--;
      } else {
        _xOutside = currentWestX;
        currentWestX++;
      }

      // Adjust if x is outside projection.
      if (currentWestX == -1) currentWestX = _adjustX(pow(2, zoom) - 1 as int);
      if (currentWestX == pow(2, zoom)) currentWestX = _adjustX(0);
    } while (((_xInside - _xOutside != 1) && (_xInside - _xOutside != -pow(2, zoom) + 1)) && currentWestX != midX);

    if (_xInside < 0) _xInside = _adjustCrossX(midX, false);
    if (_xOutside < 0) _xInside = _adjustCrossX(midX, true);

    return _xInside as int;
  }

  int _updateCurrentEastX(LatLng centerPoint, double radius, int zoom, int currentY, int currentEastX, midX) {
    var _xInside = -pow(2, zoom);
    var _xOutside = _xInside;

    // Go one tile east, and adjust if x is outside projection.
    if (zoom != 0) currentEastX++;
    if (currentEastX == -1) currentEastX = _adjustX(pow(2, zoom) - 1 as int);
    if (currentEastX == pow(2, zoom)) currentEastX = _adjustX(0);

    do {
      if (_isWithinRadius(centerPoint, _tile2latlng(currentEastX, currentY, zoom), radius) ||
          _isWithinRadius(centerPoint, _tile2latlng(currentEastX, currentY + 1, zoom), radius)) {
        _xInside = currentEastX;
        currentEastX++;
      } else {
        _xOutside = currentEastX;
        currentEastX--;
      }

      // Adjust if x is outside projection.
      if (currentEastX == -1) currentEastX = _adjustX(pow(2, zoom) - 1 as int);
      if (currentEastX == pow(2, zoom)) currentEastX = _adjustX(0);
    } while (((_xOutside - _xInside != 1) && (_xOutside - _xInside != -pow(2, zoom) + 1)) && currentEastX != midX);

    if (_xInside < 0) _xInside = _adjustCrossX(midX, false);
    if (_xOutside < 0) _xInside = _adjustCrossX(midX, true);

    return _xInside as int;
  }

  int _adjustCrossX(int midX, bool _cross) {
    _crossWest = _cross;
    _crossEast = _cross;
    return midX;
  }

  int _adjustX(int i) {
    if (i == 0) {
      _crossWest = false;
      _crossEast = true;
    } else {
      _crossWest = true;
      _crossEast = false;
    }
    return i;
  }
}

class TilesForGeometry {
  final _resultingTiles = SplayTreeSet<Tile>((a, b) => a.compareTo(b));
  final Map<int, jts.Geometry> _geometriesMap = {};

  TileResult listTilesForGeometry(String _geometryType, List<LatLng> _polygon, int _minZoom, int _maxZoom,
      {LatLng? sortFromPoint, Map<int, double> buffers = const {}}) {
    // Sort buffers by size, starting with the widest buffer.
    var _sortedBuffers = _sortRadiusBuffers(buffers);

    // Verify input - buffers (both zoom and radius) and setting minZoom.
    _minZoom = min(_minZoom, _checkRadiusBuffersAndReturnMinZoom(_sortedBuffers));

    // Remove radiuses that have already been covered by a wider radius.
    _sortedBuffers = _removeUnusedRadiusBuffers(_sortedBuffers);

    // Create Map of buffers with points inn WKT format.
    final _bufferMap = bufferMap(_geometryType, _sortedBuffers.map((e) => e.value).toList(), _polygon);
    _bufferMap[0] = _polygon;

    // Convert Map of buffers in WKT format to Map of Geometry objects.
    bufferGeometries(_bufferMap, _sortedBuffers, _maxZoom, _geometryType, _polygon);

    // Add _maxZoom to list of buffers if it not represented.
    _sortedBuffers = _addMaxZoomToBufferIfNeeded(_sortedBuffers, _maxZoom);

    // Calculate tiles for all Zoom levels.
    _getTiles(_sortedBuffers, _minZoom);

    // Sort tiles per Zoom level and from given sortFromPoint or midpoint per Zoom level.
    var sortedResult = _sortResult(_minZoom, _sortedBuffers.last.key, sortFromPoint: sortFromPoint);

    return TileResult(sortedResult);
  }

  /// The tileFinder function check whether a Geometry intersects or contains a given tile.
  ///
  /// If it intersects, it is
  /// added to the result and then split in four (the next Zoom level), where the the tiles from the split is tested
  /// recursively against the same function. If a tile is fully contained inside a POLYGON, it is sent to a separate
  /// function (addContainedTiles) that will calculate all tiles for higher Zoom levels.
  void _tileFinder(Tile _tile, int _startZoom, int _stopZoom) {
    final _tileGeometry = _tile.toWorldCoordinateGeometry();
    if (_tile.zoom <= _stopZoom) {
      if (_geometriesMap[max(_tile.zoom, _startZoom)]!.contains(_tileGeometry)) {
        _addContainedTiles(_tile, _startZoom, _stopZoom);
      } else if (_geometriesMap[max(_tile.zoom, _startZoom)]!.intersects(_tileGeometry)) {
        if (_tile.zoom >= _startZoom) _resultingTiles.add(_tile);
        _tileFinder(Tile(_tile.tileX * 2, _tile.tileY * 2, _tile.zoom + 1), _startZoom, _stopZoom);
        _tileFinder(Tile(_tile.tileX * 2, _tile.tileY * 2 + 1, _tile.zoom + 1), _startZoom, _stopZoom);
        _tileFinder(Tile(_tile.tileX * 2 + 1, _tile.tileY * 2 + 1, _tile.zoom + 1), _startZoom, _stopZoom);
        _tileFinder(Tile(_tile.tileX * 2 + 1, _tile.tileY * 2, _tile.zoom + 1), _startZoom, _stopZoom);
      }
    }
  }

  /// The function will add all children tiles for   a Tile to the result set
  void _addContainedTiles(Tile _tile, int startZoom, int stopZoom) {
    if (_tile.zoom >= startZoom) _resultingTiles.add(_tile);
    if (_tile.zoom < stopZoom) {
      _addContainedTiles(Tile(_tile.tileX * 2, _tile.tileY * 2, _tile.zoom + 1), startZoom, stopZoom);
      _addContainedTiles(Tile(_tile.tileX * 2, _tile.tileY * 2 + 1, _tile.zoom + 1), startZoom, stopZoom);
      _addContainedTiles(Tile(_tile.tileX * 2 + 1, _tile.tileY * 2 + 1, _tile.zoom + 1), startZoom, stopZoom);
      _addContainedTiles(Tile(_tile.tileX * 2 + 1, _tile.tileY * 2, _tile.zoom + 1), startZoom, stopZoom);
    }
  }

  /// The function will calculate the buffers for a given geometry with buffer sizes
  /// The function wil convert from LatLng to UTM before adding buffer, and then back to LatLng. This is done to be
  /// able to add the buffer using meters.
  Map<double, List<LatLng>> bufferMap(String _geometryType, List<double> _buffers, List<LatLng> _vertices) {
    // Create list to store converted input vertices in LatLng and UTM as Coordinates.
    final listLatLngCoordinates = <jts.Coordinate>[];
    final listUTMCoordinates = <jts.Coordinate>[];

    // Convert the vertices to Coordinates and store them.
    for (final vertex in _vertices) {
      listLatLngCoordinates.add(jts.Coordinate(vertex.longitude, vertex.latitude));
      final utm = UTM.fromLatLon(lat: vertex.latitude, lon: vertex.longitude);
      listUTMCoordinates.add(jts.Coordinate(utm.easting, utm.northing));
    }

    // Convert list of LatLng Coordinates to Geometry object.
    final geoLatLng = _listCoordinates2Geometry(4236, _geometryType, listLatLngCoordinates);

    // Get the center of the Geometry object, will be used to find correct UTM SRID.
    final _LatLngCenter = geoLatLng.getCentroid();

    // Find UTM SRID using _LatLngCenter i Geometry.
    final _SRID =
        _getSRID(_LatLngCenter.getY(), UTM.fromLatLon(lat: _LatLngCenter.getY(), lon: _LatLngCenter.getX()).zoneNumber);

    // Find correct UTMzone for the Geometry.
    final _UTMCenter = UTM.fromLatLon(lat: _LatLngCenter.getY(), lon: _LatLngCenter.getX());

    // Create UTM geometry using SRID from and UTM Coordinates.
    final geoUTM = _listCoordinates2Geometry(_SRID, _geometryType, listUTMCoordinates);

    // This is were we store the calculated buffers.
    final _result = <double, List<LatLng>>{};

    // Iterate through each buffer value, add the buffer to the Geometry and then convert the coordinates back to LatLng.
    for (final bufferValue in _buffers) {
      _result[bufferValue] = [];
      final buffer = geoUTM.buffer(bufferValue);
      buffer.getCoordinates().forEach((element) {
        final p = UTM.fromUtm(
            easting: element.x,
            northing: element.y,
            zoneNumber: _UTMCenter.zoneNumber,
            zoneLetter: _UTMCenter.zoneLetter);
        _result[bufferValue]!.add(LatLng(p.lat, p.lon));
      });
    }
    return _result;
  }

  /// The function will convert a list of Coordinates to a Geometry of the given type.
  jts.Geometry _listCoordinates2Geometry(int _SRID, String _geometryType, List<jts.Coordinate> listCoordinates) {
    final _geometryFactory = jts.GeometryFactory.withPrecisionModelSrid(jts.PrecisionModel(), _SRID);

    jts.Geometry _geometry;
    switch (_geometryType) {
      case 'POINT':
        _geometry = _geometryFactory.createPoint(listCoordinates.single);
        break;
      case 'LINESTRING':
        _geometry = _geometryFactory.createLineString(listCoordinates);
        break;
      case 'POLYGON':
        _geometry = _geometryFactory.createPolygonFromCoords(listCoordinates);
        break;
      default:
        _geometry = _geometryFactory.createPoint(listCoordinates.single);
          throw ArgumentError.value(_geometryType, '_geometryType', 'An unknown Geometry type has been used.');
    }
    return _geometry;
  }

  /// Convert Map of buffers in WKT format to Map of Geometry objects
  void bufferGeometries(Map<double, List<LatLng>> _bufferList, List<MapEntry<int, double>> _sortedBuffers, int _maxZoom,
      String _geometryType, List<LatLng> _geometry) {
    var _currentZoom = 0; // Variable used when iterating through each Zoom level.

    // Iterate through each buffer.
    for (var i = 0; i < _sortedBuffers.length; i++) {
      // Iterate through the relevant zoom and add corresponding buffer.
      while (_currentZoom <= _sortedBuffers[i].key) {
        _geometriesMap[_currentZoom] =
            jts.WKTReader().read(_latLngList2WKTGeometry('POLYGON', _bufferList[_sortedBuffers[i].value]!))!;
        _currentZoom++;
      }
    }
    _currentZoom--;

    // Add original geometry with maxZoom to result map if maxZoom is not already in the result map
    if (_geometriesMap.isEmpty || _currentZoom < _maxZoom) {
      _currentZoom++;
      while (_currentZoom <= _maxZoom) {
        _geometriesMap[_currentZoom] = jts.WKTReader().read(_latLngList2WKTGeometry(_geometryType, _geometry))!;
        _currentZoom++;
      }
      _currentZoom--;
    }
  }

  /// Add _maxZoom to list of buffers if it not represented.
  List<MapEntry<int, double>> _addMaxZoomToBufferIfNeeded(List<MapEntry<int, double>> _sortedBuffers, int _maxZoom) {
    if (_sortedBuffers.isNotEmpty) {
      if (_sortedBuffers.last.key < _maxZoom) _sortedBuffers.add(MapEntry(_maxZoom, 0));
    } else {
      _sortedBuffers.add(MapEntry(_maxZoom, 0));
    }
    return _sortedBuffers;
  }

  /// Calculate tiles for all Zoom levels.
  SplayTreeSet<Tile> _getTiles(List<MapEntry<int, double>> _sortedBuffers, int _minZoom) {
    final results = SplayTreeSet<Tile>((a, b) => a.compareTo(b)); // Where we store the results.
    var startZoom = _minZoom;
    for (var buffer in _sortedBuffers) {
      _tileFinder(Tile(0, 0, 0), startZoom, buffer.key);
      startZoom = buffer.key + 1;
    }
    return results;
  }

  /// Sort the results.
  ///
  /// The tiles are first sorted by Zoom level, then by distance to center (or a given point).
  Map<int, List<Tile>> _sortResult(int _minZoom, int highestZoom, {LatLng? sortFromPoint}) {
    // Create a map where we store the tiles in a list per Zoom level. Initialize each Zoom level to an empty list.
    final _sortedByZoomLevel = <int, List<Tile>>{}; // Where we store the tiles when sorted by Zoom level.
    for (var i = _minZoom; i <= highestZoom; i++) {
      _sortedByZoomLevel[i] = [];
    }

    // Add each tile to the correct list in the result map.
    for (final _tile in _resultingTiles) {
      _sortedByZoomLevel[_tile.zoom]!.add(_tile);
    }

    // Sort each Zoom level from distance to sortFromPoint or center.
    Point <double> p;
    if (sortFromPoint == null) {
      // If sortFromPoint is null, use center from Geometry.
      final centerPoint = _geometriesMap[highestZoom]!.getCentroid();
      p = Point(centerPoint.coordinates!.getX(0), centerPoint.coordinates!.getY(0));
    } else {
      // If sortFromPoint is given, convert it from LatLng.
      p = _convertLatLng2WorldCoordinate(sortFromPoint);
    }

    // Sorting tiles per Zoom level.
    var sortingMap = <Tile, int>{}; // Where we store the tiles after adding calculated distance to sorting point.
    final sortedResult = <int, List<Tile>>{}; // Where we store the result after sorting by distance.

    // Iterate through each Zoom level.
    for (var i = _minZoom; i <= highestZoom; i++) {
      // Get the tile address for the sorting point for the current Zoom level and clear the temporary storage map.
      final sortFromTile = _worldCoordinate2Tile(p.x, p.y, i);
      sortingMap.clear();

      // Iterate through all tiles for the Zoom level, and calculate distance the tile of the sort point.
      for (var tile in _sortedByZoomLevel[i]!) {
        sortingMap[tile] = pow((tile.tileX - sortFromTile.tileX), 2) + pow((tile.tileY - sortFromTile.tileY), 2) as int;
      }
      // Sort the tiles by distance.
      sortedResult[i] = sortingMap.keys.toList(growable: false)
        ..sort((k1, k2) => sortingMap[k1]!.compareTo(sortingMap[k2]!));
    }
    return sortedResult;
  }
}

Tile _latlng2tile(LatLng position, int zoom) {
  return Tile(_long2tileX(position.longitude, zoom), _lat2tileY(position.latitude, zoom), zoom);
}

int _long2tileX(double lon, int zoom) {
  //Adds 0.001 to avoid rounding errors
  var _x = ((lon + 180.0) / 360 * (1 << zoom) + 0.0001).floor();
  if (_x == pow(2, zoom)) {
    return 0;
  } else {
    return _x;
  }
}

int _lat2tileY(double lat, int zoom) {
  //Adds 0.001 to avoid rounding errors
  return ((1 - log(tan(degToRadian(lat)) + 1 / cos(degToRadian(lat))) / pi) / 2 * (1 << zoom) + 0.0001).floor();
}

double _tileX2long(int tileX, int zoom) {
  return tileX / (1 << zoom) * 360.0 - 180;
}

double _tileY2lat(int tileY, int zoom) {
  var n = pi - 2.0 * pi * tileY / (1 << zoom);
  return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
}

bool _isWithinRadius(LatLng position1, LatLng position2, double radius) {
  try {
    final distance = Distance(roundResult: false, calculator: Vincenty());
    return (distance(position1, position2) < radius);
  } catch (e) {
    final distance = Distance(roundResult: false, calculator: Haversine());
    return (distance(position1, position2) < radius);
  }
}

LatLng _tile2latlng(int tileX, int tileY, int zoom) {
  return LatLng(_tileY2lat(tileY, zoom), _tileX2long(tileX, zoom));
}

bool _pointIsWithinWebMercator(LatLng point) {
  if (point.latitude <= -85.0511 || point.latitude >= 85.0511) {
    throw ArgumentError.value(point.latitude, 'point.latitude', 'The latitude must be between +/-85.0511');
  }
  return false;
}

bool _isOutsideWebMercator(LatLng centerPoint, double radius) {
  final distance = Distance();
  final northPoint = LatLng(85.0511, centerPoint.longitude);
  final southPoint = LatLng(-85.0511, centerPoint.longitude);
  if ((radius > distance.distance(centerPoint, northPoint)) || (radius > distance.distance(centerPoint, southPoint))) {
    throw ArgumentError.value(radius, 'radius', 'Widest circle crosses latitude +/-85.0511');
  }
  return false;
}

int _estimateTileCount(LatLng centerPoint, int _currentZoom, double _radius) {
  final _tile = _latlng2tile(centerPoint, _currentZoom);
  final _startPos = _tile2latlng(_tile.tileX, _tile.tileY, _currentZoom);
  final _lngPos = _tile2latlng(_tile.tileX + 1, _tile.tileY, _currentZoom);
  final _latPos = _tile2latlng(_tile.tileX, _tile.tileY + 1, _currentZoom);
  final distance = Distance(roundResult: false, calculator: Vincenty());

  // lambda = radius / tile length
  final _averageTileLength = (distance(_startPos, _lngPos) + distance(_startPos, _latPos)) / 2;
  final _lambda = _radius / _averageTileLength;

  var sum1 = 0.0;
  for (var i = 1; i <= (_lambda).floor(); i++) {
    sum1 += (sqrt(pow(_lambda, 2) - pow((i - 0.5), 2) - 0.5)).ceilToDouble();
  }
  final n1 = 2 * (2 * _lambda).ceil() - 1 + 4 * sum1;
  return n1.toInt();
}

///Convert List of LatLng to Polygon with WorldCoordinate
String _latLngList2WKTGeometry(String _geometryType, List<LatLng> _polygon) {
  var _point = Point(0.0, 0.0);
  var _polygonWKT = _geometryType + ' (';
  if (_geometryType == 'POLYGON') _polygonWKT = _polygonWKT + '(';
  for (final element in _polygon) {
    _point = _convertLatLng2WorldCoordinate(element);
    _polygonWKT = _polygonWKT + _point.x.toString() + ' ';
    _polygonWKT = _polygonWKT + _point.y.toString() + ', ';
  }
  _polygonWKT = _polygonWKT.substring(0, _polygonWKT.length - 2) + ')';
  if (_geometryType == 'POLYGON') _polygonWKT = _polygonWKT + ')';
  return _polygonWKT;
}

///Convert LatLng to WorldCoordinate
Point<double> _convertLatLng2WorldCoordinate(LatLng _latLng) {
  const _tileSize = 256;
  var _sinY = sin((_latLng.latitude * pi) / 180);
  // Truncating to 0.9999 effectively limits latitude to 89.189. This is
  // about a third of a tile past the edge of the world tile.
  _sinY = min(max(_sinY, -0.9999), 0.9999);
  return Point(
      _tileSize * (0.5 + _latLng.longitude / 360), _tileSize * (0.5 - log((1 + _sinY) / (1 - _sinY)) / (4 * pi)));
}

Tile _worldCoordinate2Tile(double _x, double _y, int _zoom) {
  final x = ((_x * pow(2, _zoom)).floor() / 256).floor();
  final y = ((_y * pow(2, _zoom)).floor() / 256).floor();
  return Tile(x, y, _zoom);
}

int _getSRID(double _lat, int _zoneNumber) {
  var _return = 32000;
  if (_lat > 0) {
    _return = _return + 600;
  } else {
    _return = _return + 700;
  }
  return _return + _zoneNumber;
}

List<MapEntry<int, double>> _sortRadiusBuffers(Map<int, double> radiusBuffers) {
  return radiusBuffers.entries.toList()
    ..sort((e1, e2) {
      var diff = e2.value.compareTo(e1.value);
      if (diff == 0) diff = e1.key.compareTo(e2.key);
      return diff;
    });
}

List<MapEntry<int, double>> _removeUnusedRadiusBuffers(List<MapEntry<int, double>> _sortedBuffer) {
  var i = 0;
  while (i < _sortedBuffer.length - 1) {
    if (_sortedBuffer[i].key > _sortedBuffer[i + 1].key) {
      _sortedBuffer.removeAt(i + 1);
    } else {
      i++;
    }
  }
  return _sortedBuffer;
}

/// Verify input - radiuses (both zoom and radius) and setting minZoom
int _checkRadiusBuffersAndReturnMinZoom(List<MapEntry<int, double>> _sortedRadiusBuffers) {
  var minZoom = 20;
  for (var _zoomRadius in _sortedRadiusBuffers) {
    if (_zoomRadius.key < 0 || _zoomRadius.key > 20) {
      throw ArgumentError.value(_zoomRadius.key, '_zoomRadius.key', 'Zoom for given radius must be in 0->20');
    } else {
      if (_zoomRadius.key < minZoom) minZoom = _zoomRadius.key;
    }
    if (_zoomRadius.value <= 0 || _zoomRadius.value > 19000000) {
      throw ArgumentError.value(_zoomRadius.value, '_zoomRadius.value', 'Radius must be between 0 and 19000000');
    }
  }
  return minZoom;
}
