import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:latlong2/latlong.dart';

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

class TileCalc {
  /// The listTilesWithinRadius will calculate tiles for one or more circles on a map with the same center point.
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
    @required Map<int, double> radiuses,
  }) {
    // Verify input - centerPoint
    if (centerPoint.latitude <= -85.0511 || centerPoint.latitude >= 85.0511) {
      throw ArgumentError.value(
          centerPoint.latitude, 'centerPoint.latitude', 'The latitude must be between +/-85.0511');
    }

    // Sort radiuses, starting with the widest radius
    var _sortedRadiuses = radiuses.entries.toList()
      ..sort((e1, e2) {
        var diff = e2.value.compareTo(e1.value);
        if (diff == 0) diff = e2.key.compareTo(e1.key);
        return diff;
      });

    // Verify input - radiuses (both zoom and radius) and setting minZoom
    var minZoom = 20;
    for (var _zoomRadius in _sortedRadiuses) {
      if (_zoomRadius.key < 0 || _zoomRadius.key > 20) {
        throw ArgumentError.value(_zoomRadius.key, '_zoomRadius.key', 'Zoom for given radius must be in 0->20');
      } else {
        if (_zoomRadius.key < minZoom) minZoom = _zoomRadius.key;
      }
      if (_zoomRadius.value < 0 || _zoomRadius.value > 19000000) {
        throw ArgumentError.value(_zoomRadius.value, '_zoomRadius.value', 'Radius must be between 0 and 19000000');
      }
    }

    // The list where we keep the results to be returned
    final _result = <int, List<Tile>>{};

    // Iterate through the radiuses starting with widest
    final _tilesForZoomLevel = TilesForZoomLevel();
    var _currentZoom = minZoom;
    for (var _radius in _sortedRadiuses) {
      // Iterate through the relevant zoom level for the current radius add calculated tiles to the result
      while (_currentZoom <= _radius.key) {
        _result[_currentZoom] = _tilesForZoomLevel.fillTilesForZoomLevel(centerPoint, _radius.value, _currentZoom);
        _currentZoom++;
      }
    }

    return TileResult(_result);
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
//    var distance = Distance(calculator: Haversine());
    var distance = Distance();
    final centerTile = _latlon2tile(centerPoint, zoom);
    final northTile = _setNorthTile(centerPoint, radius, zoom);
    final southTile = _setSouthTile(centerPoint, radius, zoom);
    final westTile = _latlon2tile(distance.offset(centerPoint, radius, 270), zoom);
    final eastTile = _latlon2tile(distance.offset(centerPoint, radius, 90), zoom);

    results.add(northTile);
    results.add(southTile);
    results.add(westTile);
    results.add(eastTile);

    // Variables used to iterate from North to South, from West to East
    var currentY = northTile.tileY;
    var currentWestX = northTile.tileX;
    var currentEastX = northTile.tileX;

    // Iterating through circle given by radius
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
        if (currentWestX >= pow(2, zoom)) currentWestX = currentWestX - pow(2, zoom);
        if (currentEastX >= pow(2, zoom)) currentEastX = currentEastX - pow(2, zoom);
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

    //Sorting output
    var sortingMap = <Tile, int>{};
    for (var tile in results) {
      sortingMap[tile] = pow((tile.tileY - centerTile.tileY), 2) + pow((tile.tileX - centerTile.tileX), 2);
    }
    var sortedResult = sortingMap.keys.toList(growable: false)
      ..sort((k1, k2) => sortingMap[k1].compareTo(sortingMap[k2]));

    return sortedResult;
  }

  Tile _setNorthTile(LatLng centerPoint, double radius, int zoom) {
    var distance = Distance();
    final northPoint = LatLng(85.0511, centerPoint.longitude);
    if (radius < distance.distance(centerPoint, northPoint)) {
      return _latlon2tile(distance.offset(centerPoint, radius, 0), zoom);
    } else {
      return Tile(_latlon2tile(northPoint, zoom).tileX, 0, zoom);
    }
  }

  Tile _setSouthTile(LatLng centerPoint, double radius, int zoom) {
    var distance = Distance();
    var southPoint = LatLng(-85.0511, centerPoint.longitude);
    if (radius < distance.distance(centerPoint, southPoint)) {
      return _latlon2tile(distance.offset(centerPoint, radius, 180), zoom);
    } else {
      return Tile(_latlon2tile(southPoint, zoom).tileX, pow(2, zoom) - 1, zoom);
    }
  }

  int _updateCurrentWestX(LatLng centerPoint, double radius, int zoom, int currentY, int currentWestX, midX) {
    var _xInside = -pow(2, zoom);
    var _xOutside = _xInside;

    //Go one tile west, and adjust if x is outside projection
    if (zoom != 0) currentWestX--;
    if (currentWestX == -1) currentWestX = _adjustX(pow(2, zoom) - 1);
    if (currentWestX == pow(2, zoom)) currentWestX = _adjustX(0);

    do {
      if (_isWithinRadius(centerPoint, _tile2latlon(currentWestX + 1, currentY, zoom), radius) ||
          _isWithinRadius(centerPoint, _tile2latlon(currentWestX + 1, currentY + 1, zoom), radius)) {
        _xInside = currentWestX;
        currentWestX--;
      } else {
        _xOutside = currentWestX;
        currentWestX++;
      }

      //Adjust if x is outside projection
      if (currentWestX == -1) currentWestX = _adjustX(pow(2, zoom) - 1);
      if (currentWestX == pow(2, zoom)) currentWestX = _adjustX(0);
    } while (((_xInside - _xOutside != 1) && (_xInside - _xOutside != -pow(2, zoom) + 1)) && currentWestX != midX);

    if (_xInside < 0) _xInside = _adjustCrossX(midX, false);
    if (_xOutside < 0) _xInside = _adjustCrossX(midX, true);

    return _xInside;
  }

  int _updateCurrentEastX(LatLng centerPoint, double radius, int zoom, int currentY, int currentEastX, midX) {
    var _xInside = -pow(2, zoom);
    var _xOutside = _xInside;

    //Go one tile east, and adjust if x is outside projection
    if (zoom != 0) currentEastX++;
    if (currentEastX == -1) currentEastX = _adjustX(pow(2, zoom) - 1);
    if (currentEastX == pow(2, zoom)) currentEastX = _adjustX(0);

    do {
      if (_isWithinRadius(centerPoint, _tile2latlon(currentEastX, currentY, zoom), radius) ||
          _isWithinRadius(centerPoint, _tile2latlon(currentEastX, currentY + 1, zoom), radius)) {
        _xInside = currentEastX;
        currentEastX++;
      } else {
        _xOutside = currentEastX;
        currentEastX--;
      }

      //Adjust if x is outside projection
      if (currentEastX == -1) currentEastX = _adjustX(pow(2, zoom) - 1);
      if (currentEastX == pow(2, zoom)) currentEastX = _adjustX(0);
    } while (((_xOutside - _xInside != 1) && (_xOutside - _xInside != -pow(2, zoom) + 1)) && currentEastX != midX);

    if (_xInside < 0) _xInside = _adjustCrossX(midX, false);
    if (_xOutside < 0) _xInside = _adjustCrossX(midX, true);

    return _xInside;
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

  Tile _latlon2tile(LatLng position, int zoom) {
    return Tile(_long2tileX(position.longitude, zoom), _lat2tileY(position.latitude, zoom), zoom);
  }

  LatLng _tile2latlon(int tile_x, int tile_y, int zoom) {
    return LatLng(_tileY2lat(tile_y, zoom), _tileX2long(tile_x, zoom));
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

  double _tileX2long(int tile_x, int zoom) {
    return tile_x / (1 << zoom) * 360.0 - 180;
  }

  double _tileY2lat(int tile_y, int zoom) {
    var n = pi - 2.0 * pi * tile_y / (1 << zoom);
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
}
