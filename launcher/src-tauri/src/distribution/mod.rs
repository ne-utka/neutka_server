use std::{
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
    process::{Child, Command},
};

use futures_util::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tauri::{AppHandle, Emitter};
use zip::ZipArchive;

use crate::{
    auth::LaunchIdentity,
    config::Preferences,
    infrastructure::TomlConfigStore,
};

const MANIFEST_FILE: &str = "manifest.json";
const USER_AGENT: &str = "SpringRP-Launcher/0.1";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoteFile {
    pub file: String,
    #[serde(default)]
    pub sha256: String,
    #[serde(default)]
    pub size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OptionalMod {
    pub id: String,
    pub name: String,
    pub file: String,
    #[serde(default)]
    pub sha256: String,
    #[serde(default)]
    pub size: u64,
    #[serde(default)]
    pub default_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LaunchSpec {
    #[serde(default)]
    pub working_directory: String,
    #[serde(default)]
    pub main_jar: String,
    #[serde(default)]
    pub jvm_args: Vec<String>,
    #[serde(default)]
    pub game_args: Vec<String>,
}

/// Which official client the modpack runs on. Absent in older manifests, in
/// which case the modpack version doubles as the Minecraft version.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MinecraftSpec {
    #[serde(default)]
    pub version: String,
    #[serde(default)]
    pub fabric_loader: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DistributionManifest {
    pub version: String,
    pub game: RemoteFile,
    #[serde(default = "default_mods_directory")]
    pub mods_directory: String,
    #[serde(default)]
    pub minecraft: Option<MinecraftSpec>,
    #[serde(default)]
    pub launch: Option<LaunchSpec>,
    #[serde(default)]
    pub optional_mods: Vec<OptionalMod>,
}

fn default_mods_directory() -> String {
    "mods".into()
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct InstallRecord {
    version: String,
    game_sha256: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DistributionStatus {
    pub base_url: String,
    pub remote_version: Option<String>,
    pub installed_version: Option<String>,
    pub needs_download: bool,
    pub optional_mods: Vec<OptionalMod>,
    pub enabled_optional_mod_ids: Vec<String>,
    pub memory_gb: u32,
    pub memory_options: Vec<u32>,
    pub total_memory_gb: u32,
    pub recommended_memory_gb: u32,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgress {
    pub phase: &'static str,
    pub label: String,
    pub received: u64,
    pub total: u64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlayResult {
    pub installed_version: String,
    pub launched: bool,
}

pub fn store(app: &AppHandle) -> Result<TomlConfigStore, String> {
    let app_data_dir = app
        .path_resolver_dir()
        .map_err(|error| format!("Не удалось открыть папку данных: {error}"))?;
    Ok(TomlConfigStore::new(app_data_dir))
}

trait AppDataDir {
    fn path_resolver_dir(&self) -> Result<PathBuf, String>;
}

impl AppDataDir for AppHandle {
    fn path_resolver_dir(&self) -> Result<PathBuf, String> {
        use tauri::Manager;
        self.path()
            .app_data_dir()
            .map_err(|error| error.to_string())
    }
}

pub async fn status(app: &AppHandle) -> DistributionStatus {
    let memory = crate::jvm::profile();
    let store = match store(app) {
        Ok(store) => store,
        Err(error) => {
            return DistributionStatus {
                base_url: Preferences::default().distribution_base_url,
                remote_version: None,
                installed_version: None,
                needs_download: true,
                optional_mods: Vec::new(),
                enabled_optional_mod_ids: Vec::new(),
                memory_gb: memory.recommended_gb,
                memory_options: memory.options,
                total_memory_gb: memory.total_gb,
                recommended_memory_gb: memory.recommended_gb,
                error: Some(error),
            };
        }
    };

    let preferences = store.load_preferences().unwrap_or_default();
    let installed = read_install(&store);
    let mut status = DistributionStatus {
        base_url: preferences.distribution_base_url.clone(),
        remote_version: None,
        installed_version: installed.as_ref().map(|record| record.version.clone()),
        needs_download: true,
        optional_mods: Vec::new(),
        enabled_optional_mod_ids: preferences.optional_mod_ids.clone().unwrap_or_default(),
        memory_gb: memory.clamp((preferences.max_memory_mb / 1024).max(1)),
        memory_options: memory.options.clone(),
        total_memory_gb: memory.total_gb,
        recommended_memory_gb: memory.recommended_gb,
        error: None,
    };

    match fetch_manifest(&preferences.distribution_base_url).await {
        Ok(manifest) => {
            status.remote_version = Some(manifest.version.clone());
            status.optional_mods = manifest.optional_mods.clone();
            status.needs_download = match &installed {
                Some(record) => {
                    record.version != manifest.version
                        || (!manifest.game.sha256.is_empty()
                            && record.game_sha256 != manifest.game.sha256.to_lowercase())
                        || !store.game_dir().is_dir()
                }
                None => true,
            };
            status.enabled_optional_mod_ids =
                resolve_optional_ids(preferences.optional_mod_ids.as_deref(), &manifest);
        }
        Err(error) => status.error = Some(error),
    }

    status
}

pub fn clear_client_install(store: &TomlConfigStore) -> Result<(), String> {
    let game_dir = store.game_dir();
    if game_dir.exists() {
        fs::remove_dir_all(&game_dir).map_err(io_error)?;
    }
    let install = store.app_data_dir().join("install.toml");
    if install.exists() {
        fs::remove_file(&install).map_err(io_error)?;
    }
    let archive = store.cache_dir().join("game.zip");
    if archive.exists() {
        fs::remove_file(&archive).map_err(io_error)?;
    }
    Ok(())
}

pub async fn play(
    app: &AppHandle,
    identity: LaunchIdentity,
    preferences: &mut Preferences,
    force_reinstall: bool,
) -> Result<(PlayResult, Child), String> {
    let store = store(app)?;
    fs::create_dir_all(store.game_dir()).map_err(io_error)?;
    fs::create_dir_all(store.cache_dir()).map_err(io_error)?;

    if force_reinstall {
        emit(
            app,
            "extract",
            "Удаление текущей сборки…",
            0,
            0,
        );
        clear_client_install(&store)?;
        fs::create_dir_all(store.game_dir()).map_err(io_error)?;
        fs::create_dir_all(store.cache_dir()).map_err(io_error)?;
    }

    emit(
        app,
        "manifest",
        "Чтение списка файлов…",
        0,
        0,
    );
    let manifest = fetch_manifest(&preferences.distribution_base_url).await?;
    let enabled_ids =
        resolve_optional_ids(preferences.optional_mod_ids.as_deref(), &manifest);
    preferences.optional_mod_ids = Some(enabled_ids.clone());
    let installed = read_install(&store);
    let needs_game = match &installed {
        Some(record) => {
            record.version != manifest.version
                || (!manifest.game.sha256.is_empty()
                    && record.game_sha256 != manifest.game.sha256.to_lowercase())
                || !store.game_dir().is_dir()
        }
        None => true,
    };

    if needs_game {
        let archive_path = store.cache_dir().join("game.zip");
        download_file(
            app,
            &join_url(&preferences.distribution_base_url, &manifest.game.file),
            &archive_path,
            &manifest.game,
            "game",
            format!("Скачивание сборки {}", manifest.version),
        )
        .await?;
        emit(app, "extract", "Распаковка сборки…", 0, 0);
        extract_zip(&archive_path, &store.game_dir())?;
        write_install(
            &store,
            &InstallRecord {
                version: manifest.version.clone(),
                game_sha256: manifest.game.sha256.to_lowercase(),
            },
        )?;
    }

    sync_optional_mods(app, &store, &manifest, preferences, &enabled_ids).await?;
    let child = launch_game(app, &store, &manifest, preferences, &identity).await?;

    Ok((
        PlayResult {
            installed_version: manifest.version,
            launched: true,
        },
        child,
    ))
}

/// Список включённых модов: сохранённый выбор игрока, а если его ещё нет —
/// набор по умолчанию из манифеста. Пустой сохранённый список остаётся пустым.
fn resolve_optional_ids(
    saved: Option<&[String]>,
    manifest: &DistributionManifest,
) -> Vec<String> {
    match saved {
        Some(ids) => ids.to_vec(),
        None => manifest
            .optional_mods
            .iter()
            .filter(|item| item.default_enabled)
            .map(|item| item.id.clone())
            .collect(),
    }
}

async fn sync_optional_mods(
    app: &AppHandle,
    store: &TomlConfigStore,
    manifest: &DistributionManifest,
    preferences: &Preferences,
    enabled_ids: &[String],
) -> Result<(), String> {
    let mods_dir = store.game_dir().join(&manifest.mods_directory);
    fs::create_dir_all(&mods_dir).map_err(io_error)?;

    let enabled: Vec<&OptionalMod> = manifest
        .optional_mods
        .iter()
        .filter(|item| enabled_ids.iter().any(|id| id == &item.id))
        .collect();

    for (index, item) in enabled.iter().enumerate() {
        let cache_path = store.cache_dir().join(format!("{}.jar", item.id));
        let needs_fetch = !cache_path.is_file()
            || (!item.sha256.is_empty() && file_sha256(&cache_path)? != item.sha256.to_lowercase());
        if needs_fetch {
            download_file(
                app,
                &join_url(&preferences.distribution_base_url, &item.file),
                &cache_path,
                &RemoteFile {
                    file: item.file.clone(),
                    sha256: item.sha256.clone(),
                    size: item.size,
                },
                "mod",
                format!(
                    "Опциональный мод {} ({}/{})",
                    item.name,
                    index + 1,
                    enabled.len().max(1)
                ),
            )
            .await?;
        }
        let dest = mods_dir.join(mod_file_name(item));
        fs::copy(&cache_path, &dest).map_err(io_error)?;
    }

    let managed = read_managed_optional(store);
    let enabled_names: Vec<String> = enabled.iter().map(|item| mod_file_name(item)).collect();
    for name in &managed {
        if !enabled_names.iter().any(|item| item == name) {
            let path = mods_dir.join(name);
            if path.is_file() {
                let _ = fs::remove_file(path);
            }
        }
    }
    write_managed_optional(store, &enabled_names)?;
    Ok(())
}

async fn launch_game(
    app: &AppHandle,
    store: &TomlConfigStore,
    manifest: &DistributionManifest,
    preferences: &Preferences,
    identity: &LaunchIdentity,
) -> Result<Child, String> {
    if let Some(spec) = manifest
        .launch
        .as_ref()
        .filter(|spec| !spec.main_jar.trim().is_empty())
    {
        return launch_custom_jar(store, spec, preferences, identity);
    }

    let minecraft_version = manifest
        .minecraft
        .as_ref()
        .map(|spec| spec.version.trim().to_string())
        .filter(|version| !version.is_empty())
        .unwrap_or_else(|| manifest.version.clone());
    let fabric_loader = manifest
        .minecraft
        .as_ref()
        .map(|spec| spec.fabric_loader.clone())
        .unwrap_or_default();

    // Memory flags come from preferences, so drop any the manifest repeats.
    let extra_jvm: Vec<String> = manifest
        .launch
        .as_ref()
        .map(|spec| spec.jvm_args.clone())
        .unwrap_or_default()
        .iter()
        .filter(|argument| !argument.starts_with("-Xmx") && !argument.starts_with("-Xms"))
        .map(|argument| replace_placeholders(argument, preferences, identity))
        .collect();
    let extra_game: Vec<String> = manifest
        .launch
        .as_ref()
        .map(|spec| spec.game_args.clone())
        .unwrap_or_default()
        .iter()
        .map(|argument| replace_placeholders(argument, preferences, identity))
        .collect();

    let plan = crate::vanilla::prepare(
        app,
        &store.minecraft_dir(),
        &store.game_dir(),
        &minecraft_version,
        &fabric_loader,
        identity,
        preferences,
        &extra_jvm,
        &extra_game,
    )
    .await?;

    emit(app, "launch", format!("Запуск {}", plan.version_name), 0, 0);
    let mut command = Command::new(&plan.java);
    command.current_dir(&plan.game_dir).args(&plan.arguments);
    crate::vanilla::hide_console(&mut command);
    command
        .spawn()
        .map_err(|error| format!("Не удалось запустить игру: {error}"))
}

fn launch_custom_jar(
    store: &TomlConfigStore,
    spec: &LaunchSpec,
    preferences: &Preferences,
    identity: &LaunchIdentity,
) -> Result<Child, String> {
    let working_directory = if spec.working_directory.trim().is_empty() {
        store.game_dir()
    } else {
        store.game_dir().join(&spec.working_directory)
    };

    let java = resolve_java(preferences)?;
    let mut args = Vec::new();
    for arg in &spec.jvm_args {
        args.push(replace_placeholders(arg, preferences, identity));
    }
    if !spec.main_jar.trim().is_empty() {
        args.push("-jar".into());
        args.push(
            working_directory
                .join(&spec.main_jar)
                .to_string_lossy()
                .into_owned(),
        );
    }
    for arg in &spec.game_args {
        args.push(replace_placeholders(arg, preferences, identity));
    }

    Command::new(java)
        .current_dir(&working_directory)
        .args(&args)
        .spawn()
        .map_err(|error| format!("Не удалось запустить игру: {error}"))
}

fn resolve_java(preferences: &Preferences) -> Result<PathBuf, String> {
    if let Some(path) = preferences
        .java_path
        .as_ref()
        .map(PathBuf::from)
        .filter(|path| path.is_file())
    {
        return Ok(path);
    }

    if let Ok(home) = std::env::var("JAVA_HOME") {
        let candidate = PathBuf::from(home).join("bin").join("java.exe");
        if candidate.is_file() {
            return Ok(candidate);
        }
    }

    Ok(PathBuf::from("java"))
}

fn replace_placeholders(
    value: &str,
    preferences: &Preferences,
    identity: &LaunchIdentity,
) -> String {
    value
        .replace("{max_memory_mb}", &preferences.max_memory_mb.to_string())
        .replace("{min_memory_mb}", &preferences.min_memory_mb.to_string())
        .replace("{username}", &identity.name)
        .replace("{uuid}", &identity.uuid)
        .replace("{access_token}", &identity.access_token)
}

pub async fn fetch_manifest(base_url: &str) -> Result<DistributionManifest, String> {
    if base_url.trim().is_empty() {
        return Err("Не задан адрес сборки".into());
    }

    let response = http_client()?
        .get(join_url(base_url, MANIFEST_FILE))
        .send()
        .await
        .map_err(|_| "Нет соединения с сервером раздачи".to_string())?;

    if !response.status().is_success() {
        return Err(format!(
            "manifest.json недоступен ({})",
            response.status()
        ));
    }

    response
        .json()
        .await
        .map_err(|_| "manifest.json повреждён или имеет неверный формат".to_string())
}

async fn download_file(
    app: &AppHandle,
    url: &str,
    dest: &Path,
    remote: &RemoteFile,
    phase: &'static str,
    label: String,
) -> Result<(), String> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(io_error)?;
    }

    let response = http_client()?
        .get(url)
        .send()
        .await
        .map_err(|_| format!("Не удалось скачать {url}"))?;

    if !response.status().is_success() {
        return Err(format!("Файл недоступен: {url} ({})", response.status()));
    }

    let total = response
        .content_length()
        .filter(|value| *value > 0)
        .unwrap_or(remote.size);
    let mut received = 0_u64;
    let mut hasher = Sha256::new();
    let temp = dest.with_extension("part");
    let mut file = File::create(&temp).map_err(io_error)?;
    let mut stream = response.bytes_stream();

    emit(app, phase, &label, 0, total);
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|_| "Загрузка оборвалась".to_string())?;
        received += chunk.len() as u64;
        hasher.update(&chunk);
        file.write_all(&chunk).map_err(io_error)?;
        emit(app, phase, &label, received, total);
    }
    file.flush().map_err(io_error)?;
    drop(file);

    let digest = hex::encode(hasher.finalize());
    if !remote.sha256.is_empty() && digest != remote.sha256.to_lowercase() {
        let _ = fs::remove_file(&temp);
        return Err(format!("Контрольная сумма не совпала: {}", remote.file));
    }

    fs::rename(&temp, dest).map_err(io_error)?;
    Ok(())
}

fn extract_zip(archive_path: &Path, dest: &Path) -> Result<(), String> {
    if dest.exists() {
        fs::remove_dir_all(dest).map_err(io_error)?;
    }
    fs::create_dir_all(dest).map_err(io_error)?;

    let file = File::open(archive_path).map_err(io_error)?;
    let mut archive = ZipArchive::new(file).map_err(|_| "Архив сборки повреждён".to_string())?;

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .map_err(|_| "Не удалось прочитать архив сборки".to_string())?;
        let Some(relative) = entry.enclosed_name() else {
            continue;
        };
        if relative.components().any(|component| {
            matches!(component.as_os_str().to_str(), Some("__MACOSX" | ".DS_Store"))
        }) {
            continue;
        }

        let out_path = dest.join(relative);
        if entry.is_dir() {
            fs::create_dir_all(&out_path).map_err(io_error)?;
            continue;
        }
        if let Some(parent) = out_path.parent() {
            fs::create_dir_all(parent).map_err(io_error)?;
        }
        let mut outfile = File::create(&out_path).map_err(io_error)?;
        io::copy(&mut entry, &mut outfile).map_err(io_error)?;
    }

    Ok(())
}

fn read_install(store: &TomlConfigStore) -> Option<InstallRecord> {
    let path = store.app_data_dir().join("install.toml");
    let contents = fs::read_to_string(path).ok()?;
    toml::from_str(&contents).ok()
}

fn write_install(store: &TomlConfigStore, record: &InstallRecord) -> Result<(), String> {
    fs::create_dir_all(store.app_data_dir()).map_err(io_error)?;
    let contents =
        toml::to_string_pretty(record).map_err(|_| "Не удалось сохранить состояние установки")?;
    fs::write(store.app_data_dir().join("install.toml"), contents).map_err(io_error)
}

fn read_managed_optional(store: &TomlConfigStore) -> Vec<String> {
    let path = store.app_data_dir().join("optional-mods.json");
    fs::read_to_string(path)
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

fn write_managed_optional(store: &TomlConfigStore, names: &[String]) -> Result<(), String> {
    let contents = serde_json::to_vec_pretty(names)
        .map_err(|_| "Не удалось сохранить список опциональных модов")?;
    fs::write(store.app_data_dir().join("optional-mods.json"), contents).map_err(io_error)
}

fn mod_file_name(item: &OptionalMod) -> String {
    Path::new(&item.file)
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| format!("{}.jar", item.id))
}

fn file_sha256(path: &Path) -> Result<String, String> {
    let bytes = fs::read(path).map_err(io_error)?;
    Ok(hex::encode(Sha256::digest(bytes)))
}

pub(crate) fn http_client() -> Result<Client, String> {
    Client::builder()
        .user_agent(USER_AGENT)
        .connect_timeout(std::time::Duration::from_secs(20))
        .build()
        .map_err(|_| "Не удалось создать HTTP-клиент".to_string())
}

fn join_url(base: &str, path: &str) -> String {
    format!(
        "{}/{}",
        base.trim().trim_end_matches('/'),
        path.trim().trim_start_matches('/')
    )
}

pub(crate) fn emit(
    app: &AppHandle,
    phase: &'static str,
    label: impl Into<String>,
    received: u64,
    total: u64,
) {
    let _ = app.emit(
        "download-progress",
        DownloadProgress {
            phase,
            label: label.into(),
            received,
            total,
        },
    );
}

pub(crate) fn io_error(error: io::Error) -> String {
    format!("Ошибка файловой системы: {error}")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest() -> DistributionManifest {
        DistributionManifest {
            version: "26.1.2".into(),
            game: RemoteFile {
                file: "pack.zip".into(),
                sha256: String::new(),
                size: 0,
            },
            mods_directory: default_mods_directory(),
            minecraft: None,
            launch: None,
            optional_mods: vec![
                OptionalMod {
                    id: "iris".into(),
                    name: "Iris".into(),
                    file: "optional/iris.jar".into(),
                    sha256: String::new(),
                    size: 0,
                    default_enabled: true,
                },
                OptionalMod {
                    id: "chatpatches".into(),
                    name: "Chat Patches".into(),
                    file: "optional/chatpatches.jar".into(),
                    sha256: String::new(),
                    size: 0,
                    default_enabled: false,
                },
            ],
        }
    }

    #[test]
    fn first_launch_takes_the_defaults_from_the_manifest() {
        assert_eq!(resolve_optional_ids(None, &manifest()), vec!["iris"]);
    }

    #[test]
    fn turning_everything_off_is_respected_and_not_reset_to_defaults() {
        let chosen: Vec<String> = Vec::new();
        assert!(resolve_optional_ids(Some(&chosen), &manifest()).is_empty());
    }

    #[test]
    fn an_explicit_choice_wins_over_the_defaults() {
        let chosen = vec!["chatpatches".to_string()];
        assert_eq!(
            resolve_optional_ids(Some(&chosen), &manifest()),
            vec!["chatpatches"]
        );
    }
}

pub fn open_game_folder(app: &AppHandle) -> Result<(), String> {
    use tauri_plugin_opener::OpenerExt;

    let store = store(app)?;
    fs::create_dir_all(store.game_dir()).map_err(io_error)?;
    app.opener()
        .open_path(store.game_dir().to_string_lossy().as_ref(), None::<&str>)
        .map_err(|_| "Не удалось открыть папку игры".to_string())
}
