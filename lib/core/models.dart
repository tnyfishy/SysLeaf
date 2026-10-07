enum AppFilter { all, systemized, social, banking, disabled, uninstalled }

enum AppSort { name, systemized, disabled, uninstalled, social, banking }

enum Appearance { system, light, dark, black }

enum AppAction { systemize, disable, uninstall }

class AppOutcome {
  const AppOutcome({
    required this.package,
    required this.success,
    required this.detail,
  });
  final String package, detail;
  final bool success;
  factory AppOutcome.fromJson(Map<String, dynamic> json) => AppOutcome(
    package: json['package'] as String,
    success: json['success'] == true,
    detail: json['detail'] as String? ?? '',
  );
}

class BatchResult {
  const BatchResult(this.results);
  final List<AppOutcome> results;
  int get succeeded => results.where((r) => r.success).length;
  factory BatchResult.fromJson(Map<String, dynamic> json) => BatchResult(
    (json['results'] as List)
        .map((r) => AppOutcome.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

class Preferences {
  const Preferences({
    this.language = 'vi',
    this.appearance = Appearance.system,
  });
  final String language;
  final Appearance appearance;
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    language: json['language'] == 'en' ? 'en' : 'vi',
    appearance: Appearance.values.firstWhere(
      (e) => e.name == json['theme'],
      orElse: () => Appearance.system,
    ),
  );
  Map<String, dynamic> toJson() => {
    'language': language,
    'theme': appearance.name,
  };
}

class DeviceEnvironment {
  const DeviceEnvironment({
    required this.root,
    required this.manager,
    required this.hybridInstalled,
    required this.hybridReady,
    required this.canSystemize,
    required this.reason,
    required this.device,
    required this.androidSdk,
    required this.bootId,
    this.hybridMode = '',
  });
  final bool root, hybridInstalled, hybridReady, canSystemize;
  final String manager, reason, device, androidSdk, bootId, hybridMode;
  factory DeviceEnvironment.fromJson(Map<String, dynamic> json) =>
      DeviceEnvironment(
        root: json['root'] == true,
        manager: json['manager'] as String? ?? 'unsupported',
        hybridInstalled: json['hybrid_installed'] == true,
        hybridReady: json['hybrid_ready'] == true,
        canSystemize: json['can_systemize'] == true,
        reason: json['reason'] as String? ?? '',
        device: json['device'] as String? ?? '',
        androidSdk: json['android_sdk'] as String? ?? '',
        bootId: json['boot_id'] as String? ?? '',
        hybridMode: json['hybrid_mode'] as String? ?? '',
      );
}

class InstalledApp {
  const InstalledApp({
    required this.package,
    required this.name,
    required this.system,
    required this.enabled,
    required this.category,
    required this.moduleState,
    this.version = '',
    this.uid = 10000,
    this.categoryReason = 'unknown',
    this.installed = true,
    this.moduleTarget = '',
  });
  final String package, name, category, moduleState, version, categoryReason;
  final bool system, enabled, installed;
  final String moduleTarget;
  String get target =>
      category == 'banking' ? '/system/app' : '/system_ext/priv-app';
  bool get needsBankMigration =>
      category == 'banking' &&
      managed &&
      moduleState != 'removing' &&
      moduleTarget == '/system_ext/priv-app';
  final int uid;
  bool get managed => moduleState.isNotEmpty;
  bool get systemized => system || managed;
  bool get eligible =>
      installed &&
      !system &&
      !managed &&
      enabled &&
      uid ~/ 100000 == 0 &&
      package != 'dev.sysleaf.sysleaf';
  bool get pending => moduleState == 'pending' || moduleState == 'removing';
  bool selectableFor(AppAction action) => switch (action) {
    AppAction.systemize => eligible,
    AppAction.disable => manageable && enabled,
    AppAction.uninstall => manageable,
  };
  bool get manageable =>
      installed &&
      uid ~/ 100000 == 0 &&
      package != 'android' &&
      package != 'dev.sysleaf.sysleaf';
  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
    package: json['package'] as String,
    name: json['name'] as String,
    system: json['system'] == true,
    enabled: json['enabled'] == true,
    category: json['category'] as String? ?? 'other',
    moduleState: json['module_state'] as String? ?? '',
    version: json['version'] as String? ?? '',
    uid: json['uid'] as int? ?? 10000,
    categoryReason: json['category_reason'] as String? ?? 'unknown',
    installed: json['installed'] != false,
    moduleTarget: json['module_target'] as String? ?? '',
  );
}

List<InstalledApp> arrangeApps(
  Iterable<InstalledApp> apps, {
  AppFilter filter = AppFilter.all,
  AppSort sort = AppSort.name,
  String query = '',
}) {
  final text = query.toLowerCase().trim();
  final list = apps.where((app) {
    final matches = switch (filter) {
      AppFilter.all => app.installed || sort == AppSort.uninstalled,
      AppFilter.systemized => app.systemized,
      AppFilter.social => app.category == 'social',
      AppFilter.banking => app.category == 'banking',
      AppFilter.disabled => app.installed && !app.enabled,
      AppFilter.uninstalled => !app.installed,
    };
    return matches &&
        (text.isEmpty ||
            app.name.toLowerCase().contains(text) ||
            app.package.toLowerCase().contains(text));
  }).toList();
  int rank(InstalledApp app) => switch (sort) {
    AppSort.name => 0,
    AppSort.systemized => app.managed ? 0 : 1,
    AppSort.disabled => app.installed && !app.enabled ? 0 : 1,
    AppSort.uninstalled => !app.installed ? 0 : 1,
    AppSort.social => app.category == 'social' ? 0 : 1,
    AppSort.banking => app.category == 'banking' ? 0 : 1,
  };
  list.sort((a, b) {
    if (sort == AppSort.disabled || sort == AppSort.uninstalled) {
      final status = rank(a).compareTo(rank(b));
      if (status != 0) return status;
    }
    int pin(InstalledApp app) => app.managed
        ? 0
        : app.system
        ? 1
        : 2;
    final pinned = pin(a).compareTo(pin(b));
    if (pinned != 0) return pinned;
    final group = rank(a).compareTo(rank(b));
    if (group != 0) return group;
    final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return name != 0 ? name : a.package.compareTo(b.package);
  });
  return list;
}
