import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend.dart';
import 'models.dart';

class AppController extends ChangeNotifier {
  AppController(this.backend);
  final Backend backend;
  Preferences preferences = const Preferences();
  DeviceEnvironment? environment;
  List<InstalledApp> apps = [];
  final Set<String> selected = {};
  AppAction appAction = AppAction.systemize;
  final Map<String, Future<Uint8List?>> _icons = {};
  bool loading = true, refreshing = false, busy = false, saving = false;
  String? errorCode, errorDetail;
  String operation = 'install';
  bool get rooted => environment?.root == true;
  int get pendingCount => apps.where((a) => a.pending).length;
  int get managedCount =>
      apps.where((a) => a.managed && a.moduleState != 'removing').length;
  int get eligibleCount => apps.where((a) => a.eligible).length;
  List<InstalledApp> get selectedApps =>
      apps.where((a) => selected.contains(a.package)).toList();

  Future<void> initialize() async {
    try {
      preferences = Preferences.fromJson(
        await backend.call('preferences') as Map<String, dynamic>,
      );
    } catch (_) {
      /* Keep the Vietnamese and system theme defaults. */
    }
    notifyListeners();
    await refresh();
    loading = false;
    notifyListeners();
  }

  void _error(Object error) {
    if (error is BackendException) {
      errorCode = error.code;
      errorDetail = error.message;
      if (error.code == 'ROOT_DENIED') {
        environment = null;
        selected.clear();
      }
    } else {
      errorCode = 'INTERNAL_ERROR';
      errorDetail = error.toString();
    }
  }

  Future<void> refresh() async {
    if (refreshing || busy) return;
    refreshing = true;
    errorCode = null;
    errorDetail = null;
    notifyListeners();
    try {
      environment = DeviceEnvironment.fromJson(
        await backend.call('probe') as Map<String, dynamic>,
      );
      notifyListeners();
      apps = (await backend.call('apps') as List)
          .map((a) => InstalledApp.fromJson(a as Map<String, dynamic>))
          .toList();
      selected.removeWhere(
        (package) => !apps.any(
          (a) => a.package == package && a.selectableFor(appAction),
        ),
      );
    } catch (error) {
      _error(error);
    }
    refreshing = false;
    notifyListeners();
  }

  void toggle(InstalledApp app) {
    if (!rooted || !app.selectableFor(appAction) || busy || refreshing) return;
    if (!selected.remove(app.package)) {
      if (selected.length >= 100) {
        errorCode = 'INVALID_SELECTION';
        notifyListeners();
        return;
      }
      selected.add(app.package);
    }
    notifyListeners();
  }

  void selectCategory(String category) {
    if (!rooted || busy || refreshing) return;
    for (final app in apps.where(
      (a) => a.selectableFor(appAction) && a.category == category,
    )) {
      if (selected.length == 100) break;
      selected.add(app.package);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (!busy) {
      selected.clear();
      notifyListeners();
    }
  }

  Future<bool> installSelected() async {
    if (appAction != AppAction.systemize ||
        busy ||
        selected.isEmpty ||
        environment?.canSystemize != true) {
      return false;
    }
    return _mutate('install', {'packages': selected.toList()}, clear: true);
  }

  Future<bool> removeModule(InstalledApp app) =>
      _mutate('remove', {'package': app.package});

  void setAppAction(AppAction action) {
    if (busy || refreshing || action == appAction) return;
    appAction = action;
    selected.clear();
    notifyListeners();
  }

  Future<BatchResult?> manageApps(
    AppAction action,
    List<InstalledApp> reviewed,
  ) async {
    if (action == AppAction.systemize ||
        busy ||
        refreshing ||
        !rooted ||
        reviewed.isEmpty) {
      return null;
    }
    final packages = reviewed.map((a) => a.package).toList();
    if (packages.length > 100 ||
        packages.toSet().length != packages.length ||
        packages.any(
          (p) => !apps.any((a) => a.package == p && a.selectableFor(action)),
        )) {
      errorCode = 'APP_CHANGED';
      errorDetail = null;
      notifyListeners();
      return null;
    }
    operation = '${action.name}_apps';
    busy = true;
    errorCode = null;
    errorDetail = null;
    notifyListeners();
    BatchResult? result;
    try {
      result = BatchResult.fromJson(
        await backend.call(operation, {'packages': packages})
            as Map<String, dynamic>,
      );
      selected.removeAll(
        result.results.where((r) => r.success).map((r) => r.package),
      );
    } catch (error) {
      _error(error);
    }
    busy = false;
    // A batch can partially succeed or time out. Refresh even after an error,
    // preserving that error separately so the user can inspect what happened.
    final failureCode = errorCode, failureDetail = errorDetail;
    await refresh();
    if (failureCode != null && errorCode == null) {
      errorCode = failureCode;
      errorDetail = failureDetail;
    }
    notifyListeners();
    return result;
  }

  Future<bool> _mutate(
    String action,
    Map<String, dynamic> args, {
    bool clear = false,
  }) async {
    if (busy || refreshing || !rooted) return false;
    operation = action;
    busy = true;
    errorCode = null;
    errorDetail = null;
    notifyListeners();
    bool success = false;
    try {
      await backend.call(action, args);
      if (clear) selected.clear();
      success = true;
    } catch (error) {
      _error(error);
    }
    busy = false;
    if (success) await refresh();
    notifyListeners();
    return success;
  }

  Future<bool> reboot() async {
    if (busy || !rooted) return false;
    operation = 'reboot';
    busy = true;
    notifyListeners();
    try {
      await backend.call('reboot');
      return true;
    } catch (error) {
      _error(error);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setPreferences({
    String? language,
    Appearance? appearance,
  }) async {
    if (saving) return;
    final previous = preferences;
    preferences = Preferences(
      language: language ?? previous.language,
      appearance: appearance ?? previous.appearance,
    );
    saving = true;
    notifyListeners();
    try {
      await backend.call('save_preferences', {
        'preferences': preferences.toJson(),
      });
    } catch (error) {
      preferences = previous;
      _error(error);
    }
    saving = false;
    notifyListeners();
  }

  Future<Uint8List?> icon(String package) =>
      _icons.putIfAbsent(package, () async {
        try {
          return base64Decode(
            await backend.call('icon', {'package': package}) as String,
          );
        } catch (_) {
          return null;
        }
      });
  Future<void> openHybrid() async {
    try {
      await backend.call('open_hybrid');
    } catch (error) {
      _error(error);
      notifyListeners();
    }
  }
}
