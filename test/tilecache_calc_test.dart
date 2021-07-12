import 'package:tilecache_calc/tilecache_calc.dart';
import 'package:test/test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Check validation of input', () {
    test('Test valid center point', () {
      var result = TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: 10});
      expect(result.toList().length, equals(1));
    });

    test('Test not valid center point throws error', () {
      expect(() => TileCalc.listTilesWithinRadius(LatLng(89.93850425319522, 10.70068359375), radiuses: {10: 10}),
          throwsArgumentError);
    });

    test('Test not valid negative Zoom value throws error', () {
      expect(() => TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {-10: 10}),
          throwsArgumentError);
    });

    test('Test not valid Zoom value above 20 throws error', () {
      expect(() => TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {21: 10}),
          throwsArgumentError);
    });

    test('Test negative radius throws error', () {
      expect(() => TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: -10}),
          throwsArgumentError);
    });

    test('Test large radius does not throw error', () {
      var result = TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {0: 19000000});
      expect(result.toList().length, equals(1));
    });

    test('Test too large radius does not throw error', () {
      expect(() => TileCalc.listTilesWithinRadius(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: 19000001}),
          throwsArgumentError);
    });
  });

  group('Check order of circles', () {
    test('Test increasing zooms, same radiuses', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {0: 300, 5: 300, 10: 300, 15: 300, 20: 300},
      );
      expect(result.toList().length, equals(1156));
    });

    test('Test increasing zooms, falling radiuses', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {0: 300, 5: 250, 10: 200, 15: 150, 20: 100},
      );
      expect(result.toList().length, equals(184));
    });

    test('Test falling zooms, falling radiuses', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100},
      );
      expect(result.toList().length, equals(184));
    });

    test('Widest radius does not have the lowest zoom', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {20: 300, 5: 250, 10: 200, 15: 1000, 0: 100},
      );
      expect(result.toList().length, equals(1174));
    });
  });

  group('Check special location', () {
    test('Test Lat 0 Long 0', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(0, 0),
        radiuses: {10: 10},
      );
      expect(result.toList().length, equals(4));
    });

    test('Test Lat 85 Long 0', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(85, 0),
        radiuses: {10: 10},
      );
      expect(result.toList().length, equals(2));
    });

    test('Test Lat -85 Long 0', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(-85, 0),
        radiuses: {10: 10},
      );
      expect(result.toList().length, equals(2));
    });

    test('Test Lat 0 Long 180', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(0, 180),
        radiuses: {10: 10},
      );
      expect(result.toList().length, equals(4));
    });

    test('Test Lat 0 Long -180', () {
      var result = TileCalc.listTilesWithinRadius(
        LatLng(0, -180),
        radiuses: {10: 10},
      );
      expect(result.toList().length, equals(4));
    });
  });

  group('Estimate - Check validation of input', () {
    test('Test valid center point', () {
      var result = TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: 10});
      expect(result.totalCount(), equals(1));
    });

    test('Estimate - Test not valid center point throws error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(89.93850425319522, 10.70068359375), radiuses: {10: 10}),
          throwsArgumentError);
    });

    test('Estimate - Test not valid negative Zoom value throws error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375), radiuses: {-10: 10}),
          throwsArgumentError);
    });

    test('Estimate - Test not valid Zoom value above 20 throws error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375), radiuses: {21: 10}),
          throwsArgumentError);
    });

    test('Estimate - Test negative radius throws error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: -10}),
          throwsArgumentError);
    });

    test('Estimate - Test large radius throws error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(0.93850425319522, 10.70068359375), radiuses: {0: 19000000}),
          throwsArgumentError);
    });

    test('Estimate - Test too large radius does not throw error', () {
      expect(() => TileCalc.estimateTileCount(LatLng(59.93850425319522, 10.70068359375), radiuses: {10: 19000001}),
          throwsArgumentError);
    });
  });

  group('Estimate - Check order of circles', () {
    test('Estimate - Test increasing zooms, same radiuses', () {
      var result = TileCalc.estimateTileCount(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {0: 300, 5: 300, 10: 300, 15: 300, 20: 300},
      );
      expect(result.totalCount(), equals(1171));
    });

    test('Estimate - Test increasing zooms, falling radiuses', () {
      var result = TileCalc.estimateTileCount(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {0: 300, 5: 250, 10: 200, 15: 150, 20: 100},
      );
      expect(result.totalCount(), equals(177));
    });

    test('Estimate - Test falling zooms, falling radiuses', () {
      var result = TileCalc.estimateTileCount(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100},
      );
      expect(result.totalCount(), equals(177));
    });

    test('Estimate - Widest radius does not have the lowest zoom', () {
      var result = TileCalc.estimateTileCount(
        LatLng(59.93850425319522, 10.70068359375),
        radiuses: {20: 300, 5: 250, 10: 200, 15: 1000, 0: 100},
      );
      expect(result.totalCount(), equals(1187));
    });
  });

  group('Estimate - Check special location', () {
    test('Estimate - Test Lat 0 Long 0', () {
      var result = TileCalc.estimateTileCount(
        LatLng(0, 0),
        radiuses: {10: 10},
      );
      expect(result.totalCount(), equals(1));
    });

    test('Estimate - Test Lat 85 Long 0', () {
      var result = TileCalc.estimateTileCount(
        LatLng(85, 0),
        radiuses: {10: 10},
      );
      expect(result.totalCount(), equals(1));
    });

    test('Estimate - Test Lat -85 Long 0', () {
      var result = TileCalc.estimateTileCount(
        LatLng(-85, 0),
        radiuses: {10: 10},
      );
      expect(result.totalCount(), equals(1));
    });

    test('Estimate - Test Lat 0 Long 180', () {
      var result = TileCalc.estimateTileCount(
        LatLng(0, 180),
        radiuses: {10: 10},
      );
      expect(result.totalCount(), equals(1));
    });

    test('Estimate - Test Lat 0 Long -180', () {
      var result = TileCalc.estimateTileCount(
        LatLng(0, -180),
        radiuses: {10: 10},
      );
      expect(result.totalCount(), equals(1));
    });
  });

  group('Geometry - Check validation of input', () {
    final a = LatLng(60.536106554791331, 8.217904530465603);

    test('Test valid center point', () {
      var result = TileCalc.listTilesForPointGeometry([a], 0, 0);
      expect(result.toList().length, equals(1));
    });

    test('Test not valid center point throws error', () {
      expect(() => TileCalc.listTilesForPointGeometry([LatLng(89.93850425319522, 10.70068359375)], 0, 0),
          throwsArgumentError);
    });

    test('Test not valid negative Zoom value throws error', () {
      expect(() => TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {-10: 10}), throwsArgumentError);
    });

    test('Test not valid Zoom value above 20 throws error', () {
      expect(() => TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {21: 10}), throwsArgumentError);
    });

    test('Test negative buffer throws error', () {
      expect(() => TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {10: -10}), throwsArgumentError);
    });

    test('Test too large radius does not throw error', () {
      expect(() => TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {0: 19000001}), throwsArgumentError);
    });
  });

  group('Geometry - Check order of buffers', () {
    final a = LatLng(60.536106554791331, 8.217904530465603);
    final b = LatLng(60.540094999596477, 8.214778918772936);
    final c = LatLng(60.541747910901904, 8.215941907837987);
    final d = LatLng(60.540310665965081, 8.222483983263373);
    final e = LatLng(60.536753302440047, 8.220993848517537);

    test('Test increasing zooms, same buffers for Point', () {
      var result = TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {0: 300, 5: 300, 10: 300, 15: 300, 20: 300});
      expect(result.toList().length, equals(1215));
    });

    test('Test increasing zooms, same buffers for Linestring', () {
      var result = TileCalc.listTilesForLinestringGeometry([a, b, c, d, e], 0, 0,
          buffers: {0: 300, 5: 300, 10: 300, 15: 300, 20: 300});
      expect(result.toList().length, equals(3797));
    });

    test('Test increasing zooms, same buffers for Polygon', () {
      var result = TileCalc.listTilesForPolygonGeometry([a, b, c, d, e, a], 0, 0,
          buffers: {0: 300, 5: 300, 10: 300, 15: 300, 20: 300});
      expect(result.toList().length, equals(3799));
    });

    test('Test increasing zooms, falling buffers for Point', () {
      var result = TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {0: 300, 5: 250, 10: 200, 15: 150, 20: 100});
      expect(result.toList().length, equals(180));
    });

    test('Test increasing zooms, falling buffers for Linestring', () {
      var result = TileCalc.listTilesForLinestringGeometry([a, b, c, d], 0, 0,
          buffers: {0: 300, 5: 250, 10: 200, 15: 150, 20: 100});
      expect(result.toList().length, equals(1111));
    });

    test('Test increasing zooms, falling buffers for Polygon', () {
      var result = TileCalc.listTilesForPolygonGeometry([a, b, c, d, e, a], 0, 0,
          buffers: {0: 300, 5: 250, 10: 200, 15: 150, 20: 100});
      expect(result.toList().length, equals(1539));
    });

    test('Test falling zooms, falling buffers for Point', () {
      var result = TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(180));
    });

    test('Test falling zooms, falling buffers for Linestring', () {
      var result = TileCalc.listTilesForLinestringGeometry([a, b, c, d], 0, 0,
          buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(1111));
    });

    test('Test falling zooms, falling buffers for Polygon', () {
      var result = TileCalc.listTilesForPolygonGeometry([a, b, c, d, e, a], 0, 0,
          buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(1539));
    });

    test('Widest buffer does not have the lowest zoom for Point', () {
      var result = TileCalc.listTilesForPointGeometry([a], 0, 0, buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(180));
    });

    test('Widest buffer does not have the lowest zoom for Linestring', () {
      var result = TileCalc.listTilesForLinestringGeometry([a, b, c, d], 0, 0,
          buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(1111));
    });

    test('Widest buffer does not have the lowest zoom for Polygon', () {
      var result = TileCalc.listTilesForPolygonGeometry([a, b, c, d, e, a], 0, 0,
          buffers: {20: 100, 15: 150, 10: 200, 5: 250, 0: 100});
      expect(result.toList().length, equals(1539));
    });
  });
}
