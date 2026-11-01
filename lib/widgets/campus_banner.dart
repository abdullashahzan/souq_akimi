import 'ui.dart';
import '../core/motion.dart';

/// Editorial masthead. Only labelled controls navigate; artwork is decorative.
class CampusBanner extends StatelessWidget {
  const CampusBanner({super.key, required this.search});
  final Widget search;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF103F35), Color(0xFF186953)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          return Stack(
            children: [
              PositionedDirectional(
                end: -90,
                top: -120,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 40,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  'A little more local',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFF5D997),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Good finds.\nBetter campus life.',
                                style:
                                    (wide
                                            ? theme.textTheme.displaySmall
                                            : theme.textTheme.headlineSmall)
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                          letterSpacing: -0.8,
                                        ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Pre-loved things. Useful skills. People nearby.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD0E2D6),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 22),
                          const ExcludeSemantics(child: _CampusCollage()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    search,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CampusCollage extends StatelessWidget {
  const _CampusCollage();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 198,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          end: 12,
          top: 4,
          child: Transform.rotate(
            angle: 0.12,
            child: const _PhotoTile(
              icon: Icons.headphones_rounded,
              size: 142,
              color: Color(0xFFF7D584),
            ),
          ),
        ),
        PositionedDirectional(
          start: 6,
          bottom: 2,
          child: Transform.rotate(
            angle: -0.12,
            child: const _PhotoTile(
              icon: Icons.menu_book_rounded,
              size: 132,
              color: Color(0xFFF7F2E6),
            ),
          ),
        ),
        PositionedDirectional(
          end: 4,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              color: Color(0xFFDDF1CA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF254B39),
              size: 25,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.icon,
    required this.size,
    required this.color,
  });
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size + 16,
    padding: const EdgeInsets.fromLTRB(7, 7, 7, 17),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Center(
        child: Icon(icon, size: size * .6, color: const Color(0xFF254B39)),
      ),
    ),
  );
}

/// A real destination, styled as an editorial feature rather than an ad.
class DiscoveryLink extends StatelessWidget {
  const DiscoveryLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 26, color: const Color(0xFF254B39)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
