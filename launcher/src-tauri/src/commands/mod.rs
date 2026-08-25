use std::path::PathBuf;

use tauri::{AppHandle, Manager, State};
use tauri_plugin_opener::OpenerExt;

use crate::{
    application::ArchitectureService,
    auth::{
        self, AuthState, AuthenticatedProfile, DeviceCodeChallenge,
    },
    domain::ArchitectureStatus,
};

#[tauri::command]
pub fn get_architecture_status(app: AppHandle) -> ArchitectureStatus {
    let helper_path = app
        .path()
        .resolve("resources/NewLaunch.jar", tauri::path::BaseDirectory::Resource)
        .unwrap_or_else(|_| PathBuf::from("resources/NewLaunch.jar"));

    ArchitectureService::status(&helper_path)
}

#[tauri::command]
pub async fn start_microsoft_auth(
    app: AppHandle,
) -> Result<DeviceCodeChallenge, String> {
    let challenge = auth::request_device_code().await?;
    app.opener()
        .open_url(&challenge.verification_uri, None::<&str>)
        .map_err(|_| "Не удалось открыть браузер".to_string())?;
    Ok(challenge)
}

#[tauri::command]
pub async fn complete_microsoft_auth(
    device_code: String,
    interval: u64,
    expires_in: u64,
    state: State<'_, AuthState>,
) -> Result<AuthenticatedProfile, String> {
    let result =
        auth::complete_device_flow(&device_code, interval, expires_in).await?;
    state.replace(
        result.profile.clone(),
        result.minecraft_access_token,
        result.microsoft_refresh_token,
    )?;
    Ok(result.profile)
}

#[tauri::command]
pub fn get_authenticated_profile(
    state: State<'_, AuthState>,
) -> Result<Option<AuthenticatedProfile>, String> {
    state.profile()
}

#[tauri::command]
pub fn sign_out_microsoft(state: State<'_, AuthState>) -> Result<(), String> {
    state.clear()
}
