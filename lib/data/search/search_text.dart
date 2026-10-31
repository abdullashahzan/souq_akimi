/// Normalisation for the denormalised search blob.
///
/// This is a faithful Dart port of `souqapp.models.build_search_text` and
/// `souqapp.search.tokenize`. The Cloud Functions implement the identical rules
/// (see `docs/firestore_schema.md`), so a document written by either side
/// matches the same queries.
library;

/// Anything that is not a letter or digit separates words, so a token sitting
/// against a bracket or comma ("(calculus)", "binding,") still lands on a word
/// boundary and matches.
final RegExp _separators = RegExp(r'[^0-9a-z]+');

/// Split a query or a blob into meaningful lowercase tokens.
List<String> tokenize(String? query) {
  if (query == null || query.isEmpty) return const [];
  return query
      .toLowerCase()
      .split(_separators)
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Return the lowercased blob the search engine matches against.
///
/// The blob is padded with a leading and trailing space so the engine can match
/// on word boundaries (`' phone'` matches the token *phone* but not the `phone`
/// inside *headphones*).
String buildSearchText({
  String name = '',
  String description = '',
  String tags = '',
  String sellerUsername = '',
}) {
  final joined = [name, tags, sellerUsername, description].join(' ');
  final blob = joined.toLowerCase().replaceAll(_separators, ' ').trim();
  return ' $blob ';
}

/// The tokens inside a blob, for `array-contains` candidate retrieval.
List<String> searchTokensOf(String blob) {
  final seen = <String>{};
  for (final token in tokenize(blob)) {
    seen.add(token);
  }
  return seen.toList();
}
