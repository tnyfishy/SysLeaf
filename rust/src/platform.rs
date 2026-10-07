#[cfg(target_os = "android")]
pub use crate::android::{apps, files_dir, icon, open_hybrid};

#[cfg(not(target_os = "android"))]
pub fn apps() -> crate::error::Result<Vec<crate::model::AppInfo>> {
    Err(crate::error::CoreError::new(
        "ANDROID_ONLY",
        "The installed app list requires Android.",
    ))
}
#[cfg(not(target_os = "android"))]
pub fn files_dir() -> crate::error::Result<std::path::PathBuf> {
    Err(crate::error::CoreError::new(
        "ANDROID_ONLY",
        "Preferences require Android Application context.",
    ))
}
#[cfg(not(target_os = "android"))]
pub fn icon(_: &str) -> crate::error::Result<String> {
    Err(crate::error::CoreError::new(
        "ANDROID_ONLY",
        "Icons require Android.",
    ))
}
#[cfg(not(target_os = "android"))]
pub fn open_hybrid() -> crate::error::Result<()> {
    Err(crate::error::CoreError::new(
        "ANDROID_ONLY",
        "Open the Hybrid Mount URL on Android.",
    ))
}
