import 'package:tilecache_calc/tilecache_calc.dart';
import 'package:latlong2/latlong.dart';

void main() {
  var startTime = DateTime.now();
  print('');

  // Example 1
  print('Example 1: List tiles from a point, using 2 different zoom levels/radiuses');
  print('');
  final result1 = TileCalc.listTilesWithinRadius(LatLng(60, 10), radiuses: {18: 30, 20: 10});
  print('List of tiles when setting center to Latitude = 60 and Longitude = 10, \nthen requesting all tiles inside'
      'a 30 meter radius with Zoom level 18, \nand for zoom level 20 all tiles inside a 10 meter radius. '
      '\nAs zoom level 19 is between the two given zoom levels, \ntiles within 10 meters (the radius for the next '
      'higher zoom level) \nwill also be included.');
  final _list = result1.toList();
  for (final _tile in _list) {
    _tile.printTile();
  }

  print('');
  print('');

  // Example 2
  print('Example 2: Calculate tiles per zoom level, using a point and three different zoom levels/radiuses');
  print('');
  print('Calculating tiles for a point where the for zoom level = 3, all tiles within a 1000 km radius are included.\n'
      'For zoom level 4 to 15, all tiles within 100 km are included. \n'
      'For zoom level 16 and 17, tiles within 10 km are included.');
  var result2 = TileCalc.listTilesWithinRadius(LatLng(60, 10),
      radiuses: {3: 1000000, 15: 100000, 17: 10000});
  print('Count per zoom level');
  var _map = result2.toZoomCount();
  _map.forEach((key, value) {
    print('Zoom: ' + key.toString() + ', count of tiles: ' + value.toString());
  });
  print('Total count of tiles: ' + result2.toList().length.toString());

  print('');
  print('');

  // Example 3
  print('Example 3: Estimate tiles per zoom level, using a point and three different zoom levels/radiuses');
  print('');
  print('Estimating tiles for a point where the for zoom level = 3, all tiles within a 1000 km radius are included.\n'
      'For zoom level 4 to 15, all tiles within 100 km are included. \n'
      'For zoom level 16 and 17, tiles within 10 km are included.');
  print('Estimate per Zoom level');

  final result3 = TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375),
      radiuses: {3: 1000000, 15: 100000, 17: 10000});
  result3.toZoomCount().forEach((key, value) {
    print('Zoom ' + key.toString() + ', estimate: ' + value.toString());
  });
  print('Total estimate of tiles: ' + result3.totalCount().toString());

  final a = LatLng(60.536106554791331, 8.217904530465603);
  final b = LatLng(60.540094999596477, 8.214778918772936);
  final c = LatLng(60.541747910901904, 8.215941907837987);
  final d = LatLng(60.540310665965081, 8.222483983263373);
  final e = LatLng(60.536753302440047, 8.220993848517537);

  print('');
  print('');

  // Example 4
  print('Example 4: Calculate tiles for a POLYGON, number of tiles listed per zoom level');
  print('');
  print('This function is used to calculate the tiles that are partly or completely covered by a POLYGON.\n'
      'Minimum zoom level is set to 10, and the maximum to 16. But as the buffers are given for zoom levels \n'
      ' as high as 19, the maximum will be overwritten and set to 19.');
  print('Count per zoom level');
  final result4 = TileCalc.listTilesForPolygonGeometry([a, b, c, d, e, a], 10, 16,
      sortFromPoint: LatLng(0, 0), buffers: {18: 50, 19: 20});
  result4.toZoomCount().forEach((key, value) {
    print('Zoom ' + key.toString() + ', count of tiles: ' + value.toString());
  });
  print('Total tiles intersecting POLYGON: ' + result4.toList().length.toString());

  print('');
  print('');

  // Example 5
  print('Example 5: Calculate tiles for a LINESTRING, number of tiles listed per zoom level');
  print('');
  print('This function is used to calculate the tiles that are partly or completely covered by a LINESTRING.\n'
      'Minimum zoom level is set to 10, and the maximum to 19. For zoom level 19, a buffer of 20 meters is used.\n'
      'The tiles are sorted from latitude 60, longitude 5.');
  print('Count per zoom level');
  final result5 =
      TileCalc.listTilesForLinestringGeometry([a, b, c, d, e], 10, 19, sortFromPoint: LatLng(60, 5), buffers: {19: 20});
  result5.toZoomCount().forEach((key, value) {
    print('Zoom ' + key.toString() + ', count of tiles: ' + value.toString());
  });
  print('Total tiles intersecting LINESTRING: ' + result5.toList().length.toString());


  print('');
  print('');

  // Example 6
  print('Example 6: Calculate tiles for a POINT, number of tiles listed per zoom level');
  print('');
  print('This function is used to calculate the tiles that are partly or completely covered by a POINT and it''s.\n'
      'buffers. Minimum zoom level is set to 15, and the maximum to 20. For zoom level 15 to 17, a buffer\n'
      'of 2000 meters is used. For zoom level 18 to 19, a buffer of 50 meters is used. For zoom 20, no buffer is used');
  print('Count per zoom level');

  final result6 = TileCalc.listTilesForPointGeometry([a], 15, 20, buffers: {17: 2000, 19: 50});
  result6.toZoomCount().forEach((key, value) {
    print('Point Zoom ' + key.toString() + ', count of tiles: ' + value.toString());
  });
  print('Total tiles intersecting POINT: ' + result6.toList().length.toString());

  print(DateTime.now().difference(startTime));
}
