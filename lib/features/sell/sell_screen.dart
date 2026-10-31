import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../../core/app_config.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../providers/catalogue.dart';
import '../../widgets/ai_button.dart';
import '../../widgets/common.dart';
import '../../widgets/language_button.dart';

/// The "Sell" tab: pick a product or a service, then jump straight into its
/// form. Previously this tab dropped everyone into the product form, which made
/// services feel like a hidden side door.
class SellScreen extends ConsumerWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myProductsProvider).value?.length ?? 0;
    final services = ref.watch(myServicesProvider).value?.length ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 124),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B5D4B), Color(0xFF14897A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E0B5D4B),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_box_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(AppConfig.appNameEnglish),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const LanguageButton(),
              ],
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              child: Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF4C76A), Color(0xFFE3A33B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2EE3A33B),
                      blurRadius: 26,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start selling',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF3A2A06),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Turn an item you no longer need, or a skill you have, into extra cash.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF3A2A06)
                                  .withValues(alpha: 0.76),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF3A2A06),
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 2,
              child: _SellChoice(
                icon: Icons.inventory_2_rounded,
                title: 'Sell an item',
                body: 'A physical item students can buy and receive in their room.',
                foreground: Colors.white,
                iconBackground: Colors.white.withValues(alpha: 0.16),
                gradient: const [Color(0xFF0B5D4B), Color(0xFF14897A)],
                onTap: () => context.push('/sell/item'),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 3,
              child: _SellChoice(
                icon: Icons.handyman_rounded,
                title: 'Sell a service',
                body:
                    'A skill, errand or service you can do for other students.',
                foreground: const Color(0xFF3A2A06),
                iconBackground: Colors.white.withValues(alpha: 0.36),
                gradient: const [Color(0xFFF4C76A), Color(0xFFE3A33B)],
                onTap: () => context.push('/sell/service'),
              ),
            ),
            const SizedBox(height: 26),
            FadeSlideIn(index: 4, child: SectionHeader(title: 'Manage')),
            FadeSlideIn(
              index: 5,
              child: Row(
                children: [
                  Expanded(
                    child: _ManageCard(
                      icon: Icons.inventory_2_rounded,
                      value: '$listings',
                      label: 'My listings',
                      onTap: () => context.push('/my-listings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ManageCard(
                      icon: Icons.handyman_rounded,
                      value: '$services',
                      label: 'My services',
                      onTap: () => context.push('/my-services'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              index: 6,
              child: SoftBanner(
                icon: Icons.shield_rounded,
                text: context.tr(
                  'Buyers pay cash on delivery. Keep hand-overs on campus and use the six-digit code to confirm.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellChoice extends StatelessWidget {
  const _SellChoice({
    required this.icon,
    required this.title,
    required this.body,
    required this.foreground,
    required this.iconBackground,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color foreground;
  final Color iconBackground;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: gradient,
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: foreground, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_ios_new
                        : Icons.arrow_forward_ios,
                    size: 16,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
