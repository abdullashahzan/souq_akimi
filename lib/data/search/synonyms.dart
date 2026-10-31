/// Static language data that powers the smart search. A direct port of
/// `souqapp/synonyms.py`.
///
/// Nothing here touches Firestore — it is plain data plus tiny helpers, so it
/// is cheap to import and trivial to unit-test.
library;

/// Filler words that never help narrow a search.
const Set<String> stopwords = {
  'a',
  'an',
  'the',
  'and',
  'or',
  'of',
  'for',
  'to',
  'in',
  'on',
  'at',
  'with',
  'my',
  'me',
  'i',
  'we',
  'you',
  'want',
  'wanna',
  'need',
  'needed',
  'looking',
  'look',
  'search',
  'searching',
  'find',
  'get',
  'some',
  'any',
  'please',
  'show',
  'give',
  'is',
  'are',
  'it',
  'this',
  'that',
  'these',
  'those',
  'am',
  'do',
  'does',
  'can',
  'could',
  'would',
  'good',
  'best',
  'nice',
  'buy',
  'purchase',
  'selling',
  'sale',
  'available',
};

/// Words that mean the item is new.
const Set<String> conditionNew = {'new', 'sealed', 'unopened', 'brandnew'};

/// Words that mean the item is used.
const Set<String> conditionUsed = {
  'used',
  'secondhand',
  'second-hand',
  'preloved',
  'preowned',
  'refurbished',
  'refurb',
  'old',
};

/// Words that hint at a low-to-high price sort.
const Set<String> cheapHints = {
  'cheap',
  'cheapest',
  'cheaper',
  'budget',
  'affordable',
  'inexpensive',
  'economical',
  'lowcost',
  'low-cost',
};

/// Words that hint at a high-to-low price sort.
const Set<String> expensiveHints = {
  'expensive',
  'premium',
  'luxury',
  'luxurious',
  'priciest',
};

/// Canonical term → other words that should match the same thing.
const Map<String, Set<String>> _seed = {
  'laptop': {'notebook', 'notebooks', 'computer', 'computers', 'pc', 'macbook'},
  'notebook': {'laptop', 'notebooks', 'computer', 'macbook'},
  'computer': {'laptop', 'pc', 'desktop', 'notebook'},
  'desktop': {'computer', 'pc'},
  'phone': {'mobile', 'smartphone', 'cellphone', 'cell', 'iphone', 'android'},
  'mobile': {'phone', 'smartphone', 'cellphone'},
  'smartphone': {'phone', 'mobile'},
  'tablet': {'ipad', 'tab'},
  'ipad': {'tablet'},
  'tv': {'television', 'televisions', 'screen', 'monitor', 'display'},
  'television': {'tv', 'screen'},
  'monitor': {'screen', 'display', 'tv'},
  'headphones': {'headphone', 'earphones', 'earbuds', 'earphone', 'cans'},
  'earphones': {'headphones', 'earbuds', 'earphone'},
  'earbuds': {'headphones', 'earphones'},
  'speaker': {'speakers', 'sound', 'audio'},
  'camera': {'cameras', 'dslr', 'photography', 'lens'},
  'console': {'playstation', 'xbox', 'nintendo', 'gaming'},
  'gaming': {'console', 'game', 'games', 'video'},
  'game': {'games', 'gaming', 'console'},
  'fridge': {'refrigerator', 'freezer', 'refrigerators'},
  'refrigerator': {'fridge', 'freezer'},
  'sofa': {'couch', 'settee'},
  'couch': {'sofa', 'settee'},
  'mattress': {'bed', 'bedding'},
  'bed': {'mattress', 'bedding', 'bedframe'},
  'desk': {'table', 'workstation'},
  'table': {'desk', 'dining'},
  'chair': {'chairs', 'seat', 'stool'},
  'lamp': {'light', 'lighting'},
  'book': {'books', 'textbook', 'textbooks', 'novel', 'novels', 'reading'},
  'textbook': {'book', 'books', 'coursebook'},
  'novel': {'book', 'books', 'fiction'},
  'bike': {'bicycle', 'cycle', 'cycling', 'bikes'},
  'bicycle': {'bike', 'cycle'},
  'cycle': {'bike', 'bicycle'},
  'helmet': {'helmets', 'headgear'},
  'shoes': {'shoe', 'sneakers', 'trainers', 'footwear', 'boots'},
  'shoe': {'sneakers', 'trainers', 'footwear', 'boots'},
  'sneakers': {'shoes', 'trainers', 'running'},
  'boots': {'shoes', 'footwear'},
  'jacket': {'coat', 'outerwear', 'hoodie'},
  'coat': {'jacket', 'outerwear'},
  'hoodie': {'jacket', 'sweatshirt'},
  'shirt': {'tshirt', 'tee', 'top'},
  'jeans': {'trousers', 'pants', 'denim'},
  'backpack': {'bag', 'rucksack', 'bagpack'},
  'bag': {'backpack', 'handbag', 'rucksack', 'satchel'},
  'watch': {'watches', 'smartwatch', 'wristwatch'},
  'calculator': {'calculators', 'scientific'},
  'charger': {'adapter', 'charging', 'cable'},
  'cable': {'charger', 'cord', 'wire'},
  'keyboard': {'keyboards'},
  'mouse': {'mice', 'trackpad'},
  'printer': {'printers', 'printing', 'scanner'},
  'instrument': {'guitar', 'piano', 'music'},
  'guitar': {'instrument', 'music'},
  'microwave': {'oven'},
  'kettle': {'teapot', 'boiler'},
  'fan': {'cooler', 'cooling'},
  'heater': {'heating', 'radiator'},
  // Services — the "do it for me" half of the catalogue.
  'homework': {'assignment', 'assignments', 'coursework', 'homeworks'},
  'assignment': {'homework', 'coursework', 'assignments', 'report'},
  'tutor': {'tutoring', 'tuition', 'coaching', 'tutors'},
  'tutoring': {'tutor', 'tuition', 'coaching'},
  'printout': {'printouts', 'printing', 'print', 'photocopy', 'copies'},
  'printing': {'printout', 'printouts', 'print', 'photocopy', 'copies'},
  'photocopy': {'printing', 'printout', 'printouts', 'copies', 'copy'},
  'delivery': {'deliver', 'errand', 'errands', 'courier', 'dropoff'},
  'errand': {'errands', 'delivery', 'courier', 'dropoff'},
  'project': {'projects', 'report', 'assignment'},
};

/// The thesaurus, symmetrised exactly the way `synonyms.py` does: every
/// alternative gains its canonical term.
final Map<String, Set<String>> synonyms = _buildSynonyms();

Map<String, Set<String>> _buildSynonyms() {
  final map = <String, Set<String>>{
    for (final entry in _seed.entries) entry.key: {...entry.value},
  };
  // Snapshot first, exactly like `list(SYNONYMS.items())` in Python — entries
  // created below are not themselves expanded.
  final snapshot = map.entries.map((e) => MapEntry(e.key, e.value)).toList();
  for (final entry in snapshot) {
    for (final alt in entry.value) {
      (map[alt] ??= <String>{}).add(entry.key);
    }
  }
  return map;
}
