import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../l10n/strings.dart';
import 'widgets.dart';

Future<T?> softDialog<T>(BuildContext context, Widget child) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .38),
      transitionDuration: motion(context, 260),
      pageBuilder: (context, animation, secondary) => SafeArea(child: child),
      transitionBuilder: (context, animation, secondary, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: .94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );

Future<void> showFailure(BuildContext context, AppController controller) async {
  final s = Strings(controller.preferences.language);
  await softDialog<void>(
    context,
    AlertDialog(
      icon: const Icon(Icons.error_outline_rounded),
      title: Text(s.t('error')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.error(controller.errorCode)),
            const SizedBox(height: 16),
            ExpandingCard(
              title: s.t('details'),
              icon: Icons.code_rounded,
              child: SelectableText(
                '${controller.errorCode ?? ''}\n${controller.errorDetail ?? ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('close')),
        ),
      ],
    ),
  );
}

Future<void> confirmReboot(
  BuildContext context,
  AppController controller,
) async {
  final s = Strings(controller.preferences.language);
  final accepted = await softDialog<bool>(
    context,
    AlertDialog(
      icon: const Icon(Icons.restart_alt_rounded),
      title: Text(s.t('reboot_question')),
      content: Text(s.t('reboot_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('reboot')),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  if (!await controller.reboot() && context.mounted) {
    await showFailure(context, controller);
  }
}

Future<void> confirmSystemize(
  BuildContext context,
  AppController controller,
) async {
  final s = Strings(controller.preferences.language);
  final apps = controller.selectedApps;
  if (apps.isEmpty) return;
  final accepted = await softDialog<bool>(
    context,
    AlertDialog(
      icon: const Icon(Icons.auto_awesome_rounded),
      title: Text(s.t('confirm_title')),
      content: SizedBox(
        width: 400,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .52,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('confirm_question')),
                const SizedBox(height: 18),
                for (final app in apps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        AppIcon(app: app, controller: controller, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                app.package,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  s.t('confirm_note'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('wait')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('yes')),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  final success = await controller.installSelected();
  if (!context.mounted) return;
  if (!success) {
    await showFailure(context, controller);
    return;
  }
  await showSuccess(context, controller);
}

Future<void> showSuccess(BuildContext context, AppController controller) async {
  final s = Strings(controller.preferences.language);
  final restart = await softDialog<bool>(
    context,
    AlertDialog(
      icon: Icon(
        Icons.check_circle_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 42,
      ),
      title: Text(s.t('success')),
      content: Text(s.t('success_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('later')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('reboot')),
        ),
      ],
    ),
  );
  if (restart == true && context.mounted) {
    await confirmReboot(context, controller);
  }
}

Future<void> confirmRemove(
  BuildContext context,
  AppController controller,
  InstalledApp app,
) async {
  final s = Strings(controller.preferences.language);
  final accepted = await softDialog<bool>(
    context,
    AlertDialog(
      icon: const Icon(Icons.layers_clear_rounded),
      title: Text('${s.t('remove')} · ${app.name}'),
      content: Text(s.t('remove_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('remove')),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  final success = await controller.removeModule(app);
  if (!context.mounted) return;
  if (!success) {
    await showFailure(context, controller);
    return;
  }
  await showSuccess(context, controller);
}

Future<void> confirmAppManagement(
  BuildContext context,
  AppController controller,
) async {
  final action = controller.appAction;
  if (action == AppAction.systemize) return;
  final apps = List<InstalledApp>.unmodifiable(controller.selectedApps);
  if (apps.isEmpty) return;
  final s = Strings(controller.preferences.language);
  final c = Theme.of(context).colorScheme;
  final accepted = await softDialog<bool>(
    context,
    AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: c.error, size: 36),
      title: Text(s.t('${action.name}_question')),
      content: SizedBox(
        width: 400,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .52,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('${action.name}_warning'),
                  style: TextStyle(color: c.error, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '${apps.length} ${s.t('selected')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final app in apps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        AppIcon(app: app, controller: controller, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                app.package,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                              if (app.systemized) ...[
                                const SizedBox(height: 4),
                                StatusPill(
                                  s.t(app.managed ? 'managed' : 'stock_system'),
                                  warning: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  s.t('${action.name}_note'),
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('danger_no')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.error,
            foregroundColor: c.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('danger_yes')),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  // Send exactly the immutable list shown in the warning, even if selection
  // changed while the dialog was open.
  final result = await controller.manageApps(action, apps);
  if (!context.mounted) return;
  if (result == null) {
    await showFailure(context, controller);
    return;
  }
  await softDialog<void>(
    context,
    AlertDialog(
      title: Text('${s.t(action.name)} · ${s.t('batch_title')}'),
      content: SizedBox(
        width: 400,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .52,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.succeeded}/${result.results.length} ${s.t('batch_succeeded')}',
                ),
                const SizedBox(height: 12),
                Text(s.t('batch_note'), style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                for (final outcome in result.results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          outcome.success
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: outcome.success ? c.primary : c.error,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                apps
                                    .firstWhere(
                                      (a) => a.package == outcome.package,
                                    )
                                    .name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                outcome.package,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                s.t(
                                  outcome.success
                                      ? 'batch_succeeded'
                                      : 'batch_failed',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: outcome.success ? c.primary : c.error,
                                ),
                              ),
                              if (!outcome.success) ...[
                                const SizedBox(height: 8),
                                SelectableText(
                                  outcome.detail,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('close')),
        ),
      ],
    ),
  );
}
