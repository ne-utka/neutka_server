use std::{
    fs,
    path::{Path, PathBuf},
};

use serde::de::DeserializeOwned;

use crate::{
    config::{ConfigError, Preferences, Session},
    launcher::{LaunchError, LaunchRequest, PreparedLaunch},
};

/// Filesystem adapter rooted at Tauri's app-data directory.
pub struct TomlConfigStore {
    app_data_dir: PathBuf,
}

impl TomlConfigStore {
    pub fn new(app_data_dir: PathBuf) -> Self {
        Self { app_data_dir }
    }

    pub fn load_preferences(&self) -> Result<Preferences, ConfigError> {
        let preferences: Preferences = self.read_toml("prefs.toml")?;
        preferences.validate()?;
        Ok(preferences)
    }

    pub fn load_session(&self) -> Result<Session, ConfigError> {
        self.read_toml("session.toml")
    }

    fn read_toml<T: DeserializeOwned>(&self, name: &str) -> Result<T, ConfigError> {
        let contents =
            fs::read_to_string(self.app_data_dir.join(name)).map_err(ConfigError::Read)?;
        toml::from_str(&contents).map_err(ConfigError::Parse)
    }
}

/// Adapter responsible only for translating a domain request into the helper contract.
/// Starting the process is intentionally outside the architecture-only milestone.
pub struct JavaHelperAdapter {
    helper_jar: PathBuf,
    skins_dir: PathBuf,
}

impl JavaHelperAdapter {
    pub fn new(helper_jar: PathBuf, skins_dir: PathBuf) -> Self {
        Self {
            helper_jar,
            skins_dir,
        }
    }

    pub fn prepare(&self, request: &LaunchRequest) -> Result<PreparedLaunch, LaunchError> {
        if request.profile_id.trim().is_empty() {
            return Err(LaunchError::InvalidRequest("profileId is empty".into()));
        }
        if !self.helper_jar.is_file() {
            return Err(LaunchError::HelperMissing);
        }

        let executable = request
            .java_path
            .clone()
            .filter(|path| !path.as_os_str().is_empty())
            .ok_or(LaunchError::JavaNotConfigured)?;

        Ok(PreparedLaunch {
            executable,
            helper_jar: self.helper_jar.clone(),
            arguments: vec![
                "-jar".into(),
                path_argument(&self.helper_jar),
                "--profile".into(),
                request.profile_id.clone(),
                "--skins".into(),
                path_argument(&self.skins_dir),
            ],
        })
    }
}

fn path_argument(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}
