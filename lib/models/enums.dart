/// Every enum that crosses the wire, with the exact string values the
/// Firestore documents use. Ported from the Django `choices` lists so
/// behaviour matches the web app one-for-one.
library;

/// `Product.CONDITION_CHOICES`.
enum Condition {
  brandNew('new', 'New'),
  used('used', 'Used');

  const Condition(this.value, this.label);

  final String value;
  final String label;

  static Condition from(Object? raw) =>
      values.firstWhere((c) => c.value == raw, orElse: () => Condition.used);
}

/// `Order.STATUS_CHOICES` — the only states Souq Akimi launches with. Every
/// order is cash-on-delivery, so there is no payment state to track.
enum OrderStatus {
  pending('pending', 'On the way'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus from(Object? raw) => values.firstWhere(
    (s) => s.value == raw,
    orElse: () => OrderStatus.pending,
  );
}

/// `Delivery.STATUS_CHOICES` — one leg per seller.
enum DeliveryStatus {
  ready('ready', 'Ready for delivery'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const DeliveryStatus(this.value, this.label);

  final String value;
  final String label;

  /// Statuses that still need something to happen.
  bool get isOpen => this == ready;

  static DeliveryStatus from(Object? raw) => values.firstWhere(
    (s) => s.value == raw,
    orElse: () => DeliveryStatus.ready,
  );
}

/// `Service.CATEGORY_CHOICES`.
enum ServiceCategory {
  delivery('delivery', 'Delivery & errands'),
  homework('homework', 'Homework help'),
  project('project', 'Project help'),
  printing('printing', 'Printing & copies'),
  tutoring('tutoring', 'Tutoring & lessons'),
  design('design', 'Design & creative'),
  tech('tech', 'Tech help & repairs'),
  other('other', 'Other campus help');

  const ServiceCategory(this.value, this.label);

  final String value;
  final String label;

  static ServiceCategory from(Object? raw) => values.firstWhere(
    (c) => c.value == raw,
    orElse: () => ServiceCategory.other,
  );
}

/// `Service.PRICE_TYPE_CHOICES` — how a service price should be read.
enum PriceType {
  fixed('fixed', 'Fixed price', ''),
  hour('hour', 'Per hour', '/ hour'),
  task('task', 'Per job', '/ job'),
  page('page', 'Per page', '/ page');

  const PriceType(this.value, this.label, this.suffix);

  final String value;
  final String label;

  /// Shown after the price, e.g. `$45.00 / hour`.
  final String suffix;

  static PriceType from(Object? raw) =>
      values.firstWhere((p) => p.value == raw, orElse: () => PriceType.fixed);
}

/// `ServiceRequest.STATUS_CHOICES`.
enum ServiceRequestStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  completed('completed', 'Completed'),
  declined('declined', 'Declined'),
  cancelled('cancelled', 'Cancelled');

  const ServiceRequestStatus(this.value, this.label);

  final String value;
  final String label;

  bool get isOpen => this == pending || this == accepted;

  static ServiceRequestStatus from(Object? raw) => values.firstWhere(
    (s) => s.value == raw,
    orElse: () => ServiceRequestStatus.pending,
  );
}

/// `search.SORT_CHOICES` — the options offered in the sort sheet.
enum ProductSort {
  relevance('relevance', 'Best match'),
  newest('newest', 'Newest'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low'),
  topSale('top_sale', 'Top sales'),
  mostViewed('most_viewed', 'Most viewed'),
  name('name', 'Name A–Z');

  const ProductSort(this.value, this.label);

  final String value;
  final String label;

  static ProductSort from(Object? raw) => values.firstWhere(
    (s) => s.value == raw,
    orElse: () => ProductSort.relevance,
  );
}
