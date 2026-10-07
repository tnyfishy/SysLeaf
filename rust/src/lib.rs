#[cfg(target_os = "android")]
mod android;
mod app_management;
#[cfg(any(target_os = "android", test))]
mod categories;
mod error;
mod model;
mod modules;
mod platform;
mod preferences;
mod root;

use error::{CoreError, Result};
use serde_json::{json, Value};
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

static MUTATION_LOCK: Mutex<()> = Mutex::new(());

#[cfg(target_os = "android")]
impl From<jni::errors::Error> for CoreError {
    fn from(value: jni::errors::Error) -> Self {
        CoreError::new("ANDROID_API_ERROR", value.to_string())
    }
}

fn inventory() -> Result<Vec<model::AppInfo>> {
    root::require_root()?;
    let env = root::probe()?;
    let modules = modules::list()?;
    let mut apps = platform::apps()?;
    for app in &mut apps {
        if let Some(module) = modules.iter().find(|m| m.package == app.package) {
            app.module_state = match module.state.as_str() {
                "removing" => "removing",
                "disabled" => "disabled",
                _ if app.system => "active",
                _ if module.boot_id == env.boot_id => "pending",
                _ => "mount_failed",
            }
            .into();
        }
    }
    Ok(apps)
}

fn dispatch(request: Value) -> Result<Value> {
    let action = request
        .get("action")
        .and_then(Value::as_str)
        .ok_or_else(|| CoreError::new("INVALID_REQUEST", "Missing action."))?;
    match action {
        "preferences" => Ok(serde_json::to_value(preferences::load()?)?),
        "save_preferences" => {
            let _guard = MUTATION_LOCK
                .lock()
                .map_err(|_| CoreError::new("OPERATION_BUSY", "Operation lock unavailable."))?;
            let prefs: model::Preferences =
                serde_json::from_value(request.get("preferences").cloned().unwrap_or(Value::Null))?;
            preferences::save(&prefs)?;
            Ok(json!(true))
        }
        "probe" => Ok(serde_json::to_value(root::probe()?)?),
        "apps" => Ok(serde_json::to_value(inventory()?)?),
        "icon" => {
            let package = request.get("package").and_then(Value::as_str).unwrap_or("");
            Ok(json!(platform::icon(package)?))
        }
        "install" => {
            let _guard = MUTATION_LOCK
                .try_lock()
                .map_err(|_| CoreError::new("OPERATION_BUSY", "Another operation is running."))?;
            let packages: Vec<String> =
                serde_json::from_value(request.get("packages").cloned().unwrap_or(Value::Null))?;
            let apps = inventory()?;
            Ok(serde_json::to_value(modules::install(&packages, &apps)?)?)
        }
        "disable_apps" | "uninstall_apps" => {
            let _guard = MUTATION_LOCK
                .try_lock()
                .map_err(|_| CoreError::new("OPERATION_BUSY", "Another operation is running."))?;
            let packages: Vec<String> =
                serde_json::from_value(request.get("packages").cloned().unwrap_or(Value::Null))?;
            let action = if action == "disable_apps" {
                app_management::Action::Disable
            } else {
                app_management::Action::Uninstall
            };
            Ok(serde_json::to_value(app_management::apply(
                &packages, action,
            )?)?)
        }
        "remove" => {
            let _guard = MUTATION_LOCK
                .try_lock()
                .map_err(|_| CoreError::new("OPERATION_BUSY", "Another operation is running."))?;
            let package = request.get("package").and_then(Value::as_str).unwrap_or("");
            Ok(serde_json::to_value(modules::remove(package)?)?)
        }
        "reboot" => {
            let _guard = MUTATION_LOCK
                .try_lock()
                .map_err(|_| CoreError::new("OPERATION_BUSY", "Another operation is running."))?;
            root::reboot()?;
            Ok(json!(true))
        }
        "open_hybrid" => {
            platform::open_hybrid()?;
            Ok(json!(true))
        }
        _ => Err(CoreError::new("INVALID_REQUEST", "Unknown action.")),
    }
}

/// The caller owns `request` for the duration of this call. The returned JSON
/// allocation belongs to Rust and must be freed exactly once with sysleaf_free.
///
/// # Safety
/// `request` must point to a valid NUL-terminated UTF-8 string, or be null.
#[no_mangle]
pub unsafe extern "C" fn sysleaf_call(request: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(|| -> Result<Value> {
        if request.is_null() {
            return Err(CoreError::new("INVALID_REQUEST", "Null request."));
        }
        let input = unsafe { CStr::from_ptr(request) }
            .to_str()
            .map_err(|e| CoreError::new("INVALID_REQUEST", e.to_string()))?;
        if input.len() > 128 * 1024 {
            return Err(CoreError::new("INVALID_REQUEST", "Request too large."));
        }
        dispatch(serde_json::from_str(input)?)
    });
    let response = match result {
        Ok(Ok(data)) => json!({"ok":true,"data":data}),
        Ok(Err(error)) => json!({"ok":false,"error":error}),
        Err(_) => {
            json!({"ok":false,"error":{"code":"INTERNAL_ERROR","message":"Rust operation panicked."}})
        }
    };
    CString::new(response.to_string()).unwrap().into_raw()
}

/// # Safety
/// `value` must be null or an allocation returned by sysleaf_call which has not
/// previously been freed. It must not be a Dart-owned allocation.
#[no_mangle]
pub unsafe extern "C" fn sysleaf_free(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ffi_reports_errors_and_releases_owned_output() {
        for request in ["{}", "{bad}", "{\"action\":\"unknown\"}"] {
            let input = CString::new(request).unwrap();
            let output = unsafe { sysleaf_call(input.as_ptr()) };
            let json: Value =
                serde_json::from_str(unsafe { CStr::from_ptr(output) }.to_str().unwrap()).unwrap();
            assert_eq!(json["ok"], false);
            unsafe {
                sysleaf_free(output);
            }
        }
        let output = unsafe { sysleaf_call(std::ptr::null()) };
        unsafe {
            sysleaf_free(output);
            sysleaf_free(std::ptr::null_mut());
        }
    }
}
