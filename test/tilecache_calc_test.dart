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
}
