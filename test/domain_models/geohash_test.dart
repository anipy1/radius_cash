import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';

void main() {
  group('Geohash:', () {
    test('When encoding known places, matches the reference values', () {
      // The geohash.org worked example, Times Square, and Tallinn old town.
      expect(
        Geohash.encode(57.64911, 10.40744, precision: 11).value,
        'u4pruydqqvj',
      );
      expect(Geohash.encode(40.7580, -73.9855, precision: 6).value, 'dr5ru7');
      expect(Geohash.encode(59.4370, 24.7536, precision: 6).value, 'ud9d5k');
    });

    test('When the default precision is used, the cell is five characters', () {
      expect(Geohash.encode(59.4370, 24.7536).precision, 5);
    });

    test('Prefixes go coarsest first and truncate keeps a prefix', () {
      const g = Geohash('ud9wr');
      expect(g.prefixes, ['u', 'ud', 'ud9', 'ud9w', 'ud9wr']);
      expect(g.truncate(4), const Geohash('ud9w'));
      expect(g.truncate(9), g);
    });

    test('Validity rejects letters outside the alphabet', () {
      expect(Geohash.isValid('ud9wr'), isTrue);
      expect(Geohash.isValid('ud9wa'), isFalse); // a is not in base32ghs
      expect(Geohash.isValid(''), isFalse);
    });
  });
}
