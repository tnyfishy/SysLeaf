import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../l10n/strings.dart';
import 'widgets.dart';
import 'country_flag.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final s = Strings(controller.preferences.language);
    final c = Theme.of(context).colorScheme;
    final prefs = controller.preferences;
    return SingleChildScrollView(
      key: const PageStorageKey('settings-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(
                    Icons.palette_outlined,
                    s.t('appearance'),
                    s.t('appearance_desc'),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final option in Appearance.values)
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: _ThemeChoice(
                              appearance: option,
                              selected: prefs.appearance == option,
                              label: s.t('theme_${option.name}'),
                              onTap: controller.saving
                                  ? null
                                  : () => controller.setPreferences(
                                      appearance: option,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(
                    Icons.translate_rounded,
                    s.t('language'),
                    s.t('language_desc'),
                  ),
                  const SizedBox(height: 18),
                  _LanguageChoice(
                    flag: '🇻🇳',
                    label: 'Tiếng Việt',
                    subtitle: 'Vietnamese',
                    selected: prefs.language == 'vi',
                    onTap: controller.saving
                        ? null
                        : () => controller.setPreferences(language: 'vi'),
                  ),
                  const SizedBox(height: 10),
                  _LanguageChoice(
                    flag: '🇺🇸',
                    label: 'English',
                    subtitle: 'Tiếng Anh',
                    selected: prefs.language == 'en',
                    onTap: controller.saving
                        ? null
                        : () => controller.setPreferences(language: 'en'),
                  ),
                ],
              ),
            ),
          ),
          if (controller.errorCode != null) ...[
            const SizedBox(height: 16),
            ErrorCard(code: controller.errorCode!, strings: s),
          ],
          const SizedBox(height: 16),
          ExpandingCard(
            title: s.t('system_info'),
            icon: Icons.phone_android_rounded,
            child: Column(
              children: [
                _InfoRow(s.t('device'), controller.environment?.device ?? '—'),
                _InfoRow(
                  'Android SDK',
                  controller.environment?.androidSdk ?? '—',
                ),
                _InfoRow(
                  s.t('manager'),
                  controller.environment?.manager ?? '—',
                ),
                _InfoRow(
                  s.t('partition'),
                  '/system/app (🏦)\n/system_ext/priv-app',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ExpandingCard(
            title: s.t('about'),
            icon: Icons.eco_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('about_desc'),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 12),
                Text(
                  s.t('privacy'),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.onSurfaceVariant,
                    height: 1.5,
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

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconTile(icon, size: 40),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.appearance,
    required this.selected,
    required this.label,
    this.onTap,
  });
  final Appearance appearance;
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dark =
        appearance == Appearance.dark || appearance == Appearance.black;
    final background = appearance == Appearance.black
        ? Colors.black
        : dark
        ? const Color(0xff202820)
        : const Color(0xfff2f6ee);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: AnimatedContainer(
        duration: motion(context, 220),
        decoration: BoxDecoration(
          color: selected
              ? c.primaryContainer.withValues(alpha: .4)
              : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected
                ? c.primary
                : c.outlineVariant.withValues(alpha: .6),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    height: 57,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          color: appearance == Appearance.system
                              ? const Color(0xff202820)
                              : dark
                              ? const Color(0xff111711)
                              : const Color(0xffe1e9da),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 5,
                                  width: 35,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff83ad87),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Container(
                                  height: 4,
                                  color: dark ? Colors.white24 : Colors.black12,
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 4,
                                  width: 40,
                                  color: dark ? Colors.white24 : Colors.black12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 17,
                        color: selected ? c.primary : c.outlineVariant,
                      ),
                    ],
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

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.flag,
    required this.label,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });
  final String flag, label, subtitle;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: motion(context, 220),
        decoration: BoxDecoration(
          color: selected
              ? c.primaryContainer.withValues(alpha: .35)
              : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? c.primary.withValues(alpha: .5)
                : c.outlineVariant.withValues(alpha: .5),
          ),
        ),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: CountryFlag(flag == '🇻🇳' ? 'vi' : 'en'),
          title: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 21,
            color: selected ? c.primary : c.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
