import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/name_search.dart';

void main() {
  test('names sort as read: case and accents aside, ids break ties', () {
    final names = [
      ('2', 'yamaha'),
      ('1', 'Ducati'),
      ('3', 'Ævo'),
      ('5', 'Énergica'),
      ('4', 'BMW'),
      ('7', 'bmw'),
    ]..sort((a, b) => compareNames(a.$2, a.$1, b.$2, b.$1));
    expect([for (final n in names) n.$1], ['4', '7', '1', '5', '2', '3']);
  });

  test('a search keeps names that hold it, those starting with it first', () {
    String name(String s) => s;
    const models = ['MT-07', 'Tracer 7', 'XSR 700', 'R7', 'MT-09'];
    expect(searchByName(models, name, ''), models);
    expect(searchByName(models, name, '  '), models);
    expect(searchByName(models, name, 'mt 07'), ['MT-07']);
    expect(searchByName(models, name, 'mt07'), ['MT-07']);
    expect(searchByName(models, name, 'r'), ['R7', 'Tracer 7', 'XSR 700']);
    expect(searchByName(['Énergica', 'Ducati'], name, 'ener'), ['Énergica']);
    expect(searchByName(models, name, 'ducati'), isEmpty);
  });
}
