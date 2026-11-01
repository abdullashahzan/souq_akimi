import 'product.dart';

/// Discovery groups work with existing listings without a data migration.
enum ProductCategory {
  tech('Tech', [
    'tech',
    'laptop',
    'macbook',
    'tablet',
    'computer',
    'headphone',
    'keyboard',
    'mouse',
    'charger',
    'تقنية',
    'لابتوب',
    'سماعات',
  ]),
  books('Books & study', [
    'book',
    'textbook',
    'calculator',
    'stationery',
    'notes',
    'notebook',
    'revision',
    'كتاب',
    'كتب',
    'دفتر',
    'ملاحظات',
    'قرطاسية',
    'آلة حاسبة',
  ]),
  room('Room essentials', [
    'furniture',
    'chair',
    'desk',
    'lamp',
    'kitchen',
    'appliance',
    'bedding',
    'غرفة',
    'كرسي',
    'مصباح',
    'مطبخ',
  ]),
  style('Style & everyday', [
    'clothing',
    'bag',
    'backpack',
    'hoodie',
    'bottle',
    'accessory',
    'ملابس',
    'حقيبة',
    'قارورة',
  ]);

  const ProductCategory(this.label, this.keywords);
  final String label;
  final List<String> keywords;

  bool matches(Product product) {
    final text = '${product.name} ${product.tags.join(' ')}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
    final words = ' $text ';
    // Whole words avoid classifying "desktop keyboard" as room furniture or
    // a "study mouse" as a book. The simple plural covers books/headphones.
    return keywords.any(
      (keyword) =>
          words.contains(' $keyword ') || words.contains(' ${keyword}s '),
    );
  }
}
