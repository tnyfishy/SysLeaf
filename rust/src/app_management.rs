use crate::error::{CoreError, Result};
use crate::model::{AppInfo, APP_ID};
use crate::modules::validate_package;
use crate::root::{self, quote};
use base64::Engine;
use serde::Serialize;
use std::collections::BTreeSet;
use std::time::Duration;

#[derive(Clone, Copy)]
pub enum Action {
    Disable,
    Uninstall,
}

impl Action {
    fn command(self) -> &'static str {
        match self {
            Self::Disable => "disable-user",
            Self::Uninstall => "uninstall",
        }
    }
}

#[derive(Debug, Serialize)]
pub struct AppOutcome {
    pub package: String,
    pub success: bool,
    pub detail: String,
}

#[derive(Debug, Serialize)]
pub struct BatchResult {
    pub user_id: u32,
    pub results: Vec<AppOutcome>,
}

fn validate_selection(packages: &[String], apps: &[AppInfo], action: Action) -> Result<()> {
    if packages.is_empty() || packages.len() > 100 {
        return Err(CoreError::new(
            "INVALID_SELECTION",
            "Select between 1 and 100 apps.",
        ));
    }
    let mut seen = BTreeSet::new();
    for package in packages {
        validate_package(package)?;
        if !seen.insert(package) {
            return Err(CoreError::new("INVALID_SELECTION", "Duplicate package."));
        }
        let app = apps
            .iter()
            .find(|a| &a.package == package)
            .ok_or_else(|| CoreError::new("APP_CHANGED", "Refresh the installed app list."))?;
        if package == APP_ID || !app.installed || app.uid / 100000 != 0 {
            return Err(CoreError::new(
                "APP_NOT_ELIGIBLE",
                "SysLeaf and other profiles cannot be changed.",
            ));
        }
        if matches!(action, Action::Disable) && !app.enabled {
            return Err(CoreError::new(
                "APP_CHANGED",
                "An app is already disabled. Refresh the list.",
            ));
        }
    }
    Ok(())
}

fn script(packages: &[String], action: Action, lock: &str) -> String {
    // Both the JNI inventory and these commands target owner user 0. There is
    // no all-users uninstall and no deletion of APKs or module directories.
    let mut script = format!(
        r#"set -eu
lock={lock}
mkdir "$lock" 2>/dev/null || {{ echo SYSLEAF_ERROR:OPERATION_BUSY >&2; exit 1; }}
trap 'rmdir "$lock"' EXIT
trap 'exit 1' HUP INT TERM
installed() {{ listing=$(pm list packages --user 0 "$1" 2>&1) || return 2; printf '%s\n' "$listing" | grep -Fxq "package:$1"; }}
disabled() {{ listing=$(pm list packages -d --user 0 "$1" 2>&1) || return 2; printf '%s\n' "$listing" | grep -Fxq "package:$1"; }}
uninstalled() {{ if installed "$1"; then return 1; else status=$?; [ "$status" = 1 ]; fi; }}
"#,
        lock = quote(lock)
    );
    // Check every package before the first mutation, then recheck per package
    // to catch an uninstall by another app while this batch is running.
    for package in packages {
        script.push_str(&format!(
            "installed {} || {{ echo SYSLEAF_ERROR:APP_CHANGED >&2; exit 1; }}\n",
            quote(package)
        ));
    }
    for package in packages {
        let verify = match action {
            Action::Disable => "disabled \"$package\"",
            Action::Uninstall => "uninstalled \"$package\"",
        };
        let success = match action {
            Action::Disable => "true",
            Action::Uninstall => "printf '%s\\n' \"$output\" | grep -Fxq Success",
        };
        script.push_str(&format!(
            r#"package={package}
ok=false
output='Package is no longer installed for user 0.'
if installed "$package"; then
  if output=$(pm {command} --user 0 "$package" 2>&1); then
    if {success} && {verify}; then ok=true
    else output="$output
PackageManager did not confirm the requested state."; fi
  fi
fi
detail=$(printf '%s' "$output" | head -c 4096 | base64 | tr -d '\n\r')
printf 'SYSLEAF_RESULT\t%s\t%s\t%s\n' "$package" "$ok" "$detail"
"#,
            package = quote(package),
            command = action.command()
        ));
    }
    script
}

fn parse_results(output: &str, packages: &[String]) -> Result<BatchResult> {
    let mut results = Vec::new();
    for line in output
        .lines()
        .filter_map(|l| l.strip_prefix("SYSLEAF_RESULT\t"))
    {
        let parts: Vec<_> = line.splitn(3, '\t').collect();
        if parts.len() != 3 || !["true", "false"].contains(&parts[1]) {
            return Err(CoreError::new(
                "INVALID_RESULT",
                "Malformed PackageManager response.",
            ));
        }
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(parts[2])
            .map_err(|e| CoreError::new("INVALID_RESULT", e.to_string()))?;
        results.push(AppOutcome {
            package: parts[0].into(),
            success: parts[1] == "true",
            detail: String::from_utf8_lossy(&bytes).into_owned(),
        });
    }
    if results.iter().map(|r| &r.package).ne(packages.iter()) {
        return Err(CoreError::new(
            "INVALID_RESULT",
            "Incomplete batch results. Refresh the installed app list.",
        ));
    }
    Ok(BatchResult {
        user_id: 0,
        results,
    })
}

pub fn apply(packages: &[String], action: Action) -> Result<BatchResult> {
    root::require_root()?;
    // Read fresh Android metadata rather than trusting labels/flags from Dart.
    let apps = crate::platform::apps()?;
    validate_selection(packages, &apps, action)?;
    let output = root::run(
        &script(packages, action, "/data/adb/.sysleaf-lock"),
        Duration::from_secs(600),
    )?;
    parse_results(&output, packages)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    use std::process::Command;

    fn fixture(package: &str) -> AppInfo {
        AppInfo {
            package: package.into(),
            name: package.into(),
            source: "/system/app/base.apk".into(),
            splits: vec![],
            native_lib: String::new(),
            system: true,
            enabled: true,
            installed: true,
            category: "other".into(),
            category_reason: String::new(),
            privileged_permissions: vec![],
            uid: 1000,
            version: String::new(),
            module_state: String::new(),
            module_target: String::new(),
            icon: None,
        }
    }

    fn harness(
        packages: &[String],
        action: Action,
        missing: bool,
        locked: bool,
    ) -> (std::process::Output, Vec<String>) {
        let temp = tempfile::tempdir().unwrap();
        let dir = temp.path();
        for package in packages {
            if !(missing && package.ends_with("missing")) {
                std::fs::write(dir.join(package), "installed").unwrap();
            }
        }
        let pm = dir.join("pm");
        std::fs::write(
            &pm,
            r#"#!/bin/sh
case "$1" in
list)
  disabled=false
  shift 2
  if [ "$1" = -d ]; then disabled=true; shift; fi
  [ "$1" = --user ] && [ "$2" = 0 ] || exit 90
  package=$3
  [ ! -f "$SYSLEAF_PM_STATE/verify-error" ] || exit 3
  if [ -f "$SYSLEAF_PM_STATE/$package" ]; then
    if [ "$disabled" = false ] || [ "$(cat "$SYSLEAF_PM_STATE/$package")" = disabled ]; then
      printf 'package:%s\n' "$package"
    fi
  fi
  ;;
disable-user|uninstall)
  action=$1
  [ "$2" = --user ] && [ "$3" = 0 ] || exit 91
  package=$4
  printf '%s\n' "$package" >> "$SYSLEAF_PM_STATE/calls"
  case "$package" in
    *.blocked) printf 'Failure [POLICY]\nsecond line\n'; exit 0 ;;
    *.error) printf 'Permission denied\n' >&2; exit 1 ;;
    *.lying) printf 'Success\n'; exit 0 ;;
    *.verify_error) touch "$SYSLEAF_PM_STATE/verify-error" ;;
  esac
  if [ "$action" = disable-user ]; then
    printf disabled > "$SYSLEAF_PM_STATE/$package"
    printf 'new state: disabled-user\n'
  else
    rm "$SYSLEAF_PM_STATE/$package"
    printf 'Success\n'
  fi
  ;;
*) exit 92 ;;
esac
"#,
        )
        .unwrap();
        std::fs::set_permissions(pm, std::fs::Permissions::from_mode(0o755)).unwrap();
        let lock = dir.join("lock");
        if locked {
            std::fs::create_dir(&lock).unwrap();
        }
        let out = Command::new("sh")
            .args(["-c", &script(packages, action, lock.to_str().unwrap())])
            .env(
                "PATH",
                format!("{}:{}", dir.display(), std::env::var("PATH").unwrap()),
            )
            .env("SYSLEAF_PM_STATE", dir)
            .output()
            .unwrap();
        let calls = std::fs::read_to_string(dir.join("calls"))
            .unwrap_or_default()
            .lines()
            .map(String::from)
            .collect();
        assert_eq!(
            lock.exists(),
            locked,
            "lock cleanup must run on success and failure"
        );
        (out, calls)
    }

    #[test]
    fn fresh_selection_accepts_system_apps_but_rejects_invalid_targets() {
        let mut apps = vec![
            fixture("com.system.app"),
            fixture(APP_ID),
            fixture("com.profile.app"),
        ];
        apps[2].uid = 110001;
        assert!(validate_selection(&["com.system.app".into()], &apps, Action::Disable).is_ok());
        for selection in [
            vec![],
            vec![APP_ID.into()],
            vec!["com.profile.app".into()],
            vec!["com.not.installed".into()],
            vec!["com.system.app".into(); 2],
            vec!["com.a;reboot".into()],
            vec!["com.system.app".into(); 101],
        ] {
            assert!(validate_selection(&selection, &apps, Action::Uninstall).is_err());
        }
        apps[0].enabled = false;
        assert!(validate_selection(&["com.system.app".into()], &apps, Action::Disable).is_err());
        assert!(validate_selection(&["com.system.app".into()], &apps, Action::Uninstall).is_ok());
    }

    #[test]
    fn batch_continues_after_failures_and_checks_real_state() {
        let packages: Vec<_> = [
            "com.test.good",
            "com.test.blocked",
            "com.test.error",
            "com.test.lying",
            "com.test.last",
        ]
        .into_iter()
        .map(String::from)
        .collect();
        for action in [Action::Disable, Action::Uninstall] {
            let (out, calls) = harness(&packages, action, false, false);
            assert!(
                out.status.success(),
                "{}",
                String::from_utf8_lossy(&out.stderr)
            );
            assert_eq!(calls, packages);
            let result = parse_results(&String::from_utf8(out.stdout).unwrap(), &packages).unwrap();
            assert_eq!(
                result.results.iter().map(|r| r.success).collect::<Vec<_>>(),
                vec![true, false, false, false, true]
            );
            assert!(result.results[1].detail.contains("second line"));
            assert!(result.results[2].detail.contains("Permission denied"));
        }
    }

    #[test]
    fn package_listing_errors_are_never_reported_as_success() {
        let packages = vec!["com.test.verify_error".into()];
        let (out, _) = harness(&packages, Action::Uninstall, false, false);
        assert!(out.status.success());
        assert!(
            !parse_results(&String::from_utf8(out.stdout).unwrap(), &packages)
                .unwrap()
                .results[0]
                .success
        );
    }

    #[test]
    fn preflight_and_shared_lock_prevent_any_mutation() {
        let packages = vec!["com.test.good".into(), "com.test.missing".into()];
        for (missing, locked) in [(true, false), (false, true)] {
            let (out, calls) = harness(&packages, Action::Disable, missing, locked);
            assert!(!out.status.success());
            assert!(calls.is_empty());
        }
    }

    #[test]
    fn rejects_missing_duplicate_or_invalid_result_lines() {
        let packages = vec!["com.test.app".into()];
        for output in [
            "",
            "SYSLEAF_RESULT\tcom.other.app\ttrue\t",
            "SYSLEAF_RESULT\tcom.test.app\ttrue\t!",
            "SYSLEAF_RESULT\tcom.test.app\tmaybe\t",
            "SYSLEAF_RESULT\tcom.test.app\ttrue\t\nSYSLEAF_RESULT\tcom.test.app\ttrue\t",
        ] {
            assert!(parse_results(output, &packages).is_err());
        }
    }
}
