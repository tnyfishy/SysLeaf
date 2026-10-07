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
