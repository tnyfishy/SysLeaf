import 'package:sysleaf/core/backend.dart';

// Test-only inventory. Production has no demo mode or root bypass.
class FakeBackend implements Backend {
  bool rootAllowed = true;
  bool failInstall = false;
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
  }) => {
    'package': package,
    'name': name,
    'category': category,
    'module_state': state,
    'system': system,
    'enabled': true,
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
          'hybrid_ready': true,
          'can_systemize': true,
          'reason': '',
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
          apps.firstWhere((a) => a['package'] == package)['module_state'] =
              'pending';
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
      case 'reboot':
        return true;
      case 'open_hybrid':
        return true;
      default:
        throw UnsupportedError(action);
    }
  }
}
