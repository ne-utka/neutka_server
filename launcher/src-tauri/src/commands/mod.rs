use std::path::PathBuf;

use tauri::{AppHandle, Manager, State};
use tauri_plugin_opener::OpenerExt;

use crate::{
    application::ArchitectureService,
    auth::{self, AuthState, AuthenticatedProfile, DeviceCodeChallenge, NicknameChallenge},
    distribution::{self, DistributionStatus, PlayResult},
    domain::ArchitectureStatus,
    launch_state::{LaunchState, LaunchStatus},
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
pub async fn start_nickname_auth(nick: String) -> Result<NicknameChallenge, String> {
    auth::start_nickname_auth(&nick).await
}

#[tauri::command]
pub async fn complete_nickname_auth(
    code: String,
    expires_in: u64,
) -> Result<AuthenticatedProfile, String> {
    let nick = auth::complete_nickname_auth(&code, expires_in).await?;
    Ok(AuthenticatedProfile {
        id: "0".into(),
        name: nick,
    })
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

#[tauri::command]
pub async fn get_distribution_status(app: AppHandle) -> DistributionStatus {
    distribution::status(&app).await
}

#[tauri::command]
pub fn set_optional_mods(app: AppHandle, ids: Vec<String>) -> Result<(), String> {
    let store = distribution::store(&app)?;
    let mut preferences = store
        .load_preferences()
        .map_err(|error| error.to_string())?;
    preferences.optional_mod_ids = Some(ids);
    store
        .save_preferences(&preferences)
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub fn set_memory_gb(app: AppHandle, memory_gb: u32) -> Result<(), String> {
    let profile = crate::jvm::profile();
    if !profile.allows(memory_gb) {
        return Err(format!(
            "Доступно не больше {} ГБ: в системе {} ГБ",
            profile.options.last().copied().unwrap_or(2),
            profile.total_gb
        ));
    }

    let store = distribution::store(&app)?;
    let mut preferences = store
        .load_preferences()
        .map_err(|error| error.to_string())?;
    preferences.max_memory_mb = memory_gb * 1024;
    preferences.min_memory_mb = preferences.max_memory_mb;
    store
        .save_preferences(&preferences)
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub fn get_launch_status(state: State<'_, LaunchState>) -> LaunchStatus {
    state.status()
}

#[tauri::command]
pub async fn play_game(
    app: AppHandle,
    nickname: String,
    auth_state: State<'_, AuthState>,
    launch_state: State<'_, LaunchState>,
) -> Result<PlayResult, String> {
    let permit = launch_state.try_acquire(app.clone())?;
    let identity = auth_state.launch_identity(&nickname)?;
    let store = distribution::store(&app)?;
    let mut preferences = store
        .load_preferences()
        .map_err(|error| error.to_string())?;
    let (result, child) =
        distribution::play(&app, identity, &mut preferences, false).await?;
    let _ = store.save_preferences(&preferences);
    permit.track_game(child);
    Ok(result)
}

#[tauri::command]
pub async fn reinstall_game(
    app: AppHandle,
    nickname: String,
    auth_state: State<'_, AuthState>,
    launch_state: State<'_, LaunchState>,
) -> Result<PlayResult, String> {
    if launch_state.status().game_running {
        return Err("Закройте игру, чтобы переустановить клиент".into());
    }

    let permit = launch_state.try_acquire(app.clone())?;
    let identity = auth_state.launch_identity(&nickname)?;
    let store = distribution::store(&app)?;
    let mut preferences = store
        .load_preferences()
        .map_err(|error| error.to_string())?;
    let (result, child) =
        distribution::play(&app, identity, &mut preferences, true).await?;
    let _ = store.save_preferences(&preferences);
    permit.track_game(child);
    Ok(result)
}

#[tauri::command]
pub fn open_game_folder(app: AppHandle) -> Result<(), String> {
    distribution::open_game_folder(&app)
}
