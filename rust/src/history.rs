use crate::error::Result;
use crate::model::AppInfo;
use std::collections::BTreeMap;
use std::path::Path;
use std::sync::Mutex;

static HISTORY_LOCK: Mutex<()> = Mutex::new(());

fn merge(previous: Vec<AppInfo>, fresh: Vec<AppInfo>) -> Vec<AppInfo> {
    let mut known: BTreeMap<String, AppInfo> = previous
        .into_iter()
        .map(|mut app| {
            app.installed = false;
            app.module_state.clear();
            app.module_target.clear();
            (app.package.clone(), app)
        })
        .collect();
    for app in fresh {
        known.insert(app.package.clone(), app);
    }
    known.into_values().collect()
}

fn reconcile_at(dir: &Path, fresh: Vec<AppInfo>) -> Result<Vec<AppInfo>> {
    let path = dir.join("app-history.json");
    let previous = match std::fs::read(&path) {
        Ok(bytes) => serde_json::from_slice(&bytes)?,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Vec::new(),
        Err(e) => return Err(e.into()),
    };
    let apps = merge(previous, fresh);
    let temp = dir.join("app-history.json.tmp");
    std::fs::write(&temp, serde_json::to_vec(&apps)?)?;
    std::fs::rename(temp, path)?;
    Ok(apps)
}

pub fn inventory() -> Result<Vec<AppInfo>> {
    let _guard = HISTORY_LOCK.lock().map_err(|_| {
        crate::error::CoreError::new("OPERATION_BUSY", "App history lock unavailable.")
    })?;
    let fresh = crate::platform::apps()?;
    // Android retains metadata for removed system apps. This local history also
    // retains names/categories of fully removed user apps that Android forgets.
    reconcile_at(&crate::platform::files_dir()?, fresh)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn app(package: &str) -> AppInfo {
        serde_json::from_value(serde_json::json!({
            "package":package,"name":"Remembered bank","source":"/data/app/base.apk","splits":[],
            "native_lib":"","system":false,"enabled":true,"category":"banking","category_reason":"package_catalog",
            "privileged_permissions":[],"uid":10001,"version":"1","module_state":"","icon":null
        })).unwrap()
    }
    #[test]
    fn removed_user_apps_persist_and_reinstalled_apps_replace_stale_metadata() {
        let dir = tempfile::tempdir().unwrap();
        reconcile_at(dir.path(), vec![app("com.mbmobile")]).unwrap();
        let removed = reconcile_at(dir.path(), vec![]).unwrap();
        assert!(!removed[0].installed);
        assert_eq!(removed[0].name, "Remembered bank");
        assert_eq!(removed[0].category, "banking");
        let reloaded = reconcile_at(dir.path(), vec![]).unwrap();
        assert!(!reloaded[0].installed);
        let mut fresh = app("com.mbmobile");
        fresh.name = "Updated bank".into();
        fresh.enabled = false;
        let installed = reconcile_at(dir.path(), vec![fresh]).unwrap();
        assert!(installed[0].installed);
        assert!(!installed[0].enabled);
        assert_eq!(installed[0].name, "Updated bank");
    }
    #[test]
    fn android_known_removed_apps_and_corrupt_cache_do_not_become_installed() {
        let dir = tempfile::tempdir().unwrap();
        let mut removed = app("com.bank.removed");
        removed.installed = false;
        assert!(!reconcile_at(dir.path(), vec![removed]).unwrap()[0].installed);
        let path = dir.path().join("app-history.json");
        std::fs::write(&path, "{broken").unwrap();
        assert!(reconcile_at(dir.path(), vec![]).is_err());
        assert_eq!(std::fs::read_to_string(path).unwrap(), "{broken");
    }
}
