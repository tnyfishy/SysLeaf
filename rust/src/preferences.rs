use crate::error::{CoreError, Result};
use crate::model::Preferences;

pub fn load() -> Result<Preferences> {
    let path = crate::platform::files_dir()?.join("preferences.json");
    match std::fs::read(path) {
        Ok(bytes) => Ok(serde_json::from_slice(&bytes).unwrap_or_default()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Preferences::default()),
        Err(error) => Err(error.into()),
    }
}

pub fn save(prefs: &Preferences) -> Result<()> {
    if !["vi", "en"].contains(&prefs.language.as_str())
        || !["system", "light", "dark", "black"].contains(&prefs.theme.as_str())
    {
        return Err(CoreError::new(
            "INVALID_PREFERENCES",
            "Unsupported language or theme.",
        ));
    }
    let dir = crate::platform::files_dir()?;
    let tmp = dir.join("preferences.json.tmp");
    std::fs::write(&tmp, serde_json::to_vec(prefs)?)?;
    std::fs::rename(tmp, dir.join("preferences.json"))?;
    Ok(())
}
