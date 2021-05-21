import 'package:tilecache_calc/tilecache_calc.dart';
import 'package:latlong2/latlong.dart';

void main() {
  var result = TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {0: 1000000, 10: 10000});

  print('List of tiles');
  var _list = result.toList();
  for (var _tile in _list){
    _tile.printTile();
  }

  print('');

print('Count per Zoom level');
  var _map = result.toZoomCount();
  _map.forEach((key, value) {
    print('Zoom: ' + key.toString() + ', count of tiles: ' + value.toString());
  });

  print('');

  print('Total count of tiles: ' + result.toList().length.toString());

  var result2 = TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {0: 1000000, 10: 10000, 20: 100});



}
