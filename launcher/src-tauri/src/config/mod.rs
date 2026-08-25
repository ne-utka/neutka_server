use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Deserialize, Serialize)]
#[serde(transparent)]
pub struct SecretString(String);

impl SecretString {
    pub fn expose_secret(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(default)]
pub struct Preferences {
    pub locale: String,
    pub java_path: Option<String>,
    pub min_memory_mb: u32,
    pub max_memory_mb: u32,
    pub distribution_base_url: String,
    /// `None` — игрок ещё не открывал список и получает моды по умолчанию.
    /// Пустой список — осознанный выбор не ставить ничего.
    pub optional_mod_ids: Option<Vec<String>>,
}

impl Default for Preferences {
    fn default() -> Self {
        // До первого сохранения память подбирается по объёму ОЗУ машины.
        let memory_mb = crate::jvm::profile().recommended_gb * 1024;
        Self {
            locale: "ru-RU".into(),
            java_path: None,
            min_memory_mb: memory_mb,
            max_memory_mb: memory_mb,
            distribution_base_url: "https://springrp.ru/launcher/game".into(),
            optional_mod_ids: None,
        }
    }
}

impl Preferences {
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.min_memory_mb == 0 || self.max_memory_mb < self.min_memory_mb {
            return Err(ConfigError::Validation(
                "memory limits must be positive and ordered".into(),
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Deserialize, Serialize)]
pub struct Session {
    pub profile_id: String,
    pub player_name: String,
    pub access_token: SecretString,
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("configuration file could not be read")]
    Read(#[source] std::io::Error),
    #[error("configuration is not valid TOML")]
    Parse(#[source] toml::de::Error),
    #[error("configuration file could not be written")]
    Write(#[source] std::io::Error),
    #[error("configuration could not be serialized")]
    Serialize(#[source] toml::ser::Error),
    #[error("configuration is invalid: {0}")]
    Validation(String),
}
