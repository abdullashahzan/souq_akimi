/// The sample catalogue, ported verbatim from `functions/src/seed.ts`
/// (`SAMPLE_ITEMS` and `SAMPLE_SERVICES`). Slugs, copy, tags, prices,
/// conditions, stock and categories are byte-for-byte the same so a seeded
/// database matches the one the Cloud Function used to build.
library;

import '../models/enums.dart';

/// One sample product of the demo catalogue.
class SeedProduct {
  const SeedProduct({
    required this.slug,
    required this.name,
    required this.description,
    required this.tags,
    required this.price,
    required this.condition,
    required this.stock,
  });

  /// Stable key: the seeded doc id is `demo-product-{slug}`.
  final String slug;

  final String name;
  final String description;
  final List<String> tags;
  final double price;
  final Condition condition;
  final int stock;
}

/// One sample service of the demo catalogue.
class SeedService {
  const SeedService({
    required this.slug,
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
    required this.price,
    required this.priceType,
  });

  /// Stable key: the seeded doc id is `demo-service-{slug}`.
  final String slug;

  final String title;
  final ServiceCategory category;
  final String description;
  final List<String> tags;
  final double price;
  final PriceType priceType;
}

/// Pure data — no Firestore, no imports beyond the shared enums — so the
/// catalogue can be unit-tested and reused without touching Firebase.
class DemoSeedData {
  const DemoSeedData._();

  /// 24 items, in the order `seed.ts` lists them.
  static const List<SeedProduct> products = [
    SeedProduct(
      slug: 'casio-fx991',
      name: 'Casio FX-991EX Classwiz Calculator',
      description:
          'Exam-approved scientific calculator, barely used, all keys crisp.',
      tags: ['calculator', 'engineering', 'maths', 'exam'],
      price: 22.5,
      condition: Condition.used,
      stock: 3,
    ),
    SeedProduct(
      slug: 'mini-fridge',
      name: 'Mini Fridge 90L',
      description: 'Compact hostel fridge with freezer box. Quiet and cold.',
      tags: ['fridge', 'appliance', 'hostel', 'kitchen'],
      price: 85,
      condition: Condition.used,
      stock: 2,
    ),
    SeedProduct(
      slug: 'led-desk-lamp',
      name: 'LED Desk Lamp with USB Port',
      description: 'Three brightness levels, flexible arm, USB charging port.',
      tags: ['lamp', 'desk', 'lighting', 'study'],
      price: 15,
      condition: Condition.brandNew,
      stock: 8,
    ),
    SeedProduct(
      slug: 'study-desk',
      name: 'Folding Study Desk',
      description: 'Space-saving folding desk, fits beside a hostel bed.',
      tags: ['desk', 'furniture', 'study', 'hostel'],
      price: 40,
      condition: Condition.used,
      stock: 4,
    ),
    SeedProduct(
      slug: 'office-chair',
      name: 'Ergonomic Office Chair',
      description:
          'Mesh back, adjustable height, good for long study sessions.',
      tags: ['chair', 'furniture', 'ergonomic', 'study'],
      price: 55,
      condition: Condition.used,
      stock: 2,
    ),
    SeedProduct(
      slug: 'single-mattress',
      name: 'Single Foam Mattress',
      description: 'Clean single mattress with removable washable cover.',
      tags: ['mattress', 'bed', 'hostel', 'furniture'],
      price: 60,
      condition: Condition.used,
      stock: 3,
    ),
    SeedProduct(
      slug: 'electric-kettle',
      name: 'Electric Kettle 1.7L',
      description: 'Stainless steel kettle, fast boil, auto shut-off.',
      tags: ['kettle', 'kitchen', 'appliance'],
      price: 18,
      condition: Condition.brandNew,
      stock: 6,
    ),
    SeedProduct(
      slug: 'rice-cooker',
      name: 'Rice Cooker 1.8L',
      description: 'Non-stick rice cooker, steamer tray included.',
      tags: ['rice cooker', 'kitchen', 'appliance', 'cooking'],
      price: 28,
      condition: Condition.used,
      stock: 4,
    ),
    SeedProduct(
      slug: 'fleece-blanket',
      name: 'Fleece Blanket (Double)',
      description: 'Soft double fleece blanket for cold hostel nights.',
      tags: ['blanket', 'bedding', 'hostel', 'warm'],
      price: 14,
      condition: Condition.brandNew,
      stock: 10,
    ),
    SeedProduct(
      slug: 'lab-coat',
      name: 'Cotton Lab Coat (M)',
      description: 'White lab coat, medium, washed and pressed.',
      tags: ['lab coat', 'science', 'lab', 'uniform'],
      price: 12,
      condition: Condition.used,
      stock: 5,
    ),
    SeedProduct(
      slug: 'stats-textbook',
      name: 'Probability & Statistics Textbook',
      description: 'Standard first-year statistics text, light highlighting.',
      tags: ['textbook', 'statistics', 'maths', 'book'],
      price: 20,
      condition: Condition.used,
      stock: 3,
    ),
    SeedProduct(
      slug: 'calculus-textbook',
      name: 'Calculus Early Transcendentals',
      description: 'Complete calculus reference, cover slightly worn.',
      tags: ['textbook', 'calculus', 'maths', 'book'],
      price: 25,
      condition: Condition.used,
      stock: 2,
    ),
    SeedProduct(
      slug: 'novel-bundle',
      name: 'Novel Bundle (5 Books)',
      description: 'Mixed fiction bundle, great for slow afternoons.',
      tags: ['books', 'novels', 'fiction', 'bundle'],
      price: 15,
      condition: Condition.used,
      stock: 4,
    ),
    SeedProduct(
      slug: 'acoustic-guitar',
      name: 'Acoustic Guitar',
      description:
          'Full-size acoustic guitar with soft case and spare strings.',
      tags: ['guitar', 'music', 'instrument', 'hobby'],
      price: 70,
      condition: Condition.used,
      stock: 1,
    ),
    SeedProduct(
      slug: 'laptop-backpack',
      name: 'Laptop Backpack',
      description: 'Water-resistant 15.6" laptop backpack with padded sleeve.',
      tags: ['backpack', 'bag', 'laptop', 'travel'],
      price: 24,
      condition: Condition.brandNew,
      stock: 7,
    ),
    SeedProduct(
      slug: 'power-bank',
      name: 'Power Bank 20000mAh',
      description: 'Fast-charging power bank with dual USB and USB-C.',
      tags: ['power bank', 'charger', 'battery', 'tech'],
      price: 26,
      condition: Condition.brandNew,
      stock: 9,
    ),
    SeedProduct(
      slug: 'usb-c-hub',
      name: '7-in-1 USB-C Hub',
      description: 'HDMI, SD card, USB-A and pass-through charging.',
      tags: ['hub', 'usb c', 'tech', 'adapter'],
      price: 30,
      condition: Condition.brandNew,
      stock: 5,
    ),
    SeedProduct(
      slug: 'wireless-mouse',
      name: 'Wireless Mouse',
      description: 'Silent-click wireless mouse, USB receiver.',
      tags: ['mouse', 'computer', 'tech', 'accessory'],
      price: 10,
      condition: Condition.brandNew,
      stock: 12,
    ),
    SeedProduct(
      slug: 'mechanical-keyboard',
      name: 'Mechanical Keyboard (TKL)',
      description: 'Tenkeyless mechanical keyboard, blue switches.',
      tags: ['keyboard', 'mechanical', 'computer', 'tech'],
      price: 45,
      condition: Condition.used,
      stock: 3,
    ),
    SeedProduct(
      slug: 'monitor-24',
      name: '24" Full HD Monitor',
      description: '1080p IPS monitor, HDMI and VGA inputs.',
      tags: ['monitor', 'screen', 'computer', 'tech'],
      price: 78,
      condition: Condition.used,
      stock: 2,
    ),
    SeedProduct(
      slug: 'desk-fan',
      name: 'Desk Fan',
      description: 'Quiet three-speed desk fan for warm nights.',
      tags: ['fan', 'cooling', 'appliance', 'hostel'],
      price: 16,
      condition: Condition.brandNew,
      stock: 8,
    ),
    SeedProduct(
      slug: 'whiteboard-a2',
      name: 'Whiteboard A2 with Markers',
      description: 'Double-sided A2 whiteboard, markers and eraser included.',
      tags: ['whiteboard', 'study', 'revision', 'stationery'],
      price: 19,
      condition: Condition.used,
      stock: 4,
    ),
    SeedProduct(
      slug: 'inkjet-printer',
      name: 'Inkjet Printer',
      description: 'Colour inkjet printer with a fresh black cartridge.',
      tags: ['printer', 'printing', 'tech', 'study'],
      price: 50,
      condition: Condition.used,
      stock: 2,
    ),
    SeedProduct(
      slug: 'hoodie',
      name: 'University Hoodie (L)',
      description: 'Official campus hoodie, large, worn a handful of times.',
      tags: ['hoodie', 'clothing', 'merch', 'apparel'],
      price: 22,
      condition: Condition.used,
      stock: 5,
    ),
  ];

  /// 12 entries, in the order `seed.ts` lists them.
  static const List<SeedService> services = [
    SeedService(
      slug: 'campus-printing',
      title: 'Campus Printing & Binding',
      category: ServiceCategory.printing,
      description:
          'Black-and-white and colour printing, plus spiral binding. '
          'Same-day.',
      tags: ['printing', 'binding', 'documents', 'thesis'],
      price: 0.1,
      priceType: PriceType.page,
    ),
    SeedService(
      slug: 'homework-help',
      title: 'Homework Help (All Subjects)',
      category: ServiceCategory.homework,
      description: 'Patient one-to-one help across sciences and humanities.',
      tags: ['homework', 'help', 'study', 'subjects'],
      price: 12,
      priceType: PriceType.hour,
    ),
    SeedService(
      slug: 'latex-typesetting',
      title: 'LaTeX Typesetting',
      category: ServiceCategory.project,
      description:
          'Clean LaTeX formatting for reports, papers and dissertations.',
      tags: ['latex', 'typesetting', 'report', 'thesis'],
      price: 0.5,
      priceType: PriceType.page,
    ),
    SeedService(
      slug: 'statistics-tutoring',
      title: 'Statistics Tutoring',
      category: ServiceCategory.tutoring,
      description:
          'Probability, hypothesis testing and regression made simple.',
      tags: ['statistics', 'tutoring', 'maths', 'regression'],
      price: 15,
      priceType: PriceType.hour,
    ),
    SeedService(
      slug: 'poster-design',
      title: 'Poster & Flyer Design',
      category: ServiceCategory.design,
      description:
          'Eye-catching event posters and society flyers, print ready.',
      tags: ['poster', 'flyer', 'design', 'graphic'],
      price: 20,
      priceType: PriceType.fixed,
    ),
    SeedService(
      slug: 'laptop-repair',
      title: 'Laptop Repair & Setup',
      category: ServiceCategory.tech,
      description: 'Software setup, OS reinstall, virus cleanup and upgrades.',
      tags: ['laptop', 'repair', 'setup', 'tech'],
      price: 25,
      priceType: PriceType.task,
    ),
    SeedService(
      slug: 'hostel-delivery',
      title: 'Hostel Delivery Run',
      category: ServiceCategory.delivery,
      description: 'Pick up parcels and shopping and drop them at your block.',
      tags: ['delivery', 'errand', 'hostel', 'courier'],
      price: 5,
      priceType: PriceType.task,
    ),
    SeedService(
      slug: 'cv-review',
      title: 'CV & Cover Letter Review',
      category: ServiceCategory.other,
      description: 'Detailed feedback on your CV and a tailored cover letter.',
      tags: ['cv', 'resume', 'cover letter', 'career'],
      price: 18,
      priceType: PriceType.fixed,
    ),
    SeedService(
      slug: 'python-assignments',
      title: 'Python Assignments',
      category: ServiceCategory.project,
      description: 'Help with Python coursework, data tasks and debugging.',
      tags: ['python', 'programming', 'assignment', 'coding'],
      price: 30,
      priceType: PriceType.task,
    ),
    SeedService(
      slug: 'calculus-tutoring',
      title: 'Calculus Tutoring',
      category: ServiceCategory.tutoring,
      description: 'Limits, derivatives and integrals explained step by step.',
      tags: ['calculus', 'tutoring', 'maths', 'integration'],
      price: 14,
      priceType: PriceType.hour,
    ),
    SeedService(
      slug: 'slide-design',
      title: 'Presentation Deck Design',
      category: ServiceCategory.design,
      description: 'Professional slide decks for presentations and pitches.',
      tags: ['slides', 'presentation', 'design', 'deck'],
      price: 22,
      priceType: PriceType.fixed,
    ),
    SeedService(
      slug: 'grocery-run',
      title: 'Grocery & Errand Run',
      category: ServiceCategory.delivery,
      description: 'Groceries, laundry drop-off and other quick errands.',
      tags: ['grocery', 'errand', 'delivery', 'shopping'],
      price: 6,
      priceType: PriceType.task,
    ),
  ];
}
