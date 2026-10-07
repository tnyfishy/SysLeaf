import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/backend.dart';
import 'core/controller.dart';
import 'core/models.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SysLeafApp(controller: AppController(RustBackend())));
}

class SysLeafApp extends StatefulWidget {
  const SysLeafApp({
    super.key,
    required this.controller,
    this.initialize = true,
  });
  final AppController controller;
  final bool initialize;
  @override
  State<SysLeafApp> createState() => _SysLeafAppState();
}

class _SysLeafAppState extends State<SysLeafApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialize) widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final prefs = widget.controller.preferences;
      return MaterialApp(
        title: 'SysLeaf',
        debugShowCheckedModeBanner: false,
        locale: Locale(prefs.language),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        darkTheme: buildTheme(
          dark: true,
          black: prefs.appearance == Appearance.black,
        ),
        themeMode: switch (prefs.appearance) {
          Appearance.system => ThemeMode.system,
          Appearance.light => ThemeMode.light,
          Appearance.dark || Appearance.black => ThemeMode.dark,
        },
        themeAnimationDuration: const Duration(milliseconds: 350),
        themeAnimationCurve: Curves.easeInOutCubic,
        home: AppShell(controller: widget.controller),
      );
    },
  );
}
