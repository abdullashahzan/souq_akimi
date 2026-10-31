import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/souq_exception.dart';
import '../../models/enums.dart';
import '../../models/product.dart';
import '../../providers/auth.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_strip.dart';

/// Create a listing, or edit one you already own.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// When set the screen edits this listing instead of creating one.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
  Condition _condition = Condition.used;
  List<String> _images = const [];

  /// Photos dropped while this form was open — deleted once the save lands.
  final Set<String> _discardedImages = {};

  /// Fresh uploads. If the screen is abandoned, these are cleaned up too.
  final Set<String> _uploadedThisSession = {};
  bool _busy = false;
  bool _descriptionBusy = false;
  bool _tagsBusy = false;
  bool _loaded = false;
  bool _saved = false;

  bool get isEditing => widget.productId != null;

  @override
  void dispose() {
    if (!_saved && _uploadedThisSession.isNotEmpty) {
      // Fire-and-forget: the widget is going away, but the orphaned docs
      // should not stay billed in Firestore.
      try {
        final store = ref.read(imageStoreProvider);
        final orphaned = _uploadedThisSession
            .where((token) => !_images.contains(token) || !isEditing)
            .toList(growable: false);
        if (orphaned.isNotEmpty) store.deleteAll(orphaned);
      } catch (_) {}
    }
    _name.dispose();
    _description.dispose();
    _tags.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _hydrate(Product product) {
    if (_loaded) return;
    _loaded = true;
    _name.text = product.name;
    _description.text = product.description;
    _tags.text = product.tags.join(', ');
    _price.text = product.price.toStringAsFixed(2);
    _stock.text = '${product.stock}';
    _condition = product.condition;
    _images = List.of(product.images);
  }

  Future<void> _pickImages() async {
    final remaining = AppConfig.galleryImagesPerListing - _images.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      limit: remaining,
      maxWidth: AppConfig.maxImagePickEdge,
      maxHeight: AppConfig.maxImagePickEdge,
      imageQuality: 90,
    );
    if (picked.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final store = ref.read(imageStoreProvider);
      final tokens = <String>[];
      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > AppConfig.maxImageBytes) {
          if (mounted) {
            showMessage('Skipped {name}: over 5 MB.', args: {'name': file.name});
          }
          continue;
        }
        tokens.add(await store.saveImage(ownerId: uid, bytes: bytes));
      }
      if (!mounted) return;
      setState(() {
        _images = [..._images, ...tokens].take(
          AppConfig.galleryImagesPerListing,
        ).toList();
        _uploadedThisSession.addAll(tokens);
        _discardedImages.addAll(tokens.where((t) => !_images.contains(t)));
      });
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _discardedImages.add(_images[index]);
      _images = [
        for (var i = 0; i < _images.length; i++)
          if (i != index) _images[i],
      ];
    });
  }

  void _resetForm() {
    _name.clear();
    _description.clear();
    _tags.clear();
    _price.clear();
    _stock.text = '1';
    setState(() {
      _condition = Condition.used;
      _images = const [];
      _discardedImages.clear();
      _uploadedThisSession.clear();
      _loaded = false;
    });
  }

  Future<void> _cleanupDiscardedImages() async {
    final dropped = _discardedImages.difference(_images.toSet());
    _discardedImages.removeAll(dropped);
    if (dropped.isEmpty) return;
    await ref.read(imageStoreProvider).deleteAll(dropped);
  }

  Future<void> _writeDescription() async {
    if (_name.text.trim().length < 3) {
      showMessage('Add a title first so AI has something to work with.');
      return;
    }
    setState(() => _descriptionBusy = true);
    try {
      final text = await ref
          .read(aiAssistantProvider)
          .productDescription(
            title: _name.text.trim(),
            category: '',
            condition: context.tr(_condition.label),
            price: _price.text.trim().isEmpty
                ? ''
                : Format.money(double.tryParse(_price.text.trim())),
            notes: _description.text.trim(),
          );
      if (!mounted) return;
      _description.text = text;
      _description.selection = TextSelection.collapsed(offset: text.length);
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _descriptionBusy = false);
    }
  }

  Future<void> _suggestTags() async {
    if (_name.text.trim().length < 3) {
      showMessage('Add a title first so AI has something to work with.');
      return;
    }
    setState(() => _tagsBusy = true);
    try {
      final tags = await ref
          .read(aiAssistantProvider)
          .tags(
            title: _name.text.trim(),
            description: _description.text.trim(),
            category: context.tr(_condition.label),
          );
      if (!mounted || tags.isEmpty) return;
      _tags.text = tags.join(', ');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _tagsBusy = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final username = ref.read(profileOrEmptyProvider).username;

    setState(() => _busy = true);
    try {
      final tags = _tags.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
      final price = double.tryParse(_price.text.trim()) ?? 0;
      final stock = int.tryParse(_stock.text.trim()) ?? 0;

      if (isEditing) {
        final existing = ref
            .read(productCatalogueProvider)
            .where((p) => p.id == widget.productId)
            .firstOrNull;
        if (existing == null) {
          throw SouqException(translate('That item no longer exists.'));
        }
        await ref
            .read(productRepositoryProvider)
            .update(
              existing.copyWith(
                name: _name.text.trim(),
                description: _description.text.trim(),
                tags: tags,
                price: price,
                condition: _condition,
                stock: stock,
                images: _images,
              ),
            );
      } else {
        await ref
            .read(productRepositoryProvider)
            .create(
              Product(
                id: '',
                sellerId: uid,
                sellerUsername: username,
                name: _name.text.trim(),
                description: _description.text.trim(),
                tags: tags,
                price: price,
                condition: _condition,
                stock: stock,
                isActive: true,
                images: _images,
                viewsCount: 0,
                soldCount: 0,
              ),
            );
      }

      await _cleanupDiscardedImages();
      _saved = true;

      if (!mounted) return;
      if (isEditing) {
        showMessage('Listing updated.');
        context.pop();
        return;
      }
      _resetForm();
      showMessage('Listing is live.');
      context.go('/my-listings');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      final product = ref.watch(productByIdProvider(widget.productId!)).value;
      if (!_loaded && product != null) _hydrate(product);
    }
    final theme = Theme.of(context);
    final working = _busy || _descriptionBusy || _tagsBusy;

    return Scaffold(
      appBar: AppBar(
        leading: const SouqBackButton(fallback: '/sell'),
        title: Text(isEditing ? 'Edit listing' : 'Sell an item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhotoStrip(
                  images: _images,
                  busy: _busy,
                  onAdd: _pickImages,
                  onRemove: _removeImage,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr('What are you selling?'),
                    hintText: context.tr('e.g. Vintage camera'),
                  ),
                  validator: (v) => (v ?? '').trim().length >= 3
                      ? null
                      : context.tr('Use at least 3 characters'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Description',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    AiAssistButton(
                      label: 'Write with AI',
                      loading: _descriptionBusy,
                      onPressed: _busy ? null : _writeDescription,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 9,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'Describe the item, its condition and any details.',
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v ?? '').trim().length >= 5
                      ? null
                      : context.tr('Tell buyers a little more'),
                ),
                const SizedBox(height: 4),
                const AiHint(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tags (optional)',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    AiAssistButton(
                      label: 'Suggest tags',
                      loading: _tagsBusy,
                      onPressed: _busy ? null : _suggestTags,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tags,
                  decoration: InputDecoration(
                    hintText: context.tr('gaming, vintage, size 42'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('Price'),
                          prefixText:
                              '${context.isArabic ? AppConfig.currencySymbolArabic : AppConfig.currencySymbol} ',
                        ),
                        validator: (v) {
                          final value = double.tryParse((v ?? '').trim());
                          if (value == null || value <= 0) {
                            return context.tr('Enter a price above zero');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Quantity'),
                        ),
                        validator: (v) {
                          final value = int.tryParse((v ?? '').trim());
                          if (value == null || value < 0) {
                            return context.tr('Enter a quantity');
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Condition',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                SegmentedButton<Condition>(
                  segments: [
                    for (final value in Condition.values)
                      ButtonSegment(
                        value: value,
                        label: Text(context.tr(value.label)),
                        icon: Icon(
                          value == Condition.brandNew
                              ? Icons.star_outline
                              : Icons.recycling_outlined,
                        ),
                      ),
                  ],
                  selected: {_condition},
                  onSelectionChanged: (selection) =>
                      setState(() => _condition = selection.first),
                ),
                if (_images.isEmpty) ...[
                  const SizedBox(height: 10),
                  const SoftBanner(
                    icon: Icons.photo_outlined,
                    text:
                        'Listings with a clear cover photo sell much faster. Add up to six.',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: working ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Save changes' : 'Publish listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
