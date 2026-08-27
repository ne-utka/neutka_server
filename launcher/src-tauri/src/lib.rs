pub mod application;
pub mod auth;
pub mod commands;
pub mod config;
pub mod distribution;
pub mod domain;
pub mod infrastructure;
pub mod jvm;
pub mod launcher;
pub mod launch_state;
pub mod vanilla;

use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(auth::AuthState::default())
        .manage(launch_state::LaunchState::default())
        .setup(|app| {
            let icon =
                tauri::image::Image::from_bytes(include_bytes!("../icons/icon.png"))?;
            app.get_webview_window("main")
                .expect("main window must exist")
                .set_icon(icon)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_architecture_status,
            commands::start_microsoft_auth,
            commands::complete_microsoft_auth,
            commands::start_nickname_auth,
            commands::complete_nickname_auth,
            commands::get_authenticated_profile,
            commands::sign_out_microsoft,
            commands::get_distribution_status,
            commands::set_optional_mods,
            commands::set_memory_gb,
            commands::get_launch_status,
            commands::play_game,
            commands::reinstall_game,
            commands::open_game_folder
        ])
        .run(tauri::generate_context!())
        .expect("failed to run SpringRP");
}
