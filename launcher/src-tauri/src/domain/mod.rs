use serde::Serialize;
use std::path::Path;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ArchitectureStatus {
    pub backend: &'static str,
    pub helper: HelperStatus,
    pub config_storage: &'static str,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum HelperStatus {
    NotConfigured,
    Available,
}

impl ArchitectureStatus {
    pub fn inspect(helper_path: &Path) -> Self {
        Self {
            backend: "ready",
            helper: if helper_path.is_file() {
                HelperStatus::Available
            } else {
                HelperStatus::NotConfigured
            },
            config_storage: "app-data",
        }
    }
}
