use std::path::PathBuf;

use tauri::{AppHandle, Manager, State};
use tauri_plugin_opener::OpenerExt;

use crate::{
    application::ArchitectureService,
    auth::{
        self, AuthState, AuthenticatedProfile, DeviceCodeChallenge, MicrosoftRestoreError,
        NicknameChallenge,
    },
    config::{SecretString, Session},
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
    app: AppHandle,
    device_code: String,
    interval: u64,
    expires_in: u64,
    state: State<'_, AuthState>,
) -> Result<AuthenticatedProfile, String> {
    let result =
        auth::complete_device_flow(&device_code, interval, expires_in).await?;
    persist_microsoft_session(&app, &state, &result)?;
    Ok(result.profile)
}

#[tauri::command]
pub async fn start_nickname_auth(nick: String) -> Result<NicknameChallenge, String> {
    auth::start_nickname_auth(&nick).await
}

#[tauri::command]
pub async fn complete_nickname_auth(
    app: AppHandle,
    code: String,
    expires_in: u64,
    state: State<'_, AuthState>,
) -> Result<AuthenticatedProfile, String> {
    let nick = auth::complete_nickname_auth(&code, expires_in).await?;
    let profile = state.replace_telegram(&nick)?;
    let store = distribution::store(&app)?;
    if let Err(error) = store.save_session(&Session::Telegram {
        player_name: nick,
    }) {
        let _ = state.clear();
        return Err(persist_error(error));
    }
    Ok(profile)
}

#[tauri::command]
pub async fn get_authenticated_profile(
    app: AppHandle,
    state: State<'_, AuthState>,
) -> Result<Option<AuthenticatedProfile>, String> {
    restore_auth(&app, &state).await
}

#[tauri::command]
pub fn sign_out(app: AppHandle, state: State<'_, AuthState>) -> Result<(), String> {
    state.clear()?;
    distribution::store(&app)?
        .clear_session()
        .map_err(persist_error)
}

async fn restore_auth(
    app: &AppHandle,
    state: &AuthState,
) -> Result<Option<AuthenticatedProfile>, String> {
    if let Some(profile) = state.profile()? {
        return Ok(Some(profile));
    }

    let store = distribution::store(app)?;
    let session = match store.load_session() {
        Ok(session) => session,
        Err(_) => {
            let _ = store.clear_session();
            return Ok(None);
        }
    };
    let Some(session) = session else {
        return Ok(None);
    };

    match session {
        Session::Telegram { player_name } => {
            if !auth::is_minecraft_nick(&player_name) {
                let _ = store.clear_session();
                return Ok(None);
            }
            match state.replace_telegram(&player_name) {
                Ok(profile) => Ok(Some(profile)),
                Err(_) => {
                    let _ = store.clear_session();
                    Ok(None)
                }
            }
        }
        Session::Microsoft {
            profile_id,
            player_name,
            access_token,
            refresh_token,
        } => {
            match auth::restore_microsoft_session(
                access_token.expose_secret(),
                refresh_token
                    .as_ref()
                    .map(SecretString::expose_secret),
            )
            .await
            {
                Ok(result) => {
                    persist_microsoft_session(app, state, &result)?;
                    Ok(Some(result.profile))
                }
                Err(MicrosoftRestoreError::Expired) => {
                    let _ = state.clear();
                    let _ = store.clear_session();
                    Ok(None)
                }
                Err(MicrosoftRestoreError::Unavailable) => {
                    if player_name.is_empty() || profile_id.is_empty() {
                        return Ok(None);
                    }
                    state.replace(
                        AuthenticatedProfile {
                            id: profile_id,
                            name: player_name,
                            kind: auth::AuthProvider::Microsoft,
                        },
                        access_token.expose_secret().to_string(),
                        refresh_token.map(|token| token.expose_secret().to_string()),
                    )?;
                    state.profile()
                }
            }
        }
    }
}

fn persist_microsoft_session(
    app: &AppHandle,
    state: &AuthState,
    result: &auth::MicrosoftAuthResult,
) -> Result<(), String> {
    state.replace(
        result.profile.clone(),
        result.minecraft_access_token.clone(),
        result.microsoft_refresh_token.clone(),
    )?;
    let store = distribution::store(app)?;
    let saved = store.save_session(&Session::Microsoft {
        profile_id: result.profile.id.clone(),
        player_name: result.profile.name.clone(),
        access_token: SecretString::new(result.minecraft_access_token.clone()),
        refresh_token: result
            .microsoft_refresh_token
            .clone()
            .map(SecretString::new),
    });
    if let Err(error) = saved {
        let _ = state.clear();
        return Err(persist_error(error));
    }
    Ok(())
}

fn persist_error(_: crate::config::ConfigError) -> String {
    "Не удалось сохранить сессию входа".into()
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
    let _ = nickname;
    restore_auth(&app, &auth_state).await?;
    let permit = launch_state.try_acquire(app.clone())?;
    let identity = auth_state.launch_identity()?;
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

    let _ = nickname;
    restore_auth(&app, &auth_state).await?;
    let permit = launch_state.try_acquire(app.clone())?;
    let identity = auth_state.launch_identity()?;
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
