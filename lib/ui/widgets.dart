import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../l10n/strings.dart';

Duration motion(BuildContext context, [int ms = 280]) =>
    Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : ms);

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 26, bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 46, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? colors.primary).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, color: color ?? colors.primary, size: size * .48),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.warning = false,
    this.neutral = false,
  });
  final String text;
  final bool warning, neutral;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = warning
        ? const Color(0xffad7423)
        : neutral
        ? c.onSurfaceVariant
        : c.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.app,
    required this.controller,
    this.size = 46,
  });
  final InstalledApp app;
  final AppController controller;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .27),
    child: FutureBuilder<Uint8List?>(
      future: controller.icon(app.package),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => IconTile(Icons.apps_rounded, size: size),
          );
        }
        return IconTile(switch (app.category) {
          'banking' => Icons.account_balance_rounded,
          'social' => Icons.forum_rounded,
          _ => Icons.apps_rounded,
        }, size: size);
      },
    ),
  );
}

class ExpandingCard extends StatefulWidget {
  const ExpandingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  @override
  State<ExpandingCard> createState() => _ExpandingCardState();
}

class _ExpandingCardState extends State<ExpandingCard> {
  late bool expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                IconTile(widget.icon, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: motion(context),
                  curve: Curves.easeInOutCubic,
                  child: const Icon(Icons.expand_more_rounded),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: motion(context, 320),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.strings});
  final Strings strings;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      children: [
        IconTile(Icons.search_off_rounded, size: 68),
        const SizedBox(height: 20),
        Text(
          strings.t('nothing'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          strings.t('nothing_desc'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.code,
    required this.strings,
    this.retry,
  });
  final String code;
  final Strings strings;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.error(code),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (retry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: retry,
                child: Text(strings.t('refresh')),
              ),
            ),
        ],
      ),
    ),
  );
}
