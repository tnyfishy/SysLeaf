import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../l10n/strings.dart';
import 'apps_page.dart';
import 'dialogs.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'widgets.dart';
import 'country_flag.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int tab = 0;
  late final AnimationController transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    transition.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !widget.controller.loading &&
        widget.controller.rooted &&
        !widget.controller.busy &&
        !widget.controller.refreshing) {
      widget.controller.refresh();
    }
  }

  void selectTab(int value) {
    if (value == tab || widget.controller.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => tab = value);
    transition.duration = motion(context, 300);
    transition.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = Strings(controller.preferences.language);
    final c = Theme.of(context).colorScheme;
    final rooted = controller.rooted;
    final animation = CurvedAnimation(
      parent: transition,
      curve: Curves.easeOutCubic,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: c.surfaceContainerLow,
        systemNavigationBarIconBrightness: c.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        canPop: !controller.busy,
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                toolbarHeight: 80,
                titleSpacing: 22,
                title: Row(
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        size: 25,
                        color: c.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !rooted || tab == 0
                                ? 'SysLeaf'
                                : s.t(tab == 1 ? 'apps' : 'settings'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8,
                            ),
                          ),
                          if (tab == 0 || !rooted)
                            Text(
                              s.t('subtitle'),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: rooted
                    ? [
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: IconButton.filledTonal(
                            onPressed: controller.busy
                                ? null
                                : () => confirmReboot(context, controller),
                            tooltip: s.t('reboot'),
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                      ]
                    : null,
              ),
              body: SafeArea(
                top: false,
                bottom: !rooted,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: AnimatedSwitcher(
                      duration: motion(context, 320),
                      child: rooted
                          ? FadeTransition(
                              key: const ValueKey('rooted'),
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, .018),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: IndexedStack(
                                  index: tab,
                                  children: [
                                    HomePage(
                                      controller: controller,
                                      chooseApps: () => selectTab(1),
                                    ),
                                    AppsPage(controller: controller),
                                    SettingsPage(controller: controller),
                                  ],
                                ),
                              ),
                            )
                          : _RootGate(
                              key: const ValueKey('root-gate'),
                              controller: controller,
                              strings: s,
                            ),
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: rooted
                  ? NavigationBar(
                      selectedIndex: tab,
                      animationDuration: motion(context, 350),
                      onDestinationSelected: selectTab,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home_rounded),
                          label: s.t('home'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.apps_outlined),
                          selectedIcon: const Icon(Icons.apps_rounded),
                          label: s.t('apps'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.tune_rounded),
                          selectedIcon: const Icon(Icons.tune_rounded),
                          label: s.t('settings'),
                        ),
                      ],
                    )
                  : null,
            ),
            if (controller.busy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .42),
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(30),
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 24),
                                Text(
                                  s.t(switch (controller.operation) {
                                    'remove' => 'removing_work',
                                    'reboot' => 'rebooting',
                                    'disable_apps' => 'disabling_work',
                                    'uninstall_apps' => 'uninstalling_work',
                                    'migrate_banks' => 'migrating_banks',
                                    _ => 'installing',
                                  }),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  s.t(
                                    controller.operation == 'install'
                                        ? 'installing_desc'
                                        : 'busy_desc',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({super.key, required this.controller, required this.strings});
  final AppController controller;
  final Strings strings;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final working = controller.loading || controller.refreshing;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primaryContainer.withValues(alpha: .6),
              ),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 55,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              strings.t(working ? 'root_loading' : 'root_needed'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.t('root_needed_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: c.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (working)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.refresh,
                  icon: const Icon(Icons.key_rounded, size: 19),
                  label: Text(strings.t('grant_root')),
                ),
              ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: controller.saving
                      ? null
                      : () => controller.setPreferences(language: 'vi'),
                  icon: const CountryFlag('vi', width: 22),
                  label: const Text('Tiếng Việt'),
                ),
                const Text('·'),
                TextButton.icon(
                  onPressed: controller.saving
                      ? null
                      : () => controller.setPreferences(language: 'en'),
                  icon: const CountryFlag('en', width: 22),
                  label: const Text('English'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
