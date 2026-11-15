import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ly_homes/services/display_preferences.dart';

void main() {
  test('Display choices survive a new preferences instance', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final first = DisplayPreferences(storage: storage);
    await first.setLarge(true);
    await first.setReduceMotion(true);
    await first.setDark(true);
    final restored = DisplayPreferences(storage: storage);
    expect(restored.large, isTrue);
    expect(restored.reduceMotion, isTrue);
    expect(restored.dark, isTrue);
    first.dispose();
    restored.dispose();
  });
}
