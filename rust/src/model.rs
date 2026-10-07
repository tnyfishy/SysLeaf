use serde::{Deserialize, Serialize};

pub const APP_ID: &str = "dev.sysleaf.sysleaf";
#[cfg(target_os = "android")]
pub const HYBRID_URL: &str = "https://github.com/Hybrid-Mount/meta-hybrid_mount";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppInfo {
    pub package: String,
    pub name: String,
    pub source: String,
    pub splits: Vec<String>,
    pub native_lib: String,
    pub system: bool,
    pub enabled: bool,
    #[serde(default = "default_installed")]
    pub installed: bool,
    pub category: String,
    pub category_reason: String,
    pub privileged_permissions: Vec<String>,
    pub uid: i32,
    pub version: String,
    pub module_state: String,
    #[serde(default)]
    pub module_target: String,
    pub icon: Option<String>,
}

fn default_installed() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Preferences {
    pub language: String,
    pub theme: String,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            language: "vi".into(),
            theme: "system".into(),
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Environment {
    pub root: bool,
    pub manager: String,
    pub hybrid_installed: bool,
    pub hybrid_ready: bool,
    pub hybrid_mode: String,
    pub module_ignored: bool,
    pub partition_exists: bool,
    pub can_systemize: bool,
    pub reason: String,
    pub android_sdk: String,
    pub device: String,
    pub boot_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ManagedModule {
    pub package: String,
    pub state: String,
    pub boot_id: String,
    pub target: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct OperationResult {
    pub packages: Vec<String>,
    pub reboot_required: bool,
}
