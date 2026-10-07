import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysleaf/core/controller.dart';
import 'package:sysleaf/core/models.dart';
import 'package:sysleaf/main.dart';
import 'package:sysleaf/l10n/strings.dart';
import 'support/fake_backend.dart';

Future<void> setup(
  WidgetTester tester,
  AppController controller, {
  Size size = const Size(390, 844),
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
  addTearDown(tester.view.reset);
  await controller.initialize();
  final app = SysLeafApp(controller: controller, initialize: false);
  await tester.pumpWidget(
    capture == null ? app : RepaintBoundary(key: capture, child: app),
  );
  await tester.pumpAndSettle();
}

Future<void> capturePreview(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('artifacts/screenshots')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final weight in [400, 500, 600, 700, 800]) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('root gate offers no app tabs on a non-rooted device', (
    tester,
  ) async {
    await setup(tester, AppController(FakeBackend()..rootAllowed = false));
    expect(find.text('Cần quyền superuser'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Systemize'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group selection requires confirmation; cancel never installs', (
    tester,
  ) async {
    final backend = FakeBackend();
    final controller = AppController(backend);
    await setup(tester, controller);
    await tester.tap(find.text('Ứng dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn theo nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngân hàng').last);
    await tester.pumpAndSettle();
    expect(controller.selected.length, 2);
    await tester.tap(find.byKey(const ValueKey('apply-selection')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bạn muốn chọn (những) ứng dụng dưới đây làm ứng dụng hệ thống?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Khoan đã😐'));
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('install')));
    await tester.tap(find.byKey(const ValueKey('apply-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vâng!😋'));
    await tester.pumpAndSettle();
    expect(backend.calls.where((a) => a == 'install').length, 1);
    expect(controller.pendingCount, 2);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reboot needs explicit confirmation', (tester) async {
    final backend = FakeBackend();
    await setup(tester, AppController(backend));
    await tester.tap(find.byTooltip('Khởi động lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('reboot')));
    await tester.tap(find.byTooltip('Khởi động lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khởi động lại'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('reboot'));
  });
  testWidgets('requested copy, active Hybrid link visibility and version 1.1', (
    tester,
  ) async {
    final controller = AppController(FakeBackend());
    await setup(tester, controller);
    expect(find.text('For your best experience😊'), findsOneWidget);
    expect(find.text('Cá nhân hóa trải nghiệm của bạn'), findsOneWidget);
    expect(find.text('SYSTEMIZE • READY TO USE 👾'), findsOneWidget);
    expect(find.text('MADE WITH ❤️ BY TNYFISHY 🇻🇳'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.text('Tải Hybrid Mount ↗'), findsNothing);
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Về SysLeaf'));
    await tester.tap(find.text('Về SysLeaf'));
    await tester.pumpAndSettle();
    expect(find.text('Phiên bản 1.1'), findsOneWidget);
    expect(find.text('Tải Hybrid Mount ↗'), findsNothing);
    expect(find.textContaining('Flutter + Rust'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Hybrid download link appears only when not ready', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..hybridReady = false
      ..canSystemize = false
      ..reason = 'HYBRID_REQUIRED';
    await setup(tester, AppController(backend));
    final link = find.text('Tải Hybrid Mount ↗');
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.tap(link);
    expect(backend.calls, contains('open_hybrid'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'action chips sit below search with no checkmark; sort statuses are separate',
    (tester) async {
      await setup(
        tester,
        AppController(FakeBackend()),
        size: const Size(320, 640),
      );
      await tester.tap(find.text('Ứng dụng'));
      await tester.pumpAndSettle();
      final mode = find.byKey(const ValueKey('mode-systemize'));
      expect(tester.widget<ChoiceChip>(mode).showCheckmark, false);
      expect(
        tester.getTopLeft(mode).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      await tester.tap(find.byTooltip('Sắp xếp'));
      await tester.pumpAndSettle();
      for (final label in [
        'Ứng dụng đã gỡ cài đặt',
        'Ứng dụng đã vô hiệu hoá',
        'Ứng dụng đã systemize',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'banking module migration reviews targets and cancellation preserves them',
    (tester) async {
      final backend = FakeBackend();
      final bank = backend.apps.firstWhere(
        (a) => a['package'] == 'com.mbmobile',
      );
      bank['module_state'] = 'active';
      bank['module_target'] = '/system_ext/priv-app';
      bank['system'] = true;
      final controller = AppController(backend);
      await setup(tester, controller);
      await tester.ensureVisible(find.text('Chuyển module ngân hàng'));
      await tester.tap(find.text('Chuyển module ngân hàng'));
      await tester.pumpAndSettle();
      final button = find.text('Chuyển module ngân hàng (1)');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('MB Bank'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Khoan đã😐'));
      await tester.pumpAndSettle();
      expect(backend.calls, isNot(contains('migrate_banks')));
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vâng!😋'));
      await tester.pumpAndSettle();
      expect(controller.bankMigrations, isEmpty);
      expect(controller.pendingCount, 1);
      expect(bank['module_target'], '/system/app');
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in [AppAction.disable, AppAction.uninstall]) {
    testWidgets(
      '${action.name} reviews multiple apps and requires explicit consent on a compact screen',
      (tester) async {
        final backend = FakeBackend();
        final controller = AppController(backend);
        final capture = GlobalKey();
        await setup(
          tester,
          controller,
          size: const Size(320, 640),
          capture: capture,
        );
        await tester.tap(find.text('Ứng dụng'));
        await tester.pumpAndSettle();
        final mode = find.byKey(ValueKey('mode-${action.name}'));
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cài đặt Android'));
        controller.toggle(
          controller.apps.firstWhere((a) => a.package == 'com.mbmobile'),
        );
        await tester.pumpAndSettle();
        expect(controller.selected.length, 2);
        await tester.tap(find.byKey(const ValueKey('apply-selection')));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text('com.android.settings'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text('com.mbmobile')),
          findsOneWidget,
        );
        expect(
          find.text(Strings('vi').t('${action.name}_warning')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capturePreview(tester, capture, '${action.name}_warning_vi');
        await tester.tap(find.text('Oh, chờ chút'));
        await tester.pumpAndSettle();
        expect(backend.calls, isNot(contains('${action.name}_apps')));
        expect(controller.selected.length, 2);
        await tester.tap(find.byKey(const ValueKey('apply-selection')));
        await tester.pumpAndSettle();
        // Changing the underlying selection must not silently change the list
        // accepted by the user in an already open warning.
        controller.toggle(
          controller.apps.firstWhere((a) => a.package == 'com.zing.zalo'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Được, cứ làm đi!'));
        await tester.pumpAndSettle();
        expect(backend.lastManagementArgs!['packages'], [
          'com.android.settings',
          'com.mbmobile',
        ]);
        expect(
          backend.calls.where((a) => a == '${action.name}_apps').length,
          1,
        );
        expect(find.text('2/2 thành công'), findsOneWidget);
        expect(controller.selected, {'com.zing.zalo'});
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('English uninstall warning reports partial failures', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..preferences = {'language': 'en', 'theme': 'dark'};
    backend.failedPackages.add('com.mbmobile');
    final controller = AppController(backend);
    await setup(tester, controller);
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    controller.setAppAction(AppAction.uninstall);
    controller.selectCategory('banking');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-selection')));
    await tester.pumpAndSettle();
    expect(find.text(Strings('en').t('uninstall_warning')), findsOneWidget);
    expect(find.text('Oh, wait a moment'), findsOneWidget);
    await tester.tap(find.text('Yes, go ahead!'));
    await tester.pumpAndSettle();
    expect(find.text('1/2 succeeded'), findsOneWidget);
    expect(
      find.text('Failure [DELETE_FAILED_DEVICE_POLICY_MANAGER]'),
      findsOneWidget,
    );
    expect(controller.selected, {'com.mbmobile'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('language and pure black theme persist across tabs', (
    tester,
  ) async {
    final backend = FakeBackend();
    final controller = AppController(backend);
    await setup(tester, controller);
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đen tuyền'));
    await tester.pumpAndSettle();
    expect(controller.preferences.appearance, Appearance.black);
    expect(
      Theme.of(tester.element(find.text('Đen tuyền'))).scaffoldBackgroundColor,
      Colors.black,
    );
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(backend.preferences, {'language': 'en', 'theme': 'black'});
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Personalize your experience'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screens stay within a compact display and cutout insets', (
    tester,
  ) async {
    await setup(
      tester,
      AppController(FakeBackend()),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ứng dụng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bar = tester.getTopLeft(find.byType(AppBar));
    expect(bar.dy, greaterThanOrEqualTo(0));
  });

  testWidgets('render preview artifacts from real Flutter widgets', (
    tester,
  ) async {
    final key = GlobalKey();
    final controller = AppController(FakeBackend());
    await setup(tester, controller, capture: key);
    await capturePreview(tester, key, 'home_vi');
    await tester.tap(find.text('Ứng dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB Bank'));
    await tester.pumpAndSettle();
    await capturePreview(tester, key, 'apps_vi');
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await capturePreview(tester, key, 'settings_vi');
    await controller.setPreferences(
      language: 'en',
      appearance: Appearance.black,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await capturePreview(tester, key, 'home_en_black');
    expect(tester.takeException(), isNull);
  });
}
