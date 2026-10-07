import 'package:flutter_test/flutter_test.dart';
import 'package:sysleaf/core/controller.dart';
import 'package:sysleaf/core/models.dart';
import 'support/fake_backend.dart';

void main() {
  test('root denial stops enumeration and every systemize action', () async {
    final backend = FakeBackend()..rootAllowed = false;
    final controller = AppController(backend);
    await controller.initialize();
    expect(controller.rooted, false);
    expect(controller.errorCode, 'ROOT_DENIED');
    expect(backend.calls, isNot(contains('apps')));
    expect(await controller.installSelected(), false);
    expect(await controller.reboot(), false);
    expect(backend.calls, isNot(contains('install')));
    expect(backend.calls, isNot(contains('reboot')));
  });
  test(
    'category selection excludes existing system apps and preserves a failed selection',
    () async {
      final backend = FakeBackend();
      backend.apps.add(
        FakeBackend.app(
          'com.stock.bank',
          'Stock Bank',
          category: 'banking',
          system: true,
        ),
      );
      final controller = AppController(backend);
      await controller.initialize();
      controller.selectCategory('banking');
      expect(controller.selected, {
        'com.mbmobile',
        'com.vietcombank.vcbmobile',
      });
      backend.failInstall = true;
      expect(await controller.installSelected(), false);
      expect(controller.errorCode, 'NO_SPACE');
      expect(controller.selected.length, 2);
      backend.failInstall = false;
      expect(await controller.installSelected(), true);
      expect(controller.selected, isEmpty);
      expect(
        controller.apps.where((a) => a.moduleState == 'pending').length,
        2,
      );
      expect(
        controller.apps
            .where((a) => a.moduleState == 'pending')
            .every((a) => !a.system),
        true,
      );
    },
  );
  test('system apps stay pinned under all sorts and package search works', () {
    final apps = FakeBackend().apps.map(InstalledApp.fromJson).toList();
    for (final sort in AppSort.values) {
      final sorted = arrangeApps(apps, sort: sort);
      expect(sorted.first.package, 'com.demo.notes');
      final firstUser = sorted.indexWhere((a) => !a.systemized);
      expect(sorted.take(firstUser).every((a) => a.systemized), true);
      expect(sorted.skip(firstUser).every((a) => !a.systemized), true);
    }
    expect(arrangeApps(apps, query: 'com.mbmobile').single.name, 'MB Bank');
    expect(arrangeApps(apps, filter: AppFilter.banking).length, 2);
  });
  test('revoked root locks the app and clears selected packages', () async {
    final backend = FakeBackend();
    final controller = AppController(backend);
    await controller.initialize();
    controller.selectCategory('social');
    backend.rootAllowed = false;
    await controller.refresh();
    expect(controller.rooted, false);
    expect(controller.selected, isEmpty);
  });
  test(
    'management includes system apps and clears selection on mode change',
    () async {
      final controller = AppController(FakeBackend());
      await controller.initialize();
      controller.selectCategory('banking');
      controller.setAppAction(AppAction.disable);
      expect(controller.selected, isEmpty);
      final system = controller.apps.firstWhere(
        (a) => a.package == 'com.android.settings',
      );
      controller.toggle(system);
      expect(controller.selected, {'com.android.settings'});
      expect(await controller.installSelected(), false);
      controller.setAppAction(AppAction.uninstall);
      expect(controller.selected, isEmpty);
      final self = InstalledApp.fromJson(
        FakeBackend.app('dev.sysleaf.sysleaf', 'SysLeaf'),
      );
      controller.toggle(self);
      expect(controller.selected, isEmpty);
    },
  );
  test('root is required for disabling and uninstalling', () async {
    final backend = FakeBackend()..rootAllowed = false;
    final controller = AppController(backend);
    await controller.initialize();
    final apps = [InstalledApp.fromJson(backend.apps.first)];
    for (final action in [AppAction.disable, AppAction.uninstall]) {
      expect(await controller.manageApps(action, apps), isNull);
    }
    expect(backend.calls, isNot(contains('disable_apps')));
    expect(backend.calls, isNot(contains('uninstall_apps')));
  });
  test(
    'partial failures stay selected and management needs no mount engine',
    () async {
      final backend = FakeBackend()..canSystemize = false;
      backend.failedPackages.add('com.mbmobile');
      final controller = AppController(backend);
      await controller.initialize();
      controller.setAppAction(AppAction.disable);
      controller.selectCategory('banking');
      final result = await controller.manageApps(
        AppAction.disable,
        controller.selectedApps,
      );
      expect(result!.succeeded, 1);
      expect(controller.selected, {'com.mbmobile'});
      expect(
        controller.apps
            .firstWhere((a) => a.package == 'com.vietcombank.vcbmobile')
            .enabled,
        false,
      );
      controller.setAppAction(AppAction.uninstall);
      final disabled = controller.apps.firstWhere(
        (a) => a.package == 'com.vietcombank.vcbmobile',
      );
      controller.toggle(disabled);
      expect(
        (await controller.manageApps(
          AppAction.uninstall,
          controller.selectedApps,
        ))!.succeeded,
        1,
      );
      expect(controller.apps.any((a) => a.package == disabled.package), false);
      expect(controller.selected, isEmpty);
    },
  );
  test(
    'timeout refreshes partially changed state and keeps the error visible',
    () async {
      final backend = FakeBackend()..failManagement = true;
      final controller = AppController(backend);
      await controller.initialize();
      controller.setAppAction(AppAction.disable);
      controller.selectCategory('banking');
      expect(
        await controller.manageApps(AppAction.disable, controller.selectedApps),
        isNull,
      );
      expect(controller.errorCode, 'TIMEOUT');
      expect(
        controller.apps.firstWhere((a) => a.package == 'com.mbmobile').enabled,
        false,
      );
      expect(controller.selected, {'com.vietcombank.vcbmobile'});
      expect(controller.busy, false);
    },
  );
  test(
    'defaults are Vietnamese and follow system, invalid preferences recover',
    () {
      expect(const Preferences().language, 'vi');
      expect(const Preferences().appearance, Appearance.system);
      expect(
        Preferences.fromJson({'language': 'xx', 'theme': 'xx'}).appearance,
        Appearance.system,
      );
    },
  );
}
