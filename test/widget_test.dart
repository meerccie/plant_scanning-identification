import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basic math test', () {
    expect(1 + 1, 2);
  });

  test('String test', () {
    expect('Plantitao'.length, greaterThan(0));
  });

  group('Basic app tests', () {
    test('App name should not be empty', () {
      expect('Plantitao', isNotEmpty);
    });
  });
}