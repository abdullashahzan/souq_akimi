import 'package:souq_akimi/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../providers/auth.dart';
import '../../providers/dependencies.dart';
import '../../providers/orders.dart';
import '../../widgets/common.dart';
import '../../widgets/listing_image.dart';
import '../../widgets/listing_gallery.dart';

/// Checkout for the single "buy now" item.
///
/// Souq is cartless, cash-on-delivery only and always delivers to the buyer's
/// hostel room. The details entered here are remembered on the profile, so the
/// next checkout is already filled in.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _room = TextEditingController();
  final _notes = TextEditingController();

  String? _building;
  bool _prefilled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _room.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled) return;
    // Wait for the live profile of *this* account. The fallback profile used
    // while the stream loads has a uid too, so checking only for a non-empty
    // uid would lock in a blank form for the rest of the checkout.
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(profileProvider).value;
    if (uid == null || profile == null || profile.uid != uid) return;
    _prefilled = true;
    setState(() {
      _name.text = profile.displayName.isNotEmpty
          ? profile.displayName
          : profile.username;
      _phone.text = profile.phone;
      _room.text = profile.roomNumber;
      _building = profile.building.isNotEmpty
          ? AppConfig.buildingFor(profile.building).code
          : null;
      if (profile.email.isNotEmpty) _email.text = profile.email;
    });
  }

  Future<void> _placeOrder() async {
    final draft = ref.read(pendingPurchaseProvider);
    final product = draft.product;
    if (product == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            items: [
              {'productId': product.id, 'quantity': draft.quantity},
            ],
            delivery: {
              'fullName': _name.text.trim(),
              'email': _email.text.trim(),
              'phone': _phone.text.trim(),
              'building': _building ?? '',
              'roomNumber': _room.text.trim(),
              'deliveryNotes': _notes.text.trim(),
            },
          );

      ref.read(pendingPurchaseProvider.notifier).clear();
      if (mounted) {
        context.go('/order/${result.orderNumber}/confirmed');
      }
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checkout is opened before the profile stream emits, fill the form as
    // soon as it arrives instead of leaving the buyer to retype everything.
    ref.listen(profileProvider, (_, _) => _prefill());
    final draft = ref.watch(pendingPurchaseProvider);
    final product = draft.product;
    final theme = Theme.of(context);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: const SouqBackButton(),
        ),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing to check out',
          message: 'Pick something you like first.',
          action: FilledButton.tonal(
            onPressed: () => context.go('/'),
            child: const Text('Browse the souq'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: const SouqBackButton(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _placeOrder,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr(
                        'Place order · {total}',
                        args: {'total': Format.money(draft.lineTotal)},
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- The item ------------------------------------------------
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: PhotoPreview(
                      images: product.images,
                      label: product.name,
                      child: ListingImage(
                        url: product.images.isEmpty ? '' : product.images.first,
                        label: product.name,
                        seed: product.id,
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${Format.money(product.price)} × ${draft.quantity}',
                  ),
                  trailing: Text(
                    Format.money(draft.lineTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Delivery ------------------------------------------------
              Text(
                'Delivery',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivered to your hostel room',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr(
                                '@{seller} brings it to your room — pay cash when it arrives.',
                                args: {'seller': product.sellerUsername},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Buyer details -------------------------------------------
              Text(
                'Your details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We remember these, so you only fill them in once.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('Full name')),
                validator: (v) => (v ?? '').trim().length >= 2
                    ? null
                    : context.tr('Enter the name the seller should ask for'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('Phone')),
                validator: (v) => (v ?? '').trim().length >= 6
                    ? null
                    : context.tr('Enter a phone number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: context.tr('Email')),
                validator: (v) {
                  final value = (v ?? '').trim();
                  return value.contains('@') && value.contains('.')
                      ? null
                      : context.tr('Enter a valid email');
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _building,
                decoration: InputDecoration(labelText: context.tr('Building')),
                hint: Text(context.tr('Choose your hostel block')),
                items: [
                  for (final building in AppConfig.hostelBuildings)
                    DropdownMenuItem(
                      value: building.code,
                      child: Text(
                        context.isArabic
                            ? building.arabicLabel
                            : building.englishLabel,
                      ),
                    ),
                ],
                validator: (v) => (v ?? '').isEmpty
                    ? context.tr('Choose your building')
                    : null,
                onChanged: (value) => setState(() => _building = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('Room number'),
                  hintText: context.tr('e.g. 214'),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.tr('Enter your room number')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.tr('Notes for the seller (optional)'),
                  hintText: context.tr(
                    'e.g. Call me when you reach the block gate.',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Payment -------------------------------------------------
              Text(
                'Payment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cash on delivery',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr(
                                'Pay {amount} in cash when the item is in your hands.',
                                args: {'amount': Format.money(draft.lineTotal)},
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.password_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will get a 6-digit hand-over code. Read it to the '
                      'seller only when the item arrives — that is what '
                      'completes the order.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (product.stock < draft.quantity) ...[
                Text(
                  context.tr(
                    'Only {count} left — adjust the quantity on the listing page.',
                    args: {'count': '${product.stock}'},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Delivery is free on campus — the constant exists so the checkout total and
/// the order summary can never disagree.
const double kDeliveryFee = 0;
