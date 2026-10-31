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
import '../../models/service.dart';
import '../../providers/auth.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_strip.dart';
import '../../widgets/service_card.dart';

/// Offer a service, or edit an existing one.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId});

  final String? serviceId;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _price = TextEditingController();
  ServiceCategory _category = ServiceCategory.other;
  PriceType _priceType = PriceType.fixed;
  List<String> _images = const [];

  /// Photos replaced while this form was open — deleted once the save lands.
  final Set<String> _discardedImages = {};
  final Set<String> _uploadedThisSession = {};
  bool _busy = false;
  bool _descriptionBusy = false;
  bool _tagsBusy = false;
  bool _loaded = false;
  bool _saved = false;

  bool get isEditing => widget.serviceId != null;

  @override
  void dispose() {
    if (!_saved && _uploadedThisSession.isNotEmpty) {
      try {
        final store = ref.read(imageStoreProvider);
        final orphaned = _uploadedThisSession
            .where((token) => !_images.contains(token) || !isEditing)
            .toList(growable: false);
        if (orphaned.isNotEmpty) store.deleteAll(orphaned);
      } catch (_) {}
    }
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _price.dispose();
    super.dispose();
  }

  void _hydrate(Service service) {
    if (_loaded) return;
    _loaded = true;
    _title.text = service.title;
    _description.text = service.description;
    _tags.text = service.tags.join(', ');
    _price.text = service.price.toStringAsFixed(2);
    _category = service.category;
    _priceType = service.priceType;
    _images = List.of(service.images);
  }

  void _resetForm() {
    _title.clear();
    _description.clear();
    _tags.clear();
    _price.clear();
    setState(() {
      _category = ServiceCategory.other;
      _priceType = PriceType.fixed;
      _images = const [];
      _discardedImages.clear();
      _uploadedThisSession.clear();
      _loaded = false;
    });
  }

  // --------------------------------------------------------------------- #
  // Photos
  // --------------------------------------------------------------------- #
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

  // --------------------------------------------------------------------- #
  // AI helpers
  // --------------------------------------------------------------------- #
  Future<void> _writeDescription() async {
    if (_title.text.trim().length < 3) {
      showMessage('Add a title first so AI has something to work with.');
      return;
    }
    setState(() => _descriptionBusy = true);
    try {
      final text = await ref
          .read(aiAssistantProvider)
          .serviceDescription(
            title: _title.text.trim(),
            category: context.tr(_category.label),
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
    if (_title.text.trim().length < 3) {
      showMessage('Add a title first so AI has something to work with.');
      return;
    }
    setState(() => _tagsBusy = true);
    try {
      final tags = await ref
          .read(aiAssistantProvider)
          .tags(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: context.tr(_category.label),
          );
      if (!mounted || tags.isEmpty) return;
      _tags.text = tags.join(', ');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _tagsBusy = false);
    }
  }

  // --------------------------------------------------------------------- #
  // Save
  // --------------------------------------------------------------------- #
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

      if (isEditing) {
        final existing = ref
            .read(serviceCatalogueProvider)
            .where((s) => s.id == widget.serviceId)
            .firstOrNull;
        if (existing == null) {
          throw SouqException(translate('That item no longer exists.'));
        }
        await ref
            .read(serviceRepositoryProvider)
            .update(
              existing.copyWith(
                title: _title.text.trim(),
                category: _category,
                description: _description.text.trim(),
                tags: tags,
                price: price,
                priceType: _priceType,
                images: _images,
              ),
            );
      } else {
        await ref
            .read(serviceRepositoryProvider)
            .create(
              Service(
                id: '',
                providerId: uid,
                providerUsername: username,
                title: _title.text.trim(),
                category: _category,
                description: _description.text.trim(),
                tags: tags,
                price: price,
                priceType: _priceType,
                images: _images,
                isActive: true,
                viewsCount: 0,
              ),
            );
      }

      final dropped = _discardedImages.difference(_images.toSet());
      _discardedImages.clear();
      if (dropped.isNotEmpty) {
        await ref.read(imageStoreProvider).deleteAll(dropped);
      }
      _saved = true;

      if (!mounted) return;
      if (isEditing) {
        showMessage('Service updated.');
        context.pop();
        return;
      }
      _resetForm();
      showMessage('Service is live.');
      context.go('/my-services');
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      final service = ref.watch(serviceByIdProvider(widget.serviceId!)).value;
      if (!_loaded && service != null) _hydrate(service);
    }
    final theme = Theme.of(context);
    final working = _busy || _descriptionBusy || _tagsBusy;

    return Scaffold(
      appBar: AppBar(
        leading: const SouqBackButton(fallback: '/sell'),
        title: Text(isEditing ? 'Edit service' : 'Offer a service'),
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
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr('Title'),
                    hintText: context.tr('e.g. Printouts & binding — same day'),
                  ),
                  validator: (v) => (v ?? '').trim().length >= 3
                      ? null
                      : context.tr('Use at least 3 characters'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ServiceCategory>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: context.tr('Category'),
                  ),
                  items: [
                    for (final category in ServiceCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(serviceCategoryIcon(category), size: 18),
                            const SizedBox(width: 8),
                            Text(context.tr(category.label)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _category = value ?? ServiceCategory.other,
                  ),
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
                      'What you will do, how long it takes, and where you can hand it over.',
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v ?? '').trim().length >= 5
                      ? null
                      : context.tr('Tell clients a little more'),
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
                    hintText: context.tr('printing, binding, thesis'),
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
                      child: DropdownButtonFormField<PriceType>(
                        initialValue: _priceType,
                        decoration: InputDecoration(
                          labelText: context.tr('Charged'),
                        ),
                        items: [
                          for (final type in PriceType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(context.tr(type.label)),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => _priceType = value ?? PriceType.fixed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: working ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Save changes' : 'Publish service'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
