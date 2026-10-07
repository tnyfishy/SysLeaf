use crate::error::{CoreError, Result};
use crate::model::{AppInfo, ManagedModule, OperationResult, APP_ID};
use crate::root::{self, quote};
use std::collections::BTreeSet;
use std::path::Path;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const MARKER: &str = "SYSLEAF_V1";

pub fn validate_package(package: &str) -> Result<()> {
    let valid = package.len() <= 200
        && package.contains('.')
        && package.split('.').all(|s| {
            let mut chars = s.bytes();
            chars
                .next()
                .is_some_and(|c| c.is_ascii_alphabetic() || c == b'_')
                && chars.all(|c| c.is_ascii_alphanumeric() || c == b'_')
        });
    if valid {
        Ok(())
    } else {
        Err(CoreError::new(
            "INVALID_PACKAGE",
            "Invalid Android package ID.",
        ))
    }
}

fn module_id(package: &str) -> String {
    format!("sysleaf_{package}")
}

pub fn validate_app(app: &AppInfo) -> Result<()> {
    validate_package(&app.package)?;
    if app.package == APP_ID
        || app.system
        || !app.enabled
        || !app.installed
        || app.uid / 100000 != 0
        || !app.module_state.is_empty()
    {
        return Err(CoreError::new(
            "APP_NOT_ELIGIBLE",
            format!("{} is not an eligible primary-user app.", app.package),
        ));
    }
    let parent = Path::new(&app.source)
        .parent()
        .ok_or_else(|| CoreError::new("INVALID_SOURCE", "Missing APK directory."))?;
    let mut names = BTreeSet::new();
    for file in std::iter::once(&app.source).chain(app.splits.iter()) {
        let path = Path::new(file);
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if !file.starts_with("/data/app/")
            || file.contains("/../")
            || path.parent() != Some(parent)
            || !name.ends_with(".apk")
            || !name
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-' || b == b'.')
            || !names.insert(name)
            || file.bytes().any(|b| b == 0 || b == b'\n' || b == b'\r')
        {
            return Err(CoreError::new(
                "INVALID_SOURCE",
                "APK paths must belong to the same installed /data/app package.",
            ));
        }
    }
    Ok(())
}

pub fn list() -> Result<Vec<ManagedModule>> {
    let text = root::run(
        r#"
for m in /data/adb/modules/sysleaf_*; do
  [ -d "$m" ] || continue
  [ "$(cat "$m/.sysleaf-managed" 2>/dev/null)" = SYSLEAF_V1 ] || continue
  state=installed
  [ -f "$m/migration_pending_boot" ] && [ "$(cat "$m/migration_pending_boot")" = "$(cat /proc/sys/kernel/random/boot_id)" ] && state=pending
  [ -e "$m/disable" ] && state=disabled
  [ -e "$m/remove" ] && state=removing
  package=$(cat "$m/package")
  target=unknown
  [ -d "$m/system/system_ext/priv-app/$package" ] && target=/system_ext/priv-app
  [ -d "$m/system/app/$package" ] && target=/system/app
  printf '%s\t%s\t%s\t%s\n' "$package" "$state" "$(cat "$m/installed_boot_id" 2>/dev/null)" "$target"
done
"#,
        Duration::from_secs(15),
    )?;
    Ok(text
        .lines()
        .filter_map(|line| {
            let mut parts = line.split('\t');
            let package = parts.next()?.to_string();
            validate_package(&package).ok()?;
            Some(ManagedModule {
                package,
                state: parts.next()?.into(),
                boot_id: parts.next().unwrap_or("").into(),
                target: parts.next().unwrap_or("unknown").into(),
            })
        })
        .collect())
}

fn xml_permissions(app: &AppInfo) -> Result<String> {
    let mut out = format!("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<permissions>\n  <privapp-permissions package=\"{}\">\n", app.package);
    for permission in &app.privileged_permissions {
        if permission.len() > 256
            || !permission
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'_')
        {
            return Err(CoreError::new(
                "INVALID_PERMISSION",
                "Invalid privileged permission.",
            ));
        }
        // Systemizing is not consent to granting signature/privileged powers.
        // Explicit denial satisfies Android's enforced privapp allowlist.
        out.push_str(&format!("    <deny-permission name=\"{permission}\"/>\n"));
    }
    out.push_str("  </privapp-permissions>\n</permissions>\n");
    Ok(out)
}

pub struct Layout<'a> {
    pub adb: &'a str,
    pub boot_id: &'a str,
    pub token: &'a str,
}

pub fn install_script(apps: &[AppInfo], layout: &Layout<'_>) -> Result<String> {
    let stage = format!("{}/.sysleaf-stage-{}", layout.adb, layout.token);
    let lock = format!("{}/.sysleaf-lock", layout.adb);
    let modules = format!("{}/modules", layout.adb);
    let mut script = format!(
        r#"set -eu
export PATH=/system/bin:/system/xbin:$PATH
fail() {{ echo "SYSLEAF_ERROR:$1" >&2; exit 1; }}
[ "$(id -u)" = 0 ] || fail ROOT_DENIED
stage={stage}
modules={modules}
lock={lock}
mkdir "$lock" 2>/dev/null || fail OPERATION_BUSY
published=''
committed=false
cleanup() {{
  if [ "$committed" = false ]; then
    for id in $published; do rm -rf "$modules/$id"; done
  fi
  rm -rf "$stage"
  rmdir "$lock" 2>/dev/null || true
}}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$modules"
mkdir "$stage"
needed=8192
"#,
        stage = quote(&stage),
        modules = quote(&modules),
        lock = quote(&lock)
    );
    for app in apps {
        validate_package(&app.package)?;
        let id = module_id(&app.package);
        script.push_str(&format!(
            "[ ! -e \"$modules/{id}\" ] || fail MODULE_EXISTS\n"
        ));
        for source in std::iter::once(&app.source).chain(app.splits.iter()) {
            script.push_str(&format!(
                "[ -f {s} ] || fail APP_CHANGED\nneeded=$((needed + $(du -k {s} | cut -f1)))\n",
                s = quote(source)
            ));
        }
        let lib = format!("{}/lib", Path::new(&app.source).parent().unwrap().display());
        script.push_str(&format!(
            "if [ -d {lib} ]; then needed=$((needed + $(du -sk {lib} | cut -f1))); fi\n",
            lib = quote(&lib)
        ));
    }
    script.push_str(&format!("available=$(df -Pk {} | tail -n 1 | awk '{{print $4}}')\n[ \"$available\" -ge \"$needed\" ] || fail NO_SPACE\n",quote(layout.adb)));
    for app in apps {
        let id = module_id(&app.package);
        let files: Vec<&String> = std::iter::once(&app.source)
            .chain(app.splits.iter())
            .collect();
        let expected = files
            .iter()
            .map(|s| format!("package:{s}"))
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>()
            .join("\n");
        let check = format!(
            "actual=$(pm path --user 0 {} | sort)\n[ \"$actual\" = {} ] || fail APP_CHANGED\n",
            quote(&app.package),
            quote(&expected)
        );
        script.push_str(&check);
        let banking = app.category == "banking";
        let target = if banking {
            "system/app"
        } else {
            "system/system_ext/priv-app"
        };
        script.push_str(&format!(
            "m=\"$stage/{id}\"\napp=\"$m/{target}/{}\"\nmkdir -p \"$app\"\n",
            app.package
        ));
        for source in &files {
            let name = Path::new(source).file_name().unwrap().to_str().unwrap();
            script.push_str(&format!("before=$(sha256sum {source} | cut -d ' ' -f1)\ncp -f {source} \"$app/{name}\"\nafter=$(sha256sum \"$app/{name}\" | cut -d ' ' -f1)\n[ \"$before\" = \"$after\" ] || fail COPY_FAILED\n[ \"$before\" = \"$(sha256sum {source} | cut -d ' ' -f1)\" ] || fail APP_CHANGED\n",source=quote(source)));
        }
        let lib = format!("{}/lib", Path::new(&app.source).parent().unwrap().display());
        script.push_str(&format!(
            "if [ -d {lib} ]; then cp -RL {lib} \"$app/lib\"; fi\n",
            lib = quote(&lib)
        ));
        let name: String = app
            .name
            .chars()
            .filter(|c| *c != '\n' && *c != '\r')
            .take(100)
            .collect();
        let mount_target = if banking {
            "/system/app"
        } else {
            "/system_ext/priv-app"
        };
        let prop = format!("id={id}\nname=SysLeaf · {name}\nversion=1.1\nversionCode=2\nauthor=tnyfishy\ndescription=Systemless {mount_target} overlay for {}. User data stays in /data.\n", app.package);
        let mut contents = vec![
            ("module.prop".into(), prop),
            ("package".into(), app.package.clone()),
            (".sysleaf-managed".into(), MARKER.into()),
            ("installed_boot_id".into(), layout.boot_id.into()),
            ("mount_target".into(), mount_target.into()),
        ];
        if !banking {
            script.push_str("mkdir -p \"$m/system/system_ext/etc/permissions\"\n");
            contents.push((
                format!(
                    "system/system_ext/etc/permissions/privapp-sysleaf-{}.xml",
                    app.package
                ),
                xml_permissions(app)?,
            ));
        }
        for (file, content) in contents {
            script.push_str(&format!(
                "printf '%s\\n' {} > \"$m/{file}\"\n",
                quote(&content)
            ));
        }
        script.push_str("chown -R 0:0 \"$m\"\nfind \"$m\" -type d -exec chmod 0755 {} \\;\nfind \"$m\" -type f -exec chmod 0644 {} \\;\nchcon -R u:object_r:system_file:s0 \"$m/system\" || fail SELINUX_FAILED\n");
        script.push_str(&check);
    }
    // No installed module is changed until every selected package has staged.
    // On ordinary command failure, the EXIT trap rolls back all published modules.
    for app in apps {
        let id = module_id(&app.package);
        script.push_str(&format!("[ ! -e \"$modules/{id}\" ] || fail MODULE_EXISTS\npublished=\"$published {id}\"\nmv \"$stage/{id}\" \"$modules/{id}\"\n"));
    }
    script.push_str("sync\ncommitted=true\nprintf 'SYSLEAF_OK\\n'\n");
    Ok(script)
}

pub fn install(packages: &[String], inventory: &[AppInfo]) -> Result<OperationResult> {
    if packages.is_empty() || packages.len() > 100 {
        return Err(CoreError::new(
            "INVALID_SELECTION",
            "Select between 1 and 100 apps.",
        ));
    }
    let mut selected = Vec::new();
    let mut seen = BTreeSet::new();
    for package in packages {
        validate_package(package)?;
        if !seen.insert(package) {
            return Err(CoreError::new("INVALID_SELECTION", "Duplicate package."));
        }
        let app = inventory
            .iter()
            .find(|a| &a.package == package)
            .ok_or_else(|| CoreError::new("APP_CHANGED", "Refresh the installed app list."))?;
        validate_app(app)?;
        selected.push(app.clone());
    }
    let env = root::probe()?;
    if !env.can_systemize
        && !(env.reason == "PARTITION_MISSING" && selected.iter().all(|a| a.category == "banking"))
    {
        return Err(CoreError::new(
            &env.reason,
            "Systemizer prerequisites are not met.",
        ));
    }
    let token = format!(
        "{}-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis(),
        std::process::id()
    );
    let script = install_script(
        &selected,
        &Layout {
            adb: "/data/adb",
            boot_id: &env.boot_id,
            token: &token,
        },
    )?;
    let out = root::run(&script, Duration::from_secs(600))?;
    if !out.contains("SYSLEAF_OK") {
        return Err(CoreError::new(
            "INSTALL_FAILED",
            "Module installation did not complete.",
        ));
    }
    Ok(OperationResult {
        packages: packages.to_vec(),
        reboot_required: true,
    })
}

fn migration_script(packages: &[String], layout: &Layout<'_>) -> Result<String> {
    let stage = format!("{}/.sysleaf-bank-stage-{}", layout.adb, layout.token);
    let backup = format!("{}/.sysleaf-bank-backup-{}", layout.adb, layout.token);
    let modules = format!("{}/modules", layout.adb);
    let lock = format!("{}/.sysleaf-lock", layout.adb);
    let mut script = format!(
        r#"set -eu
fail() {{ echo "SYSLEAF_ERROR:$1" >&2; exit 1; }}
[ "$(id -u)" = 0 ] || fail ROOT_DENIED
stage={stage}
backup={backup}
modules={modules}
lock={lock}
mkdir "$lock" 2>/dev/null || fail OPERATION_BUSY
old_moved=''
published=''
committed=false
cleanup() {{
  if [ "$committed" = false ]; then
    for id in $published; do rm -rf "$modules/$id"; done
    for id in $old_moved; do
      if [ -d "$backup/$id" ]; then mv "$backup/$id" "$modules/$id" || echo SYSLEAF_ERROR:ROLLBACK_FAILED >&2; fi
    done
    rmdir "$backup" 2>/dev/null || true
  fi
  rm -rf "$stage"
  rmdir "$lock" 2>/dev/null || true
}}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir "$stage" "$backup"
hash_tree() {{
  (cd "$1" || exit 1
   find . -type f -exec sha256sum {{}} + > "$stage/.hash-tree" || exit 1
   sort "$stage/.hash-tree")
}}
needed=8192
"#,
        stage = quote(&stage),
        backup = quote(&backup),
        modules = quote(&modules),
        lock = quote(&lock)
    );
    for package in packages {
        validate_package(package)?;
        let id = module_id(package);
        script.push_str(&format!(
            r#"old="$modules/{id}"
[ -d "$old" ] && [ ! -L "$old" ] || fail APP_CHANGED
[ "$(cat "$old/.sysleaf-managed")" = SYSLEAF_V1 ] || fail APP_CHANGED
[ "$(cat "$old/package")" = {package} ] || fail APP_CHANGED
[ ! -e "$old/remove" ] || fail APP_CHANGED
[ -d "$old/system/system_ext/priv-app/{raw}" ] || fail APP_CHANGED
[ ! -e "$old/system/app/{raw}" ] || fail APP_CHANGED
[ -z "$(find "$old" -type l -print)" ] || fail INVALID_SOURCE
needed=$((needed + $(du -sk "$old" | cut -f1)))
"#,
            package = quote(package),
            raw = package
        ));
    }
    script.push_str(&format!("available=$(df -Pk {} | tail -n 1 | awk '{{print $4}}')\n[ \"$available\" -ge \"$needed\" ] || fail NO_SPACE\n", quote(layout.adb)));
    for package in packages {
        let id = module_id(package);
        // Keep the old directory outside modules until after the next boot;
        // mounted overlays may still refer to these inodes during this boot.
        let cleanup_script = format!(
            r#"#!/system/bin/sh
mounted=true
for apk in {module}/system/app/{package}/*.apk; do
  [ -f "$apk" ] && cmp -s "$apk" {target}/"${{apk##*/}}" || mounted=false
done
if [ "$(cat /proc/sys/kernel/random/boot_id)" != {boot} ] && [ "$mounted" = true ]; then
  rm -rf {old}
  rmdir {parent} 2>/dev/null || true
fi
"#,
            boot = quote(layout.boot_id),
            target = quote(&format!("/system/app/{package}")),
            module = quote(&format!("{modules}/{id}")),
            old = quote(&format!("{backup}/{id}")),
            parent = quote(&backup)
        );
        script.push_str(&format!(r#"old="$modules/{id}"
src="$old/system/system_ext/priv-app/{package}"
before=$(hash_tree "$src")
[ -n "$before" ] && [ -n "$(find "$src" -maxdepth 1 -type f -name '*.apk' -print)" ] || fail INVALID_SOURCE
m="$stage/{id}"
module_before=$(hash_tree "$old")
cp -a "$old" "$m"
[ "$(hash_tree "$m")" = "$module_before" ] || fail COPY_FAILED
printf '%s\n' "$module_before" > "$stage/{id}.before"
mkdir -p "$m/system/app"
mv "$m/system/system_ext/priv-app/{package}" "$m/system/app/{package}"
[ "$(hash_tree "$m/system/app/{package}")" = "$before" ] || fail COPY_FAILED
[ "$(hash_tree "$src")" = "$before" ] || fail APP_CHANGED
rm -f "$m/system/system_ext/etc/permissions/privapp-sysleaf-{package}.xml"
rmdir "$m/system/system_ext/priv-app" "$m/system/system_ext/etc/permissions" "$m/system/system_ext/etc" "$m/system/system_ext" 2>/dev/null || true
sed -i 's|^version=.*|version=1.1|; s|^versionCode=.*|versionCode=2|; s|^description=.*|description=Systemless /system/app banking overlay. User data stays in /data.|' "$m/module.prop"
printf '%s\n' /system/app > "$m/mount_target"
printf '%s\n' {boot} > "$m/installed_boot_id"
printf '%s\n' {boot} > "$m/migration_pending_boot"
printf '%s\n' {cleanup} > "$m/service.sh"
chown -R 0:0 "$m"
find "$m" -type d -exec chmod 0755 {{}} \;
find "$m" -type f -exec chmod 0644 {{}} \;
chmod 0755 "$m/service.sh"
chcon -R u:object_r:system_file:s0 "$m/system" || fail SELINUX_FAILED
"#, boot=quote(layout.boot_id), cleanup=quote(&cleanup_script)));
    }
    for package in packages {
        let id = module_id(package);
        script.push_str(&format!(
            r#"[ ! -e "$modules/{id}/remove" ] || fail APP_CHANGED
[ "$(hash_tree "$modules/{id}")" = "$(cat "$stage/{id}.before")" ] || fail APP_CHANGED
old_moved="$old_moved {id}"
mv "$modules/{id}" "$backup/{id}"
published="$published {id}"
mv "$stage/{id}" "$modules/{id}"
"#
        ));
    }
    script.push_str("sync\ncommitted=true\nprintf 'SYSLEAF_OK\\n'\n");
    Ok(script)
}

pub fn migrate_banks(packages: &[String], inventory: &[AppInfo]) -> Result<OperationResult> {
    if packages.is_empty()
        || packages.len() > 100
        || packages.iter().collect::<BTreeSet<_>>().len() != packages.len()
    {
        return Err(CoreError::new(
            "INVALID_SELECTION",
            "Select between 1 and 100 distinct banking modules.",
        ));
    }
    for package in packages {
        validate_package(package)?;
        let app = inventory
            .iter()
            .find(|a| &a.package == package)
            .ok_or_else(|| CoreError::new("APP_CHANGED", "Refresh the app list."))?;
        if app.category != "banking"
            || app.module_target != "/system_ext/priv-app"
            || app.module_state.is_empty()
            || app.module_state == "removing"
        {
            return Err(CoreError::new(
                "APP_CHANGED",
                "Only existing SysLeaf banking modules can be moved.",
            ));
        }
    }
    let env = root::probe()?;
    if !env.can_systemize && env.reason != "PARTITION_MISSING" {
        return Err(CoreError::new(
            &env.reason,
            "Mount prerequisites are not met.",
        ));
    }
    let token = format!(
        "{}-{}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis(),
        std::process::id()
    );
    let out = root::run(
        &migration_script(
            packages,
            &Layout {
                adb: "/data/adb",
                boot_id: &env.boot_id,
                token: &token,
            },
        )?,
        Duration::from_secs(600),
    )?;
    if !out.contains("SYSLEAF_OK") {
        return Err(CoreError::new(
            "INSTALL_FAILED",
            "Banking module migration did not complete.",
        ));
    }
    Ok(OperationResult {
        packages: packages.to_vec(),
        reboot_required: true,
    })
}

pub fn remove(package: &str) -> Result<OperationResult> {
    validate_package(package)?;
    root::require_root()?;
    let path = format!("/data/adb/modules/{}", module_id(package));
    root::run(&format!("set -eu\n[ \"$(cat {p}/.sysleaf-managed)\" = {marker} ] || exit 1\ntouch {p}/remove\nsync\n",p=quote(&path),marker=quote(MARKER)),Duration::from_secs(15))?;
    Ok(OperationResult {
        packages: vec![package.into()],
        reboot_required: true,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_shell_injection_and_path_traversal() {
        for value in [
            "com.x;reboot",
            "com../app",
            "com.x\nreboot",
            ".com.x",
            "com.a-b",
            "com.9app",
        ] {
            assert!(validate_package(value).is_err());
        }
        assert!(validate_package("com.vietcombank.vcbmobile").is_ok());
    }
    #[test]
    fn denies_privileged_permissions_instead_of_granting_them() {
        let app = fixture(
            "/data/app/random/com.example/base.apk".into(),
            "com.example",
        );
        let xml = xml_permissions(&app).unwrap();
        assert!(xml.contains(
            "<deny-permission name=\"android.permission.READ_PRIVILEGED_PHONE_STATE\"/>"
        ));
        assert!(!xml.contains("<permission name="));
    }
    fn fixture(source: String, package: &str) -> AppInfo {
        AppInfo {
            package: package.into(),
            name: "Example ' $(touch nope)".into(),
            source,
            splits: vec![],
            native_lib: String::new(),
            system: false,
            enabled: true,
            installed: true,
            category: "other".into(),
            category_reason: "unknown".into(),
            privileged_permissions: vec!["android.permission.READ_PRIVILEGED_PHONE_STATE".into()],
            uid: 10123,
            version: "1".into(),
            module_state: String::new(),
            module_target: String::new(),
            icon: None,
        }
    }
    #[test]
    fn validates_apk_set_and_primary_user() {
        let mut app = fixture(
            "/data/app/random/com.example/base.apk".into(),
            "com.example",
        );
        app.splits
            .push("/data/app/random/com.example/split_config.arm64.apk".into());
        assert!(validate_app(&app).is_ok());
        app.splits.push("/data/app/another/base.apk".into());
        assert!(validate_app(&app).is_err());
        app.splits.clear();
        app.uid = 110123;
        assert!(validate_app(&app).is_err());
    }
    #[test]
    fn transaction_copies_splits_and_keeps_data_then_rolls_back_on_failure() {
        use std::os::unix::fs::PermissionsExt;
        let tmp = tempfile::tempdir().unwrap();
        let base = tmp.path();
        let adb = base.join("adb");
        let bin = base.join("bin");
        let source = base.join("apk");
        std::fs::create_dir_all(&adb).unwrap();
        std::fs::create_dir_all(&bin).unwrap();
        std::fs::create_dir_all(source.join("lib/arm64")).unwrap();
        std::fs::write(source.join("base.apk"), "BASE_BYTES").unwrap();
        std::fs::write(source.join("split_config.apk"), "SPLIT_BYTES").unwrap();
        std::fs::write(source.join("lib/arm64/test.so"), "LIB_BYTES").unwrap();
        let userdata = base.join("private-data");
        std::fs::write(&userdata, "PRESERVE_ME").unwrap();
        let mut app = fixture(source.join("base.apk").display().to_string(), "com.example");
        app.splits
            .push(source.join("split_config.apk").display().to_string());
        for (name, script) in [
            ("id", "#!/bin/sh\necho 0\n".into()),
            ("chown", "#!/bin/sh\nexit 0\n".into()),
            ("chcon", "#!/bin/sh\nexit 0\n".into()),
            (
                "pm",
                format!(
                    "#!/bin/sh\nprintf '%s\\n' {} {}\n",
                    quote(&format!("package:{}", app.source)),
                    quote(&format!("package:{}", app.splits[0]))
                ),
            ),
        ] {
            let path = bin.join(name);
            std::fs::write(&path, script).unwrap();
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
        let run = |apps: &[AppInfo], token: &str| {
            let script = install_script(
                apps,
                &Layout {
                    adb: adb.to_str().unwrap(),
                    boot_id: "BOOT_A",
                    token,
                },
            )
            .unwrap();
            std::process::Command::new("sh")
                .args(["-c", &script])
                .env(
                    "PATH",
                    format!("{}:{}", bin.display(), std::env::var("PATH").unwrap()),
                )
                .output()
                .unwrap()
        };
        let result = run(&[app.clone()], "1");
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        let overlay =
            adb.join("modules/sysleaf_com.example/system/system_ext/priv-app/com.example");
        assert_eq!(
            std::fs::read_to_string(overlay.join("split_config.apk")).unwrap(),
            "SPLIT_BYTES"
        );
        assert_eq!(
            std::fs::read_to_string(overlay.join("lib/arm64/test.so")).unwrap(),
            "LIB_BYTES"
        );
        assert_eq!(std::fs::read_to_string(&userdata).unwrap(), "PRESERVE_ME");
        assert!(!adb.join(".sysleaf-lock").exists());
        let mut bank = app.clone();
        bank.package = "com.mbmobile".into();
        bank.category = "banking".into();
        let bank_result = run(&[bank], "bank");
        assert!(
            bank_result.status.success(),
            "{}",
            String::from_utf8_lossy(&bank_result.stderr)
        );
        let bank_module = adb.join("modules/sysleaf_com.mbmobile");
        assert!(bank_module
            .join("system/app/com.mbmobile/base.apk")
            .exists());
        assert!(bank_module
            .join("system/app/com.mbmobile/split_config.apk")
            .exists());
        assert!(bank_module
            .join("system/app/com.mbmobile/lib/arm64/test.so")
            .exists());
        assert!(!bank_module.join("system/system_ext").exists());
        assert_eq!(
            std::fs::read_to_string(bank_module.join("mount_target"))
                .unwrap()
                .trim(),
            "/system/app"
        );
        std::fs::remove_dir_all(bank_module).unwrap();
        std::fs::remove_dir_all(adb.join("modules/sysleaf_com.example")).unwrap();
        let mut broken = app.clone();
        broken.package = "com.broken".into();
        broken.source = base.join("missing.apk").display().to_string();
        let failed = run(&[app.clone(), broken], "2");
        assert!(!failed.status.success());
        assert!(!adb.join("modules/sysleaf_com.example").exists());
        assert!(!adb.join(".sysleaf-stage-2").exists());
        assert!(!adb.join(".sysleaf-lock").exists());
        assert_eq!(std::fs::read_to_string(&userdata).unwrap(), "PRESERVE_ME");

        // Fail the second publication after the first module already moved.
        let mv = bin.join("mv");
        std::fs::write(
            &mv,
            "#!/bin/sh\ncase \"$2\" in */sysleaf_com.second) exit 1;; esac\nexec /bin/mv \"$@\"\n",
        )
        .unwrap();
        std::fs::set_permissions(&mv, std::fs::Permissions::from_mode(0o755)).unwrap();
        let mut second = app.clone();
        second.package = "com.second".into();
        let failed = run(&[app.clone(), second], "3");
        assert!(!failed.status.success());
        assert!(!adb.join("modules/sysleaf_com.example").exists());
        assert!(!adb.join("modules/sysleaf_com.second").exists());
        assert!(!adb.join(".sysleaf-lock").exists());
        std::fs::remove_file(mv).unwrap();

        // A corrupted copy must fail SHA-256 validation before publication.
        let cp = bin.join("cp");
        std::fs::write(&cp,"#!/bin/sh\n/bin/cp \"$@\" || exit $?\nfor dest; do :; done\ncase \"$dest\" in *.apk) printf CORRUPT >> \"$dest\";; esac\n").unwrap();
        std::fs::set_permissions(cp, std::fs::Permissions::from_mode(0o755)).unwrap();
        let failed = run(&[app], "4");
        assert!(!failed.status.success());
        assert!(String::from_utf8_lossy(&failed.stderr).contains("COPY_FAILED"));
        assert!(!adb.join("modules/sysleaf_com.example").exists());
        assert!(!adb.join(".sysleaf-stage-4").exists());
        assert!(!adb.join(".sysleaf-lock").exists());
        assert_eq!(std::fs::read_to_string(userdata).unwrap(), "PRESERVE_ME");
    }

    #[test]
    fn banking_migration_preserves_payload_state_backup_and_rolls_back() {
        use std::os::unix::fs::PermissionsExt;
        let tmp = tempfile::tempdir().unwrap();
        let adb = tmp.path().join("adb");
        let bin = tmp.path().join("bin");
        std::fs::create_dir_all(&adb).unwrap();
        std::fs::create_dir_all(&bin).unwrap();
        for (name, body) in [("id", "echo 0"), ("chown", "exit 0"), ("chcon", "exit 0")] {
            let p = bin.join(name);
            std::fs::write(&p, format!("#!/bin/sh\n{body}\n")).unwrap();
            std::fs::set_permissions(p, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
        let packages = vec![
            "com.mbmobile".to_string(),
            "com.tpb.mb.gprsandroid".to_string(),
        ];
        let seed = || {
            for package in &packages {
                let module = adb.join(format!("modules/sysleaf_{package}"));
                let app = module.join(format!("system/system_ext/priv-app/{package}"));
                std::fs::create_dir_all(app.join("lib/arm64")).unwrap();
                for (n, b) in [
                    ("base.apk", "BASE"),
                    ("split_config.apk", "SPLIT"),
                    ("lib/arm64/a.so", "NATIVE"),
                ] {
                    std::fs::write(app.join(n), b).unwrap();
                }
                let permissions = module.join("system/system_ext/etc/permissions");
                std::fs::create_dir_all(&permissions).unwrap();
                std::fs::write(
                    permissions.join(format!("privapp-sysleaf-{package}.xml")),
                    "DENIALS",
                )
                .unwrap();
                std::fs::write(module.join(".sysleaf-managed"), MARKER).unwrap();
                std::fs::write(module.join("package"), package).unwrap();
                std::fs::write(module.join("installed_boot_id"), "BOOT_OLD").unwrap();
                std::fs::write(
                    module.join("module.prop"),
                    format!("id=sysleaf_{package}\nversion=1.0\nversionCode=1\ndescription=old\n"),
                )
                .unwrap();
                if package == "com.mbmobile" {
                    std::fs::write(module.join("disable"), "").unwrap();
                }
            }
        };
        let run = |token: &str| {
            let script = migration_script(
                &packages,
                &Layout {
                    adb: adb.to_str().unwrap(),
                    boot_id: "BOOT_NOW",
                    token,
                },
            )
            .unwrap();
            std::process::Command::new("sh")
                .args(["-c", &script])
                .env(
                    "PATH",
                    format!("{}:{}", bin.display(), std::env::var("PATH").unwrap()),
                )
                .output()
                .unwrap()
        };
        let private_data = tmp.path().join("user-data");
        std::fs::write(&private_data, "PRESERVED").unwrap();
        seed();
        let out = run("ok");
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        for package in &packages {
            let module = adb.join(format!("modules/sysleaf_{package}"));
            let dest = module.join(format!("system/app/{package}"));
            assert_eq!(
                std::fs::read_to_string(dest.join("base.apk")).unwrap(),
                "BASE"
            );
            assert_eq!(
                std::fs::read_to_string(dest.join("split_config.apk")).unwrap(),
                "SPLIT"
            );
            assert_eq!(
                std::fs::read_to_string(dest.join("lib/arm64/a.so")).unwrap(),
                "NATIVE"
            );
            assert!(!module.join("system/system_ext").exists());
            assert_eq!(module.join("disable").exists(), package == "com.mbmobile");
            assert!(adb.join(format!(".sysleaf-bank-backup-ok/sysleaf_{package}/system/system_ext/priv-app/{package}/base.apk")).exists());
            assert_eq!(
                std::fs::read_to_string(module.join("migration_pending_boot"))
                    .unwrap()
                    .trim(),
                "BOOT_NOW"
            );
        }
        assert!(!adb.join(".sysleaf-lock").exists());
        assert!(!adb.join(".sysleaf-bank-stage-ok").exists());
        assert_eq!(std::fs::read_to_string(&private_data).unwrap(), "PRESERVED");
        // Exercise the real generated cleanup logic against a simulated boot
        // and mount. Never remove backups in the same boot or on a bad mount.
        let boot_file = tmp.path().join("boot-id");
        let mounted = tmp.path().join("mounted-apps");
        let package = &packages[1];
        let module = adb.join(format!("modules/sysleaf_{package}"));
        let backup = adb.join(format!(".sysleaf-bank-backup-ok/sysleaf_{package}"));
        let service = std::fs::read_to_string(module.join("service.sh"))
            .unwrap()
            .replace(
                "/proc/sys/kernel/random/boot_id",
                boot_file.to_str().unwrap(),
            )
            .replace(
                &quote(&format!("/system/app/{package}")),
                &quote(mounted.to_str().unwrap()),
            );
        std::fs::create_dir_all(&mounted).unwrap();
        std::fs::write(mounted.join("base.apk"), "BASE").unwrap();
        std::fs::write(mounted.join("split_config.apk"), "SPLIT").unwrap();
        let cleanup = || {
            let result = std::process::Command::new("sh")
                .args(["-c", &service])
                .output()
                .unwrap();
            assert!(result.status.success());
        };
        std::fs::write(&boot_file, "BOOT_NOW").unwrap();
        cleanup();
        assert!(backup.exists());
        std::fs::write(&boot_file, "BOOT_NEXT").unwrap();
        std::fs::write(mounted.join("split_config.apk"), "WRONG").unwrap();
        cleanup();
        assert!(backup.exists());
        std::fs::write(mounted.join("split_config.apk"), "SPLIT").unwrap();
        cleanup();
        assert!(!backup.exists());
        assert!(adb
            .join(".sysleaf-bank-backup-ok/sysleaf_com.mbmobile")
            .exists());
        assert!(module.exists());
        std::fs::remove_dir_all(adb.join("modules")).unwrap();
        seed();
        let mv = bin.join("mv");
        std::fs::write(&mv, "#!/bin/sh\ncase \"$1\" in */.sysleaf-bank-stage-fail/sysleaf_com.tpb.mb.gprsandroid) exit 1;; esac\nexec /bin/mv \"$@\"\n").unwrap();
        std::fs::set_permissions(&mv, std::fs::Permissions::from_mode(0o755)).unwrap();
        let out = run("fail");
        assert!(!out.status.success());
        for package in &packages {
            let module = adb.join(format!("modules/sysleaf_{package}"));
            assert!(module
                .join(format!("system/system_ext/priv-app/{package}/base.apk"))
                .exists());
            assert!(!module.join("system/app").exists());
            assert_eq!(module.join("disable").exists(), package == "com.mbmobile");
        }
        assert!(!adb.join(".sysleaf-bank-stage-fail").exists());
        assert!(!adb.join(".sysleaf-bank-backup-fail").exists());
        assert!(!adb.join(".sysleaf-lock").exists());
        assert_eq!(std::fs::read_to_string(private_data).unwrap(), "PRESERVED");
    }
}
