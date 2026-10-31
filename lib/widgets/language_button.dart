import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:souq_akimi/widgets/ui.dart';

import '../core/l10n.dart';
import '../providers/locale.dart';

/// A compact globe that opens the two-language picker.
///
/// It is deliberately present on the signed-out screens too: a student should
/// not have to create an account before they can read the app in Arabic.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('Language'),
      icon: Icon(Icons.translate, color: onDark ? Colors.white : null),
      onSelected: (next) => ref.read(localeProvider.notifier).setLanguage(next),
      itemBuilder: (context) => [
        for (final option in AppLanguage.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == language
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: option == language
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  option == AppLanguage.arabic ? 'العربية' : 'English',
                  style: TextStyle(
                    fontWeight: option == language
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A full-width language row for the profile screen.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.translate, color: theme.colorScheme.primary),
        title: Text(
          context.tr('Language'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(language == AppLanguage.arabic ? 'العربية' : 'English'),
        trailing: SegmentedButton<AppLanguage>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment(value: AppLanguage.english, label: Text('EN')),
            ButtonSegment(value: AppLanguage.arabic, label: Text('ع')),
          ],
          selected: {language},
          onSelectionChanged: (selection) =>
              ref.read(localeProvider.notifier).setLanguage(selection.first),
        ),
      ),
    );
  }
}
