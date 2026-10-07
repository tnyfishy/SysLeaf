use crate::error::{CoreError, Result};
use crate::model::Environment;
use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::time::{Duration, Instant};

pub fn quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

pub fn run(script: &str, timeout: Duration) -> Result<String> {
    // Streaming the script avoids Linux's per-argument size limit on large
    // batches. A device-side timeout also terminates the root shell, allowing
    // its EXIT/TERM cleanup to run if the Flutter worker disappears.
    let shell = format!("if [ -x /system/bin/timeout ]; then exec /system/bin/timeout -s TERM {} /system/bin/sh -s; else exec /system/bin/sh -s; fi", timeout.as_secs());
    execute("su", &["-c", &shell], script, timeout)
}

fn execute(program: &str, args: &[&str], script: &str, timeout: Duration) -> Result<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| CoreError::new("ROOT_DENIED", e.to_string()))?;
    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    let (tx, rx) = mpsc::channel();
    let mut stdin = child.stdin.take().unwrap();
    let input = script.as_bytes().to_vec();
    let writer = tx.clone();
    std::thread::spawn(move || {
        let error = stdin
            .write_all(&input)
            .err()
            .map(|e| e.to_string())
            .unwrap_or_default();
        drop(stdin);
        let _ = writer.send((2, error));
    });
    for (kind, pipe) in [
        (0, Box::new(stdout) as Box<dyn Read + Send>),
        (1, Box::new(stderr)),
    ] {
        let tx = tx.clone();
        std::thread::spawn(move || {
            let mut bytes = Vec::new();
            let _ = pipe.take(1024 * 1024).read_to_end(&mut bytes);
            let _ = tx.send((kind, String::from_utf8_lossy(&bytes).into_owned()));
        });
    }
    drop(tx);
    let start = Instant::now();
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if start.elapsed() >= timeout {
            let _ = child.kill();
            let _ = child.wait();
            return Err(CoreError::new(
                "TIMEOUT",
                "Root command timed out; refresh the module list before retrying.",
            ));
        }
        std::thread::sleep(Duration::from_millis(25));
    };
    let mut out = String::new();
    let mut err = String::new();
    let mut write_error = String::new();
    for _ in 0..3 {
        if let Ok((kind, value)) = rx.recv_timeout(Duration::from_secs(2)) {
            if kind == 0 {
                out = value;
            } else if kind == 1 {
                err = value;
            } else {
                write_error = value;
            }
        }
    }
    if !status.success() {
        if status.code() == Some(124) {
            return Err(CoreError::new(
                "TIMEOUT",
                "The root shell reached its timeout; refresh the module list.",
            ));
        }
        let detail = if err.trim().is_empty() {
            out.trim()
        } else {
            err.trim()
        };
        let code = detail
            .lines()
            .find_map(|l| l.strip_prefix("SYSLEAF_ERROR:"))
            .unwrap_or("ROOT_COMMAND_FAILED");
        return Err(CoreError::new(
            code,
            detail.chars().take(1200).collect::<String>(),
        ));
    }
    if !write_error.is_empty() {
        return Err(CoreError::new("ROOT_WRITE_FAILED", write_error));
    }
    Ok(out)
}

pub fn require_root() -> Result<()> {
    let uid = run("id -u", Duration::from_secs(90)).map_err(|error| {
        if error.code == "TIMEOUT" {
            error
        } else {
            CoreError::new("ROOT_DENIED", error.message)
        }
    })?;
    if uid.trim() != "0" {
        return Err(CoreError::new(
            "ROOT_DENIED",
            "Superuser access is required.",
        ));
    }
    Ok(())
}

pub fn probe() -> Result<Environment> {
    require_root()?;
    let text = run(
        r#"
manager=unsupported
if [ -x /data/adb/ksu/bin/ksud ]; then manager=KernelSU
elif command -v magisk >/dev/null 2>&1; then manager=Magisk; fi
hybrid_installed=false
hybrid_ready=false
if [ -f /data/adb/modules/hybrid_mount/module.prop ]; then
  hybrid_installed=true
  if [ ! -e /data/adb/modules/hybrid_mount/disable ] && [ ! -e /data/adb/modules/hybrid_mount/remove ] && [ ! -e /data/adb/modules/hybrid_mount/skip_mount ] && [ -x /data/adb/modules/hybrid_mount/hybrid-mount ] && [ -f /data/adb/hybrid-mount/config.toml ]; then hybrid_ready=true; fi
fi
partition=false
[ -d /system_ext/priv-app ] && partition=true
printf 'manager=%s\nhybrid_installed=%s\nhybrid_ready=%s\npartition=%s\n' "$manager" "$hybrid_installed" "$hybrid_ready" "$partition"
printf 'sdk=%s\ndevice=%s\nboot_id=%s\n' "$(getprop ro.build.version.sdk)" "$(getprop ro.product.model)" "$(cat /proc/sys/kernel/random/boot_id)"
"#,
        Duration::from_secs(15),
    )?;
    let get = |key: &str| {
        text.lines()
            .find_map(|line| line.strip_prefix(&format!("{key}=")))
            .unwrap_or("")
            .to_string()
    };
    let manager = get("manager");
    let hybrid_installed = get("hybrid_installed") == "true";
    let mut hybrid_ready = get("hybrid_ready") == "true";
    let mut hybrid_mode = String::new();
    let mut module_ignored = false;
    if manager == "KernelSU" && hybrid_ready {
        let config = run(
            "cat /data/adb/hybrid-mount/config.toml",
            Duration::from_secs(10),
        )?;
        if let Ok(value) = config.parse::<toml::Value>() {
            hybrid_mode = value
                .get("default_mode")
                .and_then(|v| v.as_str())
                .unwrap_or("overlay")
                .into();
            // Require a real mount backend. VFS can intentionally hide the injected
            // paths from PackageManager; an ignore rule must never report success.
            hybrid_ready = ["overlay", "magic"].contains(&hybrid_mode.as_str());
            let module_dir = value
                .get("moduledir")
                .and_then(|v| v.as_str())
                .unwrap_or("/data/adb/modules");
            hybrid_ready &=
                std::path::Path::new(module_dir) == std::path::Path::new("/data/adb/modules");
            if let Some(rules) = value.get("rules").and_then(|v| v.as_table()) {
                module_ignored = rules
                    .iter()
                    .filter(|(id, _)| id.starts_with("sysleaf_"))
                    .any(|(_, rule)| {
                        let bad = |mode: &str| !["overlay", "magic"].contains(&mode);
                        rule.get("default_mode")
                            .and_then(|m| m.as_str())
                            .is_some_and(bad)
                            || rule
                                .get("paths")
                                .and_then(|p| p.as_table())
                                .is_some_and(|p| p.values().any(|m| m.as_str().is_some_and(bad)))
                    });
            }
        } else {
            hybrid_ready = false;
        }
    }
    let partition_exists = get("partition") == "true";
    let reason = if !partition_exists {
        "PARTITION_MISSING"
    } else if manager == "unsupported" {
        "MANAGER_UNSUPPORTED"
    } else if manager == "KernelSU" && !hybrid_ready {
        "HYBRID_REQUIRED"
    } else if module_ignored {
        "HYBRID_RULE_BLOCKED"
    } else {
        ""
    };
    Ok(Environment {
        root: true,
        manager,
        hybrid_installed,
        hybrid_ready,
        hybrid_mode,
        module_ignored,
        partition_exists,
        can_systemize: reason.is_empty(),
        reason: reason.into(),
        android_sdk: get("sdk"),
        device: get("device"),
        boot_id: get("boot_id"),
    })
}

pub fn reboot() -> Result<()> {
    require_root()?;
    run(
        "svc power reboot || /system/bin/reboot",
        Duration::from_secs(15),
    )
    .map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn shell_quotes_untrusted_strings() {
        let malicious = "label'; touch /tmp/should-not-exist; echo '$(id)`id`";
        let out = Command::new("sh")
            .args(["-c", &format!("printf %s {}", quote(malicious))])
            .output()
            .unwrap();
        assert_eq!(String::from_utf8(out.stdout).unwrap(), malicious);
    }
    #[test]
    fn streams_scripts_larger_than_argument_limit() {
        let script = format!(
            "{}\nprintf 'STREAM_OK\\n'\n",
            "# padding for large batch\n".repeat(10000)
        );
        assert!(script.len() > 128 * 1024);
        assert_eq!(
            execute("sh", &["-s"], &script, Duration::from_secs(5))
                .unwrap()
                .trim(),
            "STREAM_OK"
        );
    }
}
