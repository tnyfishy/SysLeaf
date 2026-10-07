import 'package:sysleaf/core/backend.dart';

// Test-only inventory. Production has no demo mode or root bypass.
class FakeBackend implements Backend {
  bool rootAllowed = true;
  bool failInstall = false;
  bool canSystemize = true;
  bool hybridReady = true;
  String reason = '';
  bool failManagement = false;
  final Set<String> failedPackages = {};
  Map<String, dynamic>? lastManagementArgs;
  final List<String> calls = [];
  Map<String, dynamic> preferences = {'language': 'vi', 'theme': 'light'};
  final List<Map<String, dynamic>> apps = [
    app('com.android.settings', 'Cài đặt Android', system: true),
    app('com.demo.notes', 'Leaf Notes', state: 'active', system: true),
    app('com.zing.zalo', 'Zalo', category: 'social'),
    app('com.mbmobile', 'MB Bank', category: 'banking'),
    app('com.instagram.android', 'Instagram', category: 'social'),
    app('org.telegram.messenger', 'Telegram', category: 'social'),
    app('com.vietcombank.vcbmobile', 'VCB Digibank', category: 'banking'),
    app('com.demo.music', 'Music'),
  ];
  static Map<String, dynamic> app(
    String package,
    String name, {
    String category = 'other',
    String state = '',
    bool system = false,
    bool enabled = true,
    bool installed = true,
    String target = '',
  }) => {
    'package': package,
    'name': name,
    'category': category,
    'module_state': state,
    'system': system,
    'enabled': enabled,
    'installed': installed,
    'module_target': target,
    'uid': 10001,
    'version': '1.0',
  };
  @override
  Future<dynamic> call(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    calls.add(action);
    switch (action) {
      case 'preferences':
        return preferences;
      case 'save_preferences':
        preferences = args['preferences'] as Map<String, dynamic>;
        return true;
      case 'probe':
        if (!rootAllowed) {
          throw const BackendException('ROOT_DENIED', 'Permission denied');
        }
        return {
          'root': true,
          'manager': 'KernelSU',
          'hybrid_installed': true,
          'hybrid_ready': hybridReady,
          'can_systemize': canSystemize,
          'reason': reason,
          'device': 'Pixel 8 Pro',
          'android_sdk': '35',
          'boot_id': 'BOOT_A',
          'hybrid_mode': 'overlay',
        };
      case 'apps':
        return apps;
      case 'icon':
        throw const BackendException(
          'TEST_NO_ICON',
          'Use category icon in tests',
        );
      case 'install':
        if (failInstall) {
          throw const BackendException('NO_SPACE', 'Insufficient storage');
        }
        for (final package in args['packages'] as List) {
          final app = apps.firstWhere((a) => a['package'] == package);
          app['module_state'] = 'pending';
          app['module_target'] = app['category'] == 'banking'
              ? '/system/app'
              : '/system_ext/priv-app';
        }
        return {'packages': args['packages'], 'reboot_required': true};
      case 'migrate_banks':
        for (final package in args['packages'] as List) {
          final app = apps.firstWhere((a) => a['package'] == package);
          app['module_target'] = '/system/app';
          app['module_state'] = app['module_state'] == 'disabled'
              ? 'disabled'
              : 'pending';
        }
        return {'packages': args['packages'], 'reboot_required': true};
      case 'remove':
        apps.firstWhere(
          (a) => a['package'] == args['package'],
        )['module_state'] = 'removing';
        return {
          'packages': [args['package']],
          'reboot_required': true,
        };
      case 'disable_apps':
      case 'uninstall_apps':
        lastManagementArgs = args;
        if (failManagement) {
          apps.firstWhere(
            (a) => a['package'] == (args['packages'] as List).first,
          )['enabled'] = false;
          throw const BackendException('TIMEOUT', 'Operation interrupted');
        }
        final results = <Map<String, dynamic>>[];
        for (final package in args['packages'] as List) {
          final success = !failedPackages.contains(package);
          if (success) {
            if (action == 'disable_apps') {
              apps.firstWhere((a) => a['package'] == package)['enabled'] =
                  false;
            } else {
              apps.firstWhere((a) => a['package'] == package)['installed'] =
                  false;
            }
          }
          results.add({
            'package': package,
            'success': success,
            'detail': success
                ? 'Success'
                : 'Failure [DELETE_FAILED_DEVICE_POLICY_MANAGER]',
          });
        }
        return {'user_id': 0, 'results': results};
      case 'reboot':
        return true;
      case 'open_hybrid':
        return true;
      default:
        throw UnsupportedError(action);
    }
  }
}
