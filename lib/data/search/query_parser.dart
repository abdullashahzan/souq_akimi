import '../../models/enums.dart';
import 'search_text.dart';
import 'synonyms.dart';

/// Everything the search pipeline inferred from the raw query string.
/// Port of `souqapp.search.ParsedQuery`.
class ParsedQuery {
  ParsedQuery({
    this.raw = '',
    this.terms = const [],
    this.phrases = const [],
    this.priceMin,
    this.priceMax,
    this.conditionPref,
    this.sortHint = '',
    this.hadText = false,
  });

  final String raw;
  final List<String> terms;
  final List<String> phrases;
  final double? priceMin;
  final double? priceMax;

  /// `new` / `used` — used to *rank*, never to filter.
  final Condition? conditionPref;

  /// e.g. `price_asc` for "cheap".
  final String sortHint;

  /// The raw query had words, even if all of them were filler.
  final bool hadText;
}

const String _number = r'\d+(?:\.\d+)?';

double? _toDecimal(String? value) =>
    value == null ? null : double.tryParse(value);

/// Flatten punctuation the same way [buildSearchText] does, so a quoted phrase
/// can be matched straight against the stored blob.
String _normalizePhrase(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^0-9a-z]+'), ' ').trim();

class _PriceHit {
  const _PriceHit(this.low, this.high, this.remaining);

  final double? low;
  final double? high;
  final String remaining;
}

/// Extract a single price constraint. Returns the bounds plus the text with the
/// matched words removed.
_PriceHit _extractOnePrice(String text) {
  // Consume a matched price phrase by replacing it with a single space.
  String take(RegExpMatch match) =>
      '${text.substring(0, match.start)} ${text.substring(match.end)}';

  RegExpMatch? match;

  match = RegExp(
    'between\\s+\\\$?($_number)\\s+(?:and|to|-)\\s+\\\$?($_number)',
  ).firstMatch(text);
  if (match != null) {
    return _PriceHit(
      _toDecimal(match.group(1)),
      _toDecimal(match.group(2)),
      take(match),
    );
  }

  match = RegExp('\\\$($_number)\\s*(?:-|to)\\s*\\\$?($_number)')
      .firstMatch(text);
  if (match != null) {
    return _PriceHit(
      _toDecimal(match.group(1)),
      _toDecimal(match.group(2)),
      take(match),
    );
  }

  match = RegExp(
    '(?:over|above|more\\s+than|greater\\s+than|from|min(?:imum)?|at\\s+least|>=?)\\s*\\\$?($_number)',
  ).firstMatch(text);
  if (match != null) {
    return _PriceHit(_toDecimal(match.group(1)), null, take(match));
  }

  match = RegExp(
    '(?:under|below|less\\s+than|cheaper\\s+than|lower\\s+than|up\\s*to|upto|max(?:imum)?|<=?)\\s*\\\$?($_number)',
  ).firstMatch(text);
  if (match != null) {
    return _PriceHit(null, _toDecimal(match.group(1)), take(match));
  }

  // A bare "$50" is most naturally read as a budget ceiling.
  match = RegExp('\\\$($_number)').firstMatch(text);
  if (match != null) {
    return _PriceHit(null, _toDecimal(match.group(1)), take(match));
  }

  return _PriceHit(null, null, text);
}

/// Pull *every* price constraint out of `text` and intersect them (the
/// strictest limit wins), consuming the price words as they go.
({double? low, double? high, String text}) _extractPrice(String text) {
  double? priceMin;
  double? priceMax;
  while (true) {
    final hit = _extractOnePrice(text);
    if (hit.remaining == text) break;
    text = hit.remaining;

    final low = hit.low;
    if (low != null) {
      final current = priceMin;
      priceMin = (current == null || low > current) ? low : current;
    }
    final high = hit.high;
    if (high != null) {
      final current = priceMax;
      priceMax = (current == null || high < current) ? high : current;
    }
  }
  return (low: priceMin, high: priceMax, text: text);
}

/// Turn a raw query string into a [ParsedQuery].
ParsedQuery parseQuery(String? rawInput) {
  final raw = (rawInput ?? '').trim();
  if (raw.isEmpty) return ParsedQuery(raw: raw);

  var text = raw.toLowerCase();

  final phrases = RegExp(r'"([^"]+)"')
      .allMatches(text)
      .map((m) => _normalizePhrase(m.group(1) ?? ''))
      .where((p) => p.isNotEmpty)
      .toList();
  text = text.replaceAll(RegExp(r'"[^"]*"'), ' ');

  final price = _extractPrice(text);
  text = price.text;

  // Collapse multi-word condition phrases before tokenising.
  text = text.replaceAll(RegExp(r'\bbrand[\s-]?new\b'), ' new ');
  text = text.replaceAll(RegExp(r'\bsecond[\s-]?hand\b'), ' used ');
  text = text.replaceAll(RegExp(r'\bsecondhand\b'), ' used ');
  text = text.replaceAll(RegExp(r'\bpre[\s-]?owned\b'), ' used ');

  final terms = <String>[];
  Condition? conditionPref;
  var sortHint = '';
  for (final token in tokenize(text)) {
    if (stopwords.contains(token)) continue;
    if (conditionNew.contains(token)) {
      conditionPref = Condition.brandNew;
      continue;
    }
    if (conditionUsed.contains(token)) {
      conditionPref = Condition.used;
      continue;
    }
    if (cheapHints.contains(token)) {
      sortHint = 'price_asc';
      continue;
    }
    if (expensiveHints.contains(token)) {
      sortHint = 'price_desc';
      continue;
    }
    terms.add(token);
  }

  return ParsedQuery(
    raw: raw,
    terms: terms,
    phrases: phrases,
    priceMin: price.low,
    priceMax: price.high,
    conditionPref: conditionPref,
    sortHint: sortHint,
    hadText: tokenize(raw).isNotEmpty,
  );
}

/// Very light de-pluralisation: "laptops" → "laptop".
String singular(String token) {
  if (token.length > 3 && token.endsWith('s') && !token.endsWith('ss')) {
    return token.substring(0, token.length - 1);
  }
  return token;
}

/// Bounded edit distance; returns `cap + 1` once it is known to exceed.
int levenshtein(String a, String b, int cap) {
  if ((a.length - b.length).abs() > cap) return cap + 1;
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final ca = a.codeUnitAt(i);
    final current = <int>[i + 1];
    var best = current[0];
    for (var j = 0; j < b.length; j++) {
      final cost = ca == b.codeUnitAt(j) ? 0 : 1;
      final value = [
        previous[j + 1] + 1,
        current[j] + 1,
        previous[j] + cost,
      ].reduce((x, y) => x < y ? x : y);
      current.add(value);
      if (value < best) best = value;
    }
    if (best > cap) return cap + 1;
    previous = current;
  }
  return previous.last;
}

/// Close vocabulary words for [token] (typo tolerance).
List<String> fuzzyVariants(String token, Set<String> vocab, {int limit = 3}) {
  if (token.length < 4) return const [];
  final cap = token.length <= 6 ? 1 : 2;
  final scored = <({int distance, String word})>[];
  for (final word in vocab) {
    if (word == token) continue;
    if ((word.length - token.length).abs() > cap) continue;
    final distance = levenshtein(token, word, cap);
    if (distance <= cap) scored.add((distance: distance, word: word));
  }
  scored.sort((a, b) {
    final byDistance = a.distance.compareTo(b.distance);
    return byDistance != 0 ? byDistance : a.word.compareTo(b.word);
  });
  return scored.take(limit).map((e) => e.word).toList();
}

/// All synonym variants of [term] (and its singular form).
Set<String> _synonymsFor(String term) {
  final variants = <String>{};
  variants.addAll(synonyms[term] ?? const {});
  final sing = singular(term);
  if (sing != term) variants.addAll(synonyms[sing] ?? const {});
  return variants;
}

/// One set of variants per significant term.
///
/// A listing matches the query when *every* term matches *at least one* of its
/// variants. Unknown terms (likely typos) also pull in their nearest vocabulary
/// words so "laptp" still finds a "laptop".
List<Set<String>> expandTermGroups(ParsedQuery parsed, Set<String> vocab) {
  final groups = <Set<String>>[];
  for (final term in parsed.terms) {
    final variants = <String>{term};
    final sing = singular(term);
    if (sing != term) variants.add(sing);
    variants.addAll(_synonymsFor(term));
    if (!vocab.contains(term) && !vocab.contains(sing)) {
      variants.addAll(fuzzyVariants(term, vocab));
    }
    groups.add(variants);
  }
  return groups;
}

/// A corrected query string, or `''` when nothing was misspelled.
String didYouMean(String? raw, Set<String> vocab) {
  final parsed = parseQuery(raw);
  if (parsed.terms.isEmpty) return '';
  final corrected = <String>[];
  var changed = false;
  for (final term in parsed.terms) {
    if (vocab.contains(term) || vocab.contains(singular(term))) {
      corrected.add(term);
      continue;
    }
    final candidates = fuzzyVariants(term, vocab, limit: 1);
    if (candidates.isNotEmpty) {
      corrected.add(candidates.first);
      changed = true;
    } else {
      corrected.add(term);
    }
  }
  return changed ? corrected.join(' ') : '';
}
