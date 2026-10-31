import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/data/search/query_parser.dart';

void main() {
  group('parseQuery — price extraction', () {
    test('a bare amount is a budget ceiling', () {
      final parsed = parseQuery('laptop \$50');
      expect(parsed.priceMax, 50);
      expect(parsed.priceMin, isNull);
      expect(parsed.terms, ['laptop']);
    });

    test('over/above/minimum set the floor', () {
      expect(parseQuery('over \$20').priceMin, 20);
      expect(parseQuery('above \$20').priceMin, 20);
      expect(parseQuery('at least 20').priceMin, 20);
      expect(parseQuery('>= 20').priceMin, 20);
    });

    test('under/upto/maximum set the ceiling', () {
      expect(parseQuery('under \$50').priceMax, 50);
      expect(parseQuery('up to 50').priceMax, 50);
      expect(parseQuery('<= 50').priceMax, 50);
    });

    test('a range keeps both bounds', () {
      final parsed = parseQuery('between \$10 and \$20');
      expect(parsed.priceMin, 10);
      expect(parsed.priceMax, 20);
      expect(parsed.terms, isEmpty);
    });

    test('the dash form of a range also keeps both bounds', () {
      final parsed = parseQuery('\$10 - \$20');
      expect(parsed.priceMin, 10);
      expect(parsed.priceMax, 20);
    });

    test('the strictest of several constraints wins', () {
      final parsed = parseQuery('over \$5 under \$30');
      expect(parsed.priceMin, 5);
      expect(parsed.priceMax, 30);
    });

    test('decimals survive', () {
      expect(parseQuery('cheap shoes under \$12.50').priceMax, 12.5);
    });
  });

  group('parseQuery — natural language hints', () {
    test('stop words disappear', () {
      final parsed = parseQuery('i am looking for a laptop for my sister');
      expect(parsed.terms, ['laptop', 'sister']);
      expect(parsed.hadText, isTrue);
    });

    test('cheap/expensive become sort hints, not terms', () {
      expect(parseQuery('cheap laptop').sortHint, 'price_asc');
      expect(parseQuery('cheap laptop').terms, ['laptop']);
      expect(parseQuery('expensive phone').sortHint, 'price_desc');
      expect(parseQuery('expensive phone').terms, ['phone']);
    });

    test('condition words become a preference, not a filter term', () {
      final parsed = parseQuery('brand new phone');
      expect(parsed.conditionPref, isNotNull);
      expect(parsed.conditionPref!.value, 'new');
      expect(parsed.terms, ['phone']);
    });

    test('second-hand and pre-owned collapse to "used"', () {
      expect(parseQuery('second hand bike').conditionPref!.value, 'used');
      expect(parseQuery('pre-owned bike').conditionPref!.value, 'used');
      expect(parseQuery('second-hand bike').terms, ['bike']);
    });

    test('quoted phrases stay together', () {
      final parsed = parseQuery('"brand new laptop"');
      expect(parsed.phrases, ['brand new laptop']);
      expect(parsed.terms, isEmpty);
    });

    test('an empty query is inert', () {
      final parsed = parseQuery('   ');
      expect(parsed.terms, isEmpty);
      expect(parsed.priceMin, isNull);
      expect(parsed.priceMax, isNull);
      expect(parsed.hadText, isFalse);
    });
  });

  group('typo tolerance helpers', () {
    test('levenshtein is exact within the cap', () {
      expect(levenshtein('laptop', 'laptop', 2), 0);
      expect(levenshtein('laptop', 'laptp', 2), 1);
      expect(levenshtein('kitten', 'sitting', 3), 3);
    });

    test('levenshtein short-circuits past the cap', () {
      expect(levenshtein('a', 'abcdefgh', 2), 3); // cap + 1
      expect(levenshtein('abc', 'xyz', 1), 2); // cap + 1
    });

    test('singular strips a trailing s, but not a double s', () {
      expect(singular('laptops'), 'laptop');
      expect(singular('shoes'), 'shoe');
      expect(singular('class'), 'class');
      expect(singular('pc'), 'pc');
    });

    test('fuzzyVariants finds near misses and ignores distant words', () {
      final vocab = {'laptop', 'phone', 'notebook'};
      expect(fuzzyVariants('laptp', vocab), contains('laptop'));
      expect(fuzzyVariants('phne', vocab), contains('phone'));
      expect(fuzzyVariants('xylophone', vocab), isEmpty);
    });

    test('fuzzyVariants refuses short tokens', () {
      expect(fuzzyVariants('pc', {'mac'}), isEmpty);
    });

    test('fuzzyVariants prefers the closest word', () {
      final variants = fuzzyVariants('calclator', {
        'calculators',
        'calculator',
      });
      expect(variants.first, 'calculator'); // distance 1 beats distance 2
      expect(variants, contains('calculators'));
    });
  });

  group('didYouMean', () {
    final vocab = {'laptop', 'phone', 'headphones'};

    test('corrects a misspelling', () {
      expect(didYouMean('laptp', vocab), 'laptop');
      expect(didYouMean('phne', vocab), 'phone');
    });

    test('leaves a correct query alone', () {
      expect(didYouMean('laptop', vocab), '');
      expect(didYouMean('the laptop', vocab), '');
    });

    test('returns nothing for an empty or unfuzzyable query', () {
      expect(didYouMean('', vocab), '');
      expect(didYouMean('zzzzzzzzzz', vocab), '');
    });

    test('keeps the words it could not fix', () {
      expect(didYouMean('laptp zzzzzzzzzz', vocab), 'laptop zzzzzzzzzz');
    });
  });

  group('expandTermGroups', () {
    test('adds synonyms and the singular form', () {
      final groups = expandTermGroups(parseQuery('laptops'), {
        'laptop',
        'phone',
      });
      expect(groups.single, contains('laptop'));
      expect(groups.single, contains('notebook'));
      expect(groups.single, contains('computer'));
    });

    test('a term already in the vocabulary is not fuzzed', () {
      final groups = expandTermGroups(parseQuery('laptop'), {'laptop'});
      // Only the term itself and its synonyms — no random near neighbours.
      expect(groups.single, isNot(contains('phones')));
    });

    test('an unknown term pulls in near neighbours', () {
      final groups = expandTermGroups(parseQuery('laptp'), {'laptop'});
      expect(groups.single, contains('laptop'));
    });
  });
}
