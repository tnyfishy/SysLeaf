import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../l10n/strings.dart';
import 'dialogs.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.chooseApps,
  });
  final AppController controller;
  final VoidCallback chooseApps;
  @override
  Widget build(BuildContext context) {
    final s = Strings(controller.preferences.language);
    final c = Theme.of(context).colorScheme;
    final env = controller.environment!;
    final engineActive =
        env.manager == 'Magisk' ||
        (env.hybridReady && env.reason != 'HYBRID_RULE_BLOCKED');
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        key: const PageStorageKey('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: c.primaryContainer.withValues(alpha: .65),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: c.primary,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'SYSTEMIZE • READY TO USE 👾',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            s.t('hero'),
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1.16,
                              letterSpacing: -.9,
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _LeafArtwork(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.t('hero_desc'),
                      style: TextStyle(
                        color: c.onSurfaceVariant,
                        height: 1.6,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: chooseApps,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(s.t('choose_apps'))),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    const IconTile(Icons.verified_user_outlined),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.t('root_ready'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            env.manager,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: c.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (controller.errorCode != null) ...[
              const SizedBox(height: 14),
              ErrorCard(
                code: controller.errorCode!,
                strings: s,
                retry: controller.refresh,
              ),
            ],
            SectionLabel(s.t('overview')),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Statistic(
                    '${controller.eligibleCount}',
                    s.t('available'),
                    Icons.apps_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Statistic(
                    '${controller.managedCount}',
                    s.t('managed'),
                    Icons.layers_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Statistic(
                    '${controller.pendingCount}',
                    s.t('pending'),
                    Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
            if (controller.pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: c.secondaryContainer.withValues(alpha: .65),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: Text(
                      s.t('pending'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: s.t('reboot'),
                      onPressed: () => confirmReboot(context, controller),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ),
            SectionLabel(s.t('mount_engine')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconTile(
                          env.manager == 'Magisk'
                              ? Icons.auto_fix_high_rounded
                              : Icons.hub_outlined,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                env.manager == 'Magisk'
                                    ? 'Magic Mount'
                                    : 'Hybrid Mount',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.t(
                                  env.manager == 'Magisk'
                                      ? 'magic_desc'
                                      : 'hybrid_desc',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StatusPill(
                      s.t(engineActive ? 'mount_ready' : 'mount_needed'),
                      warning: !engineActive,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      env.manager == 'Magisk'
                          ? s.t('hybrid_magisk')
                          : !env.canSystemize
                          ? s.error(env.reason)
                          : '${env.hybridMode == 'overlay' ? 'OverlayFS' : 'Magic Mount'} · /system/app (🏦) + /system_ext/priv-app',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (env.manager == 'KernelSU' && !env.hybridReady)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: controller.openHybrid,
                          child: Text(s.t('hybrid_link')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ExpandingCard(
              title: s.t('migrate_banks'),
              icon: Icons.account_balance_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('migrate_banks_note'),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  if (controller.bankMigrations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: controller.busy || controller.refreshing
                          ? null
                          : () => confirmBankMigration(context, controller),
                      icon: const Icon(Icons.drive_file_move_rounded),
                      label: Text(
                        '${s.t('migrate_banks')} (${controller.bankMigrations.length})',
                      ),
                    ),
                  ] else
                    Text(
                      s.t('bank_layout_current'),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ExpandingCard(
              title: s.t('how'),
              icon: Icons.lightbulb_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 1; i <= 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 13, bottom: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.t('step_$i'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            s.t('step_${i}_desc'),
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 15),
                  Text(
                    s.t('data_note'),
                    style: TextStyle(
                      fontSize: 12,
                      color: c.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'MADE WITH ❤️ BY TNYFISHY 🇻🇳',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: c.onSurfaceVariant.withValues(alpha: .65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Statistic extends StatelessWidget {
  const _Statistic(this.value, this.label, this.icon);
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 36,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LeafArtwork extends StatelessWidget {
  const _LeafArtwork();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      width: 78,
      height: 105,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: .1),
              ),
            ),
          ),
          Transform.rotate(
            angle: .13,
            child: Container(
              width: 57,
              height: 91,
              decoration: BoxDecoration(
                color: c.surfaceContainerLow,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: c.primary.withValues(alpha: .4),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: .1),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 20,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.eco_rounded, color: c.primary, size: 32),
                  const Spacer(),
                  Container(
                    width: 18,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 3,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
                border: Border.all(color: c.primaryContainer, width: 3),
              ),
              child: Icon(Icons.check_rounded, size: 16, color: c.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
