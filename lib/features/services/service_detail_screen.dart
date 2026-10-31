import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../../core/app_config.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../models/service.dart';
import '../../providers/auth.dart';
import '../../providers/catalogue.dart';
import '../../providers/dependencies.dart';
import '../../providers/orders.dart';
import '../../providers/sellers.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/common.dart';
import '../../widgets/listing_image.dart';
import '../../widgets/service_card.dart';
import '../auth/require_auth.dart';

/// A service listing, its gallery, and the brief a buyer sends with it.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  bool _countedView = false;

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(serviceByIdProvider(widget.serviceId));

    return serviceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: const SouqBackButton()),
        body: ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(serviceByIdProvider(widget.serviceId)),
        ),
      ),
      data: (service) {
        if (service == null) {
          return Scaffold(
            appBar: AppBar(leading: const SouqBackButton()),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Service not found',
              message: 'It may have been removed by its provider.',
            ),
          );
        }
        if (!_countedView) {
          _countedView = true;
          ref.read(serviceRepositoryProvider).recordView(service.id);
        }

        final uid = ref.watch(currentUidProvider) ?? '';
        final isOwner = service.isOwnedBy(uid);
        final seller = ref
            .watch(sellerProfileProvider(service.providerId))
            .value;
        final sellerName = seller?.username.trim().isNotEmpty == true
            ? seller!.username
            : service.providerUsername;
        final openRequest = ref
            .watch(outgoingRequestsProvider)
            .value
            ?.where(
              (r) =>
                  r.serviceId == service.id && r.requesterId == uid && r.isOpen,
            )
            .firstOrNull;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              service.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: context.tr('Edit service'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/service/${service.id}/edit'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: isOwner
              ? null
              : _RequestBar(
                  enabled: openRequest == null,
                  label: openRequest == null
                      ? 'Request this service'
                      : context.tr(
                          'Request sent ({status})',
                          args: {
                            'status': context.tr(openRequest.status.label),
                          },
                        ),
                  onPressed: () => _openBriefSheet(context, service),
                ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ServiceGallery(service: service),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Format.priceWithUnit(
                        service.price,
                        service.priceType.suffix,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          avatar: Icon(
                            serviceCategoryIcon(service.category),
                            size: 16,
                          ),
                          label: Text(service.category.label),
                        ),
                        Chip(label: Text(service.priceType.label)),
                        if (service.viewsCount > 0)
                          Chip(
                            avatar: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                            ),
                            label: Text(
                              context.tr(
                                '{count} views',
                                args: {'count': '${service.viewsCount}'},
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (sellerName.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              sellerName[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            sellerHandle(sellerName, seller?.salesCount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('Service provider on campus'),
                          trailing: Icon(
                            Icons.verified_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    Text(
                      'What you get',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (service.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final tag in service.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SoftBanner(
                      icon: Icons.location_on_outlined,
                      text: 'The provider comes to your hostel room. Share your building and room with the brief.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBriefSheet(BuildContext context, Service service) async {
    if (!requireSignIn(
      context,
      ref,
      message: 'Sign in to request a service.',
    )) {
      return;
    }
    final data = await showModalBottomSheet<_BriefData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BriefSheet(service: service),
    );
    if (data == null || !context.mounted) return;

    showMessage('Request sent.');
  }
}

class _ServiceGallery extends StatefulWidget {
  const _ServiceGallery({required this.service});

  final Service service;

  @override
  State<_ServiceGallery> createState() => _ServiceGalleryState();
}

class _ServiceGalleryState extends State<_ServiceGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.service.images.isEmpty
        ? <String>['']
        : widget.service.images;
    final theme = Theme.of(context);
    return SizedBox(
      height: (MediaQuery.sizeOf(context).width * 0.625).clamp(200.0, 360.0),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => photos[index].isEmpty
                ? Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Icon(
                      serviceCategoryIcon(widget.service.category),
                      size: 78,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : ListingImage(
                    url: photos[index],
                    label: widget.service.title,
                    seed: index == 0
                        ? widget.service.id
                        : '${widget.service.id}-$index',
                  ),
          ),
          if (photos.length > 1)
            PositionedDirectional(
              bottom: 12,
              start: 0,
              end: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BriefData {
  const _BriefData({
    required this.message,
    required this.phone,
    required this.building,
    required this.roomNumber,
  });

  final String message;
  final String phone;
  final String building;
  final String roomNumber;
}

class _BriefSheet extends ConsumerStatefulWidget {
  const _BriefSheet({required this.service});

  final Service service;

  @override
  ConsumerState<_BriefSheet> createState() => _BriefSheetState();
}

class _BriefSheetState extends ConsumerState<_BriefSheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _phone = TextEditingController();
  final _room = TextEditingController();
  String? _building;
  bool _aiBusy = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileOrEmptyProvider);
    _phone.text = profile.phone;
    _room.text = profile.roomNumber;
    if (profile.building.trim().isNotEmpty) {
      _building = AppConfig.buildingFor(profile.building).code;
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    setState(() => _aiBusy = true);
    try {
      final text = await ref
          .read(aiAssistantProvider)
          .serviceBrief(
            serviceTitle: widget.service.title,
            hint: _message.text.trim(),
            building: _building == null
                ? ''
                : context.isArabic
                ? AppConfig.buildingFor(_building!).arabicLabel
                : AppConfig.buildingFor(_building!).englishLabel,
            room: _room.text.trim(),
          );
      if (!mounted) return;
      _message.text = text;
      _message.selection = TextSelection.collapsed(offset: text.length);
    } catch (error) {
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_message.text.trim().length < 10) {
      showMessage('Add a little more detail so they can help.');
      return;
    }
    final data = _BriefData(
      message: _message.text.trim(),
      phone: _phone.text.trim(),
      building: _building ?? '',
      roomNumber: _room.text.trim(),
    );
    setState(() => _sending = true);
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final profile = await ref.read(profileProvider.future);
      if (profile.uid != uid) return;
      await ref
          .read(serviceRepositoryProvider)
          .createRequest(
            service: widget.service,
            requesterId: uid,
            requesterUsername: profile.username,
            message: data.message,
            phone: data.phone,
            building: data.building,
            roomNumber: data.roomNumber,
          );
      ref
          .read(userRepositoryProvider)
          .saveDeliveryDetails(
            uid: uid,
            phone: data.phone,
            building: data.building,
            roomNumber: data.roomNumber,
          )
          .catchError((Object _) {});
      if (mounted) Navigator.of(context).pop(data);
    } catch (error) {
      // Keep the brief visible on failure so retry never loses the draft.
      if (mounted) showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, insets + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What do you need?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This brief goes straight to the provider, with your contact details.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _message,
                  minLines: 4,
                  maxLines: 8,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.tr('What do you need?'),
                    hintText: context.tr(
                      'e.g. I need 40 pages printed in colour and bound, ready by Thursday evening.',
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value ?? '').trim().length >= 10
                      ? null
                      : context.tr(
                          'Add a little more detail so they can help.',
                        ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AiAssistButton(
                    label: 'Draft my brief',
                    loading: _aiBusy,
                    onPressed: _sending ? null : _draft,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Your contact details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Shared with provider',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone'),
                    hintText: '05xxxxxxxx',
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length >= 8
                        ? null
                        : context.tr('Enter a phone number');
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _building,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Building'),
                  ),
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
                  onChanged: (value) => setState(() => _building = value),
                  validator: (value) =>
                      value == null ? context.tr('Choose your building') : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _room,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Room number'),
                    hintText: '214',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.tr('Enter your room number')
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending || _aiBusy ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Send request'),
                ),
                const SizedBox(height: 4),
                Text(
                  'You pay the provider directly when the work is done.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestBar extends StatelessWidget {
  const _RequestBar({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.send_outlined),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
