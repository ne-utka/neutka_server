use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchRequest {
    pub profile_id: String,
    pub java_path: Option<PathBuf>,
}

#[derive(Debug, Clone)]
pub struct PreparedLaunch {
    pub executable: PathBuf,
    pub helper_jar: PathBuf,
    pub arguments: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchReceipt {
    pub process_id: u32,
    pub started_at: String,
}

#[derive(Debug, Error)]
pub enum LaunchError {
    #[error("Java executable is not configured")]
    JavaNotConfigured,
    #[error("NewLaunch.jar is not available")]
    HelperMissing,
    #[error("launch request is invalid: {0}")]
    InvalidRequest(String),
    #[error("game process could not be started")]
    Process(#[source] std::io::Error),
}

pub trait GameLauncher: Send + Sync {
    fn launch(&self, request: LaunchRequest) -> Result<LaunchReceipt, LaunchError>;
}
