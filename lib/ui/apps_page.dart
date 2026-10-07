import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../l10n/strings.dart';
import 'dialogs.dart';
import 'widgets.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  AppFilter filter = AppFilter.all;
  AppSort sort = AppSort.name;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = Strings(controller.preferences.language);
    final c = Theme.of(context).colorScheme;
    final list = arrangeApps(
      controller.apps,
      filter: filter,
      sort: sort,
      query: query,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: s.t('search'),
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.refreshing
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: controller.refresh,
                      tooltip: s.t('refresh'),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              for (final option in AppFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: filter == option,
                    showCheckmark: false,
                    avatar: option == AppFilter.banking
                        ? const Text('🏦', style: TextStyle(fontSize: 15))
                        : Icon(switch (option) {
                            AppFilter.all => Icons.apps_rounded,
                            AppFilter.systemized => Icons.verified_outlined,
                            AppFilter.social => Icons.forum_outlined,
                            AppFilter.banking => Icons.account_balance_outlined,
                          }, size: 16),
                    label: Text(
                      s.t(
                        option == AppFilter.systemized
                            ? 'systemized'
                            : option.name,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onSelected: (_) => setState(() => filter = option),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 14, 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${list.length} ${s.t('apps').toLowerCase()}',
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: controller.busy ? null : _groups,
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: Text(
                  s.t('presets'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              PopupMenuButton<AppSort>(
                tooltip: s.t('sort'),
                initialValue: sort,
                icon: const Icon(Icons.sort_rounded, size: 22),
                onSelected: (value) => setState(() => sort = value),
                itemBuilder: (context) => [
                  for (final option in AppSort.values)
                    PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          option == AppSort.banking
                              ? const Text('🏦', style: TextStyle(fontSize: 20))
                              : Icon(switch (option) {
                                  AppSort.name => Icons.sort_by_alpha_rounded,
                                  AppSort.systemized => Icons.verified_outlined,
                                  AppSort.social => Icons.forum_outlined,
                                  AppSort.banking =>
                                    Icons.account_balance_outlined,
                                }, size: 20),
                          const SizedBox(width: 12),
                          Text(s.t('by_${option.name}')),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (controller.errorCode != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: ErrorCard(code: controller.errorCode!, strings: s),
          ),
        if (controller.environment?.canSystemize == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: ErrorCard(code: controller.environment!.reason, strings: s),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: controller.refreshing && controller.apps.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text(s.t('loading_apps'))),
                      ),
                    ],
                  )
                : list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [EmptyState(strings: s)],
                  )
                : ListView.builder(
                    key: const PageStorageKey('apps-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _AppRow(
                      app: list[index],
                      controller: controller,
                      strings: s,
                      selected: controller.selected.contains(
                        list[index].package,
                      ),
                    ),
                  ),
          ),
        ),
        AnimatedSize(
          duration: motion(context, 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.bottomCenter,
          child: controller.selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  decoration: BoxDecoration(
                    color: c.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: c.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${controller.selected.length} ${s.t('selected')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: controller.clearSelection,
                            child: Text(s.t('clear')),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              controller.environment?.canSystemize == true &&
                                  !controller.busy &&
                                  !controller.refreshing
                              ? () => confirmSystemize(context, controller)
                              : null,
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: Text(s.t('systemize')),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _groups() {
    final controller = widget.controller;
    final s = Strings(controller.preferences.language);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('select_group'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.t('preset_desc'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              for (final category in ['social', 'banking'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(
                    builder: (context) {
                      final count = controller.apps
                          .where((a) => a.eligible && a.category == category)
                          .length;
                      return Card(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          enabled: count > 0,
                          leading: Text(
                            category == 'banking' ? '🏦' : '💬',
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            s.t(category),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '$count ${s.t('group_detected')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                          ),
                          onTap: count == 0
                              ? null
                              : () {
                                  controller.selectCategory(category);
                                  Navigator.pop(sheetContext);
                                },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.controller,
    required this.strings,
    required this.selected,
  });
  final InstalledApp app;
  final AppController controller;
  final Strings strings;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final status = app.managed
        ? app.moduleState
        : app.system
        ? 'stock_system'
        : !app.enabled
        ? 'not_enabled'
        : '';
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: motion(context, 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected
              ? c.primaryContainer.withValues(alpha: .45)
              : c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? c.primary.withValues(alpha: .5)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: app.eligible ? () => controller.toggle(app) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 6, 13),
              child: Row(
                children: [
                  AppIcon(app: app, controller: controller),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.package,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        if (status.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          StatusPill(
                            strings.t(status),
                            warning: app.pending || status == 'mount_failed',
                            neutral: !app.managed,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  if (app.eligible)
                    Checkbox(
                      value: selected,
                      onChanged: controller.busy
                          ? null
                          : (_) => controller.toggle(app),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                  else if (app.managed && app.moduleState != 'removing')
                    PopupMenuButton<String>(
                      tooltip: strings.t('remove'),
                      icon: const Icon(Icons.more_vert_rounded, size: 21),
                      enabled: !controller.busy && !controller.refreshing,
                      onSelected: (_) =>
                          confirmRemove(context, controller, app),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.layers_clear_outlined, size: 20),
                              const SizedBox(width: 10),
                              Text(strings.t('remove')),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        app.system
                            ? Icons.shield_outlined
                            : Icons.lock_outline_rounded,
                        size: 17,
                        color: c.outline,
                      ),
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
