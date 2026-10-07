import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysleaf/core/controller.dart';
import 'package:sysleaf/core/models.dart';
import 'package:sysleaf/main.dart';
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
    await tester.tap(find.text('Systemize'));
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
    await tester.tap(find.text('Systemize'));
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
    expect(find.text('Your apps.\nPart of the system.'), findsOneWidget);
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
