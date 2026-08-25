//! Installs the official Minecraft client and the Fabric loader from the
//! vendor metadata services (`piston-meta.mojang.com`, `meta.fabricmc.net`)
//! and turns them into a runnable command line.

use std::{
    collections::HashMap,
    fs::{self, File},
    io,
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
};

use futures_util::StreamExt;
use reqwest::Client;
use serde::Deserialize;
use serde_json::Value;
use sha1::{Digest, Sha1};
use tauri::AppHandle;
use zip::ZipArchive;

use crate::{
    auth::LaunchIdentity,
    config::Preferences,
    distribution::{emit, http_client, io_error},
};

const VERSION_MANIFEST_URL: &str =
    "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";
const JAVA_RUNTIME_MANIFEST_URL: &str =
    "https://piston-meta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json";
const RESOURCES_URL: &str = "https://resources.download.minecraft.net";
const FABRIC_META_URL: &str = "https://meta.fabricmc.net/v2/versions/loader";
const PARALLEL_DOWNLOADS: usize = 16;

#[derive(Debug, Clone)]
pub struct LaunchPlan {
    pub java: PathBuf,
    pub arguments: Vec<String>,
    pub game_dir: PathBuf,
    pub version_name: String,
}

#[derive(Deserialize)]
struct VersionManifest {
    versions: Vec<VersionEntry>,
}

#[derive(Deserialize)]
struct VersionEntry {
    id: String,
    url: String,
}

#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
struct VersionJson {
    #[serde(default)]
    id: String,
    #[serde(default)]
    asset_index: Option<AssetIndexRef>,
    #[serde(default)]
    downloads: HashMap<String, Artifact>,
    #[serde(default)]
    libraries: Vec<Library>,
    #[serde(default)]
    main_class: String,
    #[serde(default)]
    arguments: Arguments,
    #[serde(default)]
    java_version: Option<JavaVersion>,
}

#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
struct AssetIndexRef {
    id: String,
    #[serde(default)]
    sha1: String,
    url: String,
}

#[derive(Deserialize, Clone, Default)]
struct Artifact {
    #[serde(default)]
    path: String,
    #[serde(default)]
    sha1: String,
    #[serde(default)]
    size: u64,
    #[serde(default)]
    url: String,
}

#[derive(Deserialize, Clone)]
struct Library {
    name: String,
    #[serde(default)]
    downloads: Option<LibraryDownloads>,
    /// Maven root used by Fabric metadata, which omits `downloads`.
    #[serde(default)]
    url: Option<String>,
    #[serde(default)]
    sha1: Option<String>,
    #[serde(default)]
    size: Option<u64>,
    #[serde(default)]
    rules: Vec<Rule>,
}

#[derive(Deserialize, Clone, Default)]
struct LibraryDownloads {
    #[serde(default)]
    artifact: Option<Artifact>,
}

#[derive(Deserialize, Clone, Default)]
struct Rule {
    #[serde(default)]
    action: String,
    #[serde(default)]
    os: Option<OsRule>,
    #[serde(default)]
    features: Option<serde_json::Map<String, Value>>,
}

#[derive(Deserialize, Clone, Default)]
struct OsRule {
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    arch: Option<String>,
}

#[derive(Deserialize, Clone, Default)]
struct Arguments {
    #[serde(default)]
    game: Vec<Value>,
    #[serde(default)]
    jvm: Vec<Value>,
}

#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
struct JavaVersion {
    #[serde(default)]
    component: String,
    #[serde(default)]
    major_version: u32,
}

#[derive(Deserialize)]
struct FabricLoaderEntry {
    version: String,
    #[serde(default)]
    stable: bool,
}

#[derive(Deserialize)]
struct AssetIndexFile {
    #[serde(default)]
    objects: HashMap<String, AssetObject>,
}

#[derive(Deserialize)]
struct AssetObject {
    hash: String,
    #[serde(default)]
    size: u64,
}

#[derive(Deserialize)]
struct RuntimeFileEntry {
    #[serde(rename = "type")]
    kind: String,
    #[serde(default)]
    downloads: HashMap<String, Artifact>,
    #[serde(default)]
    executable: bool,
}

#[derive(Deserialize)]
struct RuntimeManifest {
    #[serde(default)]
    files: HashMap<String, RuntimeFileEntry>,
}

#[derive(Deserialize)]
struct RuntimeComponent {
    manifest: Artifact,
}

struct DownloadItem {
    url: String,
    path: PathBuf,
    sha1: String,
    size: u64,
}

/// Downloads everything the client needs and returns the command line for it.
#[allow(clippy::too_many_arguments)]
pub async fn prepare(
    app: &AppHandle,
    mc_root: &Path,
    game_dir: &Path,
    minecraft_version: &str,
    fabric_loader: &str,
    identity: &LaunchIdentity,
    preferences: &Preferences,
    extra_jvm: &[String],
    extra_game: &[String],
) -> Result<LaunchPlan, String> {
    let client = http_client()?;
    fs::create_dir_all(mc_root).map_err(io_error)?;

    emit(app, "meta", "Чтение метаданных Minecraft…", 0, 0);
    let version = load_version_json(&client, mc_root, minecraft_version).await?;
    let loader = resolve_loader_version(&client, fabric_loader).await?;
    let profile =
        load_fabric_profile(&client, mc_root, minecraft_version, &loader).await?;

    let java = resolve_java(
        app,
        &client,
        mc_root,
        version.java_version.as_ref(),
        preferences.java_path.as_deref(),
    )
    .await?;

    let libraries = merge_libraries(&profile, &version);
    let libraries_dir = mc_root.join("libraries");
    let version_dir = mc_root.join("versions").join(minecraft_version);
    let natives_dir = version_dir.join("natives");
    let client_jar = version_dir.join(format!("{minecraft_version}.jar"));

    let mut downloads = Vec::new();
    let mut classpath = Vec::new();
    let mut natives = Vec::new();

    if let Some(artifact) = version.downloads.get("client") {
        downloads.push(DownloadItem {
            url: artifact.url.clone(),
            path: client_jar.clone(),
            sha1: artifact.sha1.clone(),
            size: artifact.size,
        });
    } else {
        return Err("Mojang не отдал клиент для этой версии".into());
    }

    for library in &libraries {
        let Some(item) = library_artifact(library, &libraries_dir) else {
            continue;
        };
        if is_native(&library.name) {
            natives.push(item.path.clone());
        }
        classpath.push(item.path.clone());
        downloads.push(item);
    }
    classpath.push(client_jar.clone());

    emit(app, "client", "Клиент и библиотеки…", 0, downloads.len() as u64);
    download_many(app, &client, downloads, "client", "Клиент и библиотеки").await?;

    if !natives.is_empty() {
        emit(app, "natives", "Распаковка нативных библиотек…", 0, 0);
        fs::create_dir_all(&natives_dir).map_err(io_error)?;
        for jar in &natives {
            extract_natives(jar, &natives_dir)?;
        }
    }

    let assets_dir = mc_root.join("assets");
    let asset_index = version
        .asset_index
        .as_ref()
        .ok_or_else(|| "В метаданных версии нет индекса ресурсов".to_string())?;
    let objects = load_asset_index(&client, &assets_dir, asset_index).await?;
    // Several logical assets can share one hash; download each blob once.
    let mut seen_hashes = std::collections::HashSet::new();
    let asset_items: Vec<DownloadItem> = objects
        .into_iter()
        .filter(|(_, object)| seen_hashes.insert(object.hash.clone()))
        .filter_map(|(_, object)| {
            let prefix = object.hash.get(0..2)?.to_string();
            Some(DownloadItem {
                url: format!("{RESOURCES_URL}/{prefix}/{}", object.hash),
                path: assets_dir.join("objects").join(prefix).join(&object.hash),
                sha1: object.hash,
                size: object.size,
            })
        })
        .collect();

    emit(app, "assets", "Ресурсы игры…", 0, asset_items.len() as u64);
    download_many(app, &client, asset_items, "assets", "Ресурсы игры").await?;

    let classpath_value = classpath
        .iter()
        .map(|path| path.to_string_lossy().into_owned())
        .collect::<Vec<_>>()
        .join(CLASSPATH_SEPARATOR);

    let mut variables: HashMap<&str, String> = HashMap::new();
    variables.insert("auth_player_name", identity.name.clone());
    variables.insert("version_name", profile.id.clone());
    variables.insert("game_directory", game_dir.to_string_lossy().into_owned());
    variables.insert("assets_root", assets_dir.to_string_lossy().into_owned());
    variables.insert("game_assets", assets_dir.to_string_lossy().into_owned());
    variables.insert("assets_index_name", asset_index.id.clone());
    variables.insert("auth_uuid", identity.uuid.replace('-', ""));
    variables.insert("auth_access_token", identity.access_token.clone());
    variables.insert("auth_session", identity.access_token.clone());
    variables.insert("clientid", String::new());
    variables.insert("auth_xuid", String::new());
    variables.insert("user_type", user_type(identity).into());
    variables.insert("version_type", "release".into());
    variables.insert(
        "natives_directory",
        natives_dir.to_string_lossy().into_owned(),
    );
    variables.insert(
        "library_directory",
        libraries_dir.to_string_lossy().into_owned(),
    );
    variables.insert("launcher_name", "SpringRP".into());
    variables.insert("launcher_version", env!("CARGO_PKG_VERSION").into());
    variables.insert("classpath", classpath_value);
    variables.insert("classpath_separator", CLASSPATH_SEPARATOR.into());

    let mut arguments = crate::jvm::performance_arguments(preferences.max_memory_mb);
    collect_arguments(&version.arguments.jvm, &variables, &mut arguments);
    collect_arguments(&profile.arguments.jvm, &variables, &mut arguments);
    for argument in extra_jvm {
        arguments.push(substitute(argument, &variables));
    }

    let main_class = if profile.main_class.is_empty() {
        version.main_class.clone()
    } else {
        profile.main_class.clone()
    };
    if main_class.is_empty() {
        return Err("В метаданных нет главного класса".into());
    }
    arguments.push(main_class);

    collect_arguments(&version.arguments.game, &variables, &mut arguments);
    collect_arguments(&profile.arguments.game, &variables, &mut arguments);
    for argument in extra_game {
        arguments.push(substitute(argument, &variables));
    }

    fs::create_dir_all(game_dir).map_err(io_error)?;

    Ok(LaunchPlan {
        java,
        arguments,
        game_dir: game_dir.to_path_buf(),
        version_name: profile.id.clone(),
    })
}

async fn load_version_json(
    client: &Client,
    mc_root: &Path,
    minecraft_version: &str,
) -> Result<VersionJson, String> {
    let cache = mc_root
        .join("versions")
        .join(minecraft_version)
        .join(format!("{minecraft_version}.json"));

    if let Some(cached) = read_json::<VersionJson>(&cache) {
        return Ok(cached);
    }

    let manifest: VersionManifest = client
        .get(VERSION_MANIFEST_URL)
        .send()
        .await
        .map_err(|_| "Нет соединения с сервисом версий Mojang".to_string())?
        .json()
        .await
        .map_err(|_| "Mojang вернул неизвестный формат списка версий".to_string())?;

    let entry = manifest
        .versions
        .into_iter()
        .find(|item| item.id == minecraft_version)
        .ok_or_else(|| format!("Mojang не знает версию {minecraft_version}"))?;

    let body = client
        .get(&entry.url)
        .send()
        .await
        .map_err(|_| "Не удалось скачать описание версии".to_string())?
        .text()
        .await
        .map_err(|_| "Описание версии повреждено".to_string())?;

    write_text(&cache, &body)?;
    serde_json::from_str(&body)
        .map_err(|_| "Описание версии имеет неизвестный формат".to_string())
}

async fn resolve_loader_version(client: &Client, requested: &str) -> Result<String, String> {
    if !requested.trim().is_empty() {
        return Ok(requested.trim().to_string());
    }

    let loaders: Vec<FabricLoaderEntry> = client
        .get(FABRIC_META_URL)
        .send()
        .await
        .map_err(|_| "Нет соединения с Fabric".to_string())?
        .json()
        .await
        .map_err(|_| "Fabric вернул неизвестный формат".to_string())?;

    loaders
        .into_iter()
        .find(|entry| entry.stable)
        .map(|entry| entry.version)
        .ok_or_else(|| "У Fabric нет стабильной версии загрузчика".to_string())
}

async fn load_fabric_profile(
    client: &Client,
    mc_root: &Path,
    minecraft_version: &str,
    loader: &str,
) -> Result<VersionJson, String> {
    let id = format!("fabric-loader-{loader}-{minecraft_version}");
    let cache = mc_root.join("versions").join(&id).join(format!("{id}.json"));

    if let Some(cached) = read_json::<VersionJson>(&cache) {
        return Ok(cached);
    }

    let url = format!("{FABRIC_META_URL}/{minecraft_version}/{loader}/profile/json");
    let response = client
        .get(&url)
        .send()
        .await
        .map_err(|_| "Нет соединения с Fabric".to_string())?;

    if !response.status().is_success() {
        return Err(format!(
            "Fabric {loader} не поддерживает Minecraft {minecraft_version}"
        ));
    }

    let body = response
        .text()
        .await
        .map_err(|_| "Fabric вернул повреждённый профиль".to_string())?;

    write_text(&cache, &body)?;
    serde_json::from_str(&body)
        .map_err(|_| "Профиль Fabric имеет неизвестный формат".to_string())
}

async fn load_asset_index(
    client: &Client,
    assets_dir: &Path,
    reference: &AssetIndexRef,
) -> Result<HashMap<String, AssetObject>, String> {
    let cache = assets_dir
        .join("indexes")
        .join(format!("{}.json", reference.id));

    if let Some(cached) = read_json::<AssetIndexFile>(&cache) {
        return Ok(cached.objects);
    }

    let body = client
        .get(&reference.url)
        .send()
        .await
        .map_err(|_| "Не удалось скачать индекс ресурсов".to_string())?
        .text()
        .await
        .map_err(|_| "Индекс ресурсов повреждён".to_string())?;

    if !reference.sha1.is_empty() && sha1_hex(body.as_bytes()) != reference.sha1 {
        return Err("Индекс ресурсов не прошёл проверку целостности".into());
    }

    write_text(&cache, &body)?;
    let parsed: AssetIndexFile = serde_json::from_str(&body)
        .map_err(|_| "Индекс ресурсов имеет неизвестный формат".to_string())?;
    Ok(parsed.objects)
}

fn merge_libraries(profile: &VersionJson, version: &VersionJson) -> Vec<Library> {
    let mut seen: Vec<String> = Vec::new();
    let mut merged = Vec::new();

    for library in profile.libraries.iter().chain(version.libraries.iter()) {
        if !rules_allow(&library.rules) {
            continue;
        }
        let key = dedup_key(&library.name);
        if seen.contains(&key) {
            continue;
        }
        seen.push(key);
        merged.push(library.clone());
    }

    merged
}

fn library_artifact(library: &Library, libraries_dir: &Path) -> Option<DownloadItem> {
    if let Some(artifact) = library
        .downloads
        .as_ref()
        .and_then(|downloads| downloads.artifact.as_ref())
        .filter(|artifact| !artifact.url.is_empty())
    {
        let relative = if artifact.path.is_empty() {
            maven_path(&library.name)?
        } else {
            artifact.path.clone()
        };
        return Some(DownloadItem {
            url: artifact.url.clone(),
            path: libraries_dir.join(relative),
            sha1: artifact.sha1.clone(),
            size: artifact.size,
        });
    }

    let relative = maven_path(&library.name)?;
    let base = library.url.clone()?;
    Some(DownloadItem {
        url: format!("{}/{relative}", base.trim_end_matches('/')),
        path: libraries_dir.join(relative),
        sha1: library.sha1.clone().unwrap_or_default(),
        size: library.size.unwrap_or_default(),
    })
}

fn maven_path(name: &str) -> Option<String> {
    let mut parts = name.split(':');
    let group = parts.next()?;
    let artifact = parts.next()?;
    let version = parts.next()?;
    let classifier = parts.next();

    let mut file = format!("{artifact}-{version}");
    if let Some(classifier) = classifier {
        file.push('-');
        file.push_str(classifier);
    }
    file.push_str(".jar");

    Some(format!(
        "{}/{artifact}/{version}/{file}",
        group.replace('.', "/")
    ))
}

fn dedup_key(name: &str) -> String {
    let parts: Vec<&str> = name.split(':').collect();
    match parts.len() {
        0 | 1 => name.to_string(),
        2 => format!("{}:{}", parts[0], parts[1]),
        _ => format!(
            "{}:{}:{}",
            parts[0],
            parts[1],
            parts.get(3).copied().unwrap_or_default()
        ),
    }
}

fn is_native(name: &str) -> bool {
    name.split(':')
        .nth(3)
        .is_some_and(|classifier| classifier.starts_with("natives"))
}

fn rules_allow(rules: &[Rule]) -> bool {
    if rules.is_empty() {
        return true;
    }

    let mut allowed = false;
    for rule in rules {
        // Feature flags (demo, custom resolution, quick play) are never set.
        if rule.features.as_ref().is_some_and(|map| !map.is_empty()) {
            continue;
        }
        let matches = match &rule.os {
            None => true,
            Some(os) => {
                os.name.as_deref().is_none_or(|name| name == CURRENT_OS)
                    && os.arch.as_deref().is_none_or(|arch| arch == CURRENT_ARCH)
            }
        };
        if matches {
            allowed = rule.action == "allow";
        }
    }
    allowed
}

fn collect_arguments(
    items: &[Value],
    variables: &HashMap<&str, String>,
    out: &mut Vec<String>,
) {
    for item in items {
        match item {
            Value::String(value) => out.push(substitute(value, variables)),
            Value::Object(map) => {
                let rules: Vec<Rule> = map
                    .get("rules")
                    .cloned()
                    .and_then(|value| serde_json::from_value(value).ok())
                    .unwrap_or_default();
                if !rules_allow(&rules) {
                    continue;
                }
                match map.get("value") {
                    Some(Value::String(value)) => out.push(substitute(value, variables)),
                    Some(Value::Array(values)) => {
                        for value in values {
                            if let Some(value) = value.as_str() {
                                out.push(substitute(value, variables));
                            }
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        }
    }
}

fn substitute(value: &str, variables: &HashMap<&str, String>) -> String {
    let mut result = value.to_string();
    for (key, replacement) in variables {
        let placeholder = format!("${{{key}}}");
        if result.contains(&placeholder) {
            result = result.replace(&placeholder, replacement);
        }
    }
    result
}

fn user_type(identity: &LaunchIdentity) -> &'static str {
    if identity.access_token == "0" {
        "legacy"
    } else {
        "msa"
    }
}

async fn download_many(
    app: &AppHandle,
    client: &Client,
    items: Vec<DownloadItem>,
    phase: &'static str,
    label: &str,
) -> Result<(), String> {
    let total = items.len() as u64;
    if total == 0 {
        return Ok(());
    }

    let done = Arc::new(AtomicU64::new(0));
    let mut stream = futures_util::stream::iter(items.into_iter().map(|item| {
        let client = client.clone();
        let app = app.clone();
        let done = Arc::clone(&done);
        let label = label.to_string();
        async move {
            let result = download_one(&client, &item).await;
            let finished = done.fetch_add(1, Ordering::Relaxed) + 1;
            if finished % 10 == 0 || finished == total {
                emit(
                    &app,
                    phase,
                    format!("{label} {finished}/{total}"),
                    finished,
                    total,
                );
            }
            result
        }
    }))
    .buffer_unordered(PARALLEL_DOWNLOADS);

    while let Some(result) = stream.next().await {
        result?;
    }
    Ok(())
}

async fn download_one(client: &Client, item: &DownloadItem) -> Result<(), String> {
    if is_present(&item.path, item.size) {
        return Ok(());
    }
    if let Some(parent) = item.path.parent() {
        fs::create_dir_all(parent).map_err(io_error)?;
    }

    let response = client
        .get(&item.url)
        .send()
        .await
        .map_err(|_| format!("Не удалось скачать {}", file_label(&item.path)))?;

    if !response.status().is_success() {
        return Err(format!(
            "{} недоступен ({})",
            file_label(&item.path),
            response.status()
        ));
    }

    let bytes = response
        .bytes()
        .await
        .map_err(|_| format!("Загрузка прервана: {}", file_label(&item.path)))?;

    if !item.sha1.is_empty() && sha1_hex(&bytes) != item.sha1.to_lowercase() {
        return Err(format!(
            "Файл не прошёл проверку целостности: {}",
            file_label(&item.path)
        ));
    }

    let temp = item.path.with_file_name(format!(
        "{}.part",
        file_label(&item.path)
    ));
    fs::write(&temp, &bytes).map_err(io_error)?;
    fs::rename(&temp, &item.path).map_err(io_error)?;
    Ok(())
}

fn is_present(path: &Path, size: u64) -> bool {
    match fs::metadata(path) {
        Ok(metadata) if metadata.is_file() => size == 0 || metadata.len() == size,
        _ => false,
    }
}

fn extract_natives(jar: &Path, natives_dir: &Path) -> Result<(), String> {
    let file = File::open(jar).map_err(io_error)?;
    let mut archive =
        ZipArchive::new(file).map_err(|_| "Нативная библиотека повреждена".to_string())?;

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .map_err(|_| "Не удалось прочитать нативную библиотеку".to_string())?;
        if entry.is_dir() {
            continue;
        }
        let Some(relative) = entry.enclosed_name() else {
            continue;
        };
        let is_native_binary = relative
            .extension()
            .and_then(|value| value.to_str())
            .is_some_and(|value| matches!(value, "dll" | "so" | "dylib" | "jnilib"));
        if !is_native_binary {
            continue;
        }
        let Some(name) = relative.file_name() else {
            continue;
        };

        let target = natives_dir.join(name);
        if target.is_file() {
            continue;
        }
        let mut out = File::create(&target).map_err(io_error)?;
        io::copy(&mut entry, &mut out).map_err(io_error)?;
    }

    Ok(())
}

async fn resolve_java(
    app: &AppHandle,
    client: &Client,
    mc_root: &Path,
    requirement: Option<&JavaVersion>,
    override_path: Option<&str>,
) -> Result<PathBuf, String> {
    let required = requirement.map(|value| value.major_version).unwrap_or(8);
    let component = requirement
        .map(|value| value.component.clone())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "java-runtime-delta".into());

    if let Some(java) = override_path
        .map(PathBuf::from)
        .filter(|path| path.is_file())
    {
        return Ok(java);
    }

    let runtime_dir = mc_root.join("java").join(&component);
    if let Some(java) = usable_java(&runtime_dir.join("bin"), required) {
        return Ok(java);
    }

    if let Ok(home) = std::env::var("JAVA_HOME") {
        if let Some(java) = usable_java(&PathBuf::from(home).join("bin"), required) {
            return Ok(java);
        }
    }

    emit(
        app,
        "java",
        format!("Загрузка Java {required} от Mojang…"),
        0,
        0,
    );
    install_java_runtime(app, client, &runtime_dir, &component).await?;

    usable_java(&runtime_dir.join("bin"), required)
        .ok_or_else(|| format!("Не удалось подготовить Java {required}"))
}

fn usable_java(bin_dir: &Path, required: u32) -> Option<PathBuf> {
    let probe = bin_dir.join(JAVA_CONSOLE_BINARY);
    if !probe.is_file() {
        return None;
    }
    if java_major(&probe)? < required {
        return None;
    }

    let windowless = bin_dir.join(JAVA_BINARY);
    Some(if windowless.is_file() { windowless } else { probe })
}

fn java_major(java: &Path) -> Option<u32> {
    let mut command = std::process::Command::new(java);
    command.arg("-version");
    hide_console(&mut command);

    let output = command.output().ok()?;
    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stderr),
        String::from_utf8_lossy(&output.stdout)
    );
    let quoted = text.split('"').nth(1)?;
    let mut parts = quoted.split(['.', '-', '+']);
    let first: u32 = parts.next()?.parse().ok()?;
    if first == 1 {
        parts.next()?.parse().ok()
    } else {
        Some(first)
    }
}

async fn install_java_runtime(
    app: &AppHandle,
    client: &Client,
    runtime_dir: &Path,
    component: &str,
) -> Result<(), String> {
    let platforms: HashMap<String, HashMap<String, Vec<RuntimeComponent>>> = client
        .get(JAVA_RUNTIME_MANIFEST_URL)
        .send()
        .await
        .map_err(|_| "Нет соединения со средой выполнения Mojang".to_string())?
        .json()
        .await
        .map_err(|_| "Mojang вернул неизвестный формат Java-манифеста".to_string())?;

    let entry = platforms
        .get(JAVA_PLATFORM)
        .and_then(|components| components.get(component))
        .and_then(|entries| entries.first())
        .ok_or_else(|| format!("Mojang не публикует {component} для этой системы"))?;

    let manifest: RuntimeManifest = client
        .get(&entry.manifest.url)
        .send()
        .await
        .map_err(|_| "Не удалось скачать состав Java".to_string())?
        .json()
        .await
        .map_err(|_| "Состав Java имеет неизвестный формат".to_string())?;

    let mut items = Vec::new();
    let mut executables = Vec::new();
    for (relative, file) in manifest.files {
        let target = runtime_dir.join(&relative);
        match file.kind.as_str() {
            "directory" => {
                fs::create_dir_all(&target).map_err(io_error)?;
            }
            "file" => {
                let Some(raw) = file.downloads.get("raw") else {
                    continue;
                };
                if file.executable {
                    executables.push(target.clone());
                }
                items.push(DownloadItem {
                    url: raw.url.clone(),
                    path: target,
                    sha1: raw.sha1.clone(),
                    size: raw.size,
                });
            }
            _ => {}
        }
    }

    download_many(app, client, items, "java", "Java").await?;
    mark_executable(&executables)?;
    Ok(())
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Option<T> {
    let contents = fs::read_to_string(path).ok()?;
    serde_json::from_str(&contents).ok()
}

fn write_text(path: &Path, contents: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(io_error)?;
    }
    fs::write(path, contents).map_err(io_error)
}

fn sha1_hex(bytes: &[u8]) -> String {
    hex::encode(Sha1::digest(bytes))
}

fn file_label(path: &Path) -> String {
    path.file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.to_string_lossy().into_owned())
}

#[cfg(windows)]
const CURRENT_OS: &str = "windows";
#[cfg(target_os = "macos")]
const CURRENT_OS: &str = "osx";
#[cfg(all(unix, not(target_os = "macos")))]
const CURRENT_OS: &str = "linux";

#[cfg(target_arch = "x86_64")]
const CURRENT_ARCH: &str = "x86_64";
#[cfg(target_arch = "aarch64")]
const CURRENT_ARCH: &str = "arm64";
#[cfg(target_arch = "x86")]
const CURRENT_ARCH: &str = "x86";

#[cfg(windows)]
const CLASSPATH_SEPARATOR: &str = ";";
#[cfg(not(windows))]
const CLASSPATH_SEPARATOR: &str = ":";

#[cfg(windows)]
const JAVA_BINARY: &str = "javaw.exe";
#[cfg(not(windows))]
const JAVA_BINARY: &str = "java";

#[cfg(windows)]
const JAVA_CONSOLE_BINARY: &str = "java.exe";
#[cfg(not(windows))]
const JAVA_CONSOLE_BINARY: &str = "java";

#[cfg(all(windows, target_arch = "x86_64"))]
const JAVA_PLATFORM: &str = "windows-x64";
#[cfg(all(windows, target_arch = "aarch64"))]
const JAVA_PLATFORM: &str = "windows-arm64";
#[cfg(all(windows, target_arch = "x86"))]
const JAVA_PLATFORM: &str = "windows-x86";
#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
const JAVA_PLATFORM: &str = "mac-os-arm64";
#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
const JAVA_PLATFORM: &str = "mac-os";
#[cfg(all(unix, not(target_os = "macos")))]
const JAVA_PLATFORM: &str = "linux";

#[cfg(windows)]
pub fn hide_console(command: &mut std::process::Command) {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    command.creation_flags(CREATE_NO_WINDOW);
}

#[cfg(not(windows))]
pub fn hide_console(_command: &mut std::process::Command) {}

#[cfg(test)]
mod tests {
    use super::*;

    fn rules(json: &str) -> Vec<Rule> {
        serde_json::from_str(json).expect("rules must parse")
    }

    #[test]
    fn maven_coordinates_become_repository_paths() {
        assert_eq!(
            maven_path("net.fabricmc:fabric-loader:0.19.3").as_deref(),
            Some("net/fabricmc/fabric-loader/0.19.3/fabric-loader-0.19.3.jar")
        );
        assert_eq!(
            maven_path("org.lwjgl:lwjgl:3.3.3:natives-windows").as_deref(),
            Some("org/lwjgl/lwjgl/3.3.3/lwjgl-3.3.3-natives-windows.jar")
        );
    }

    #[test]
    fn foreign_platform_libraries_are_skipped() {
        let osx = rules(r#"[{"action":"allow","os":{"name":"osx"}}]"#);
        assert_eq!(rules_allow(&osx), CURRENT_OS == "osx");

        let here = format!(r#"[{{"action":"allow","os":{{"name":"{CURRENT_OS}"}}}}]"#);
        assert!(rules_allow(&rules(&here)));
        assert!(rules_allow(&[]));
    }

    #[test]
    fn feature_gated_arguments_are_never_emitted() {
        let demo = rules(r#"[{"action":"allow","features":{"is_demo_user":true}}]"#);
        assert!(!rules_allow(&demo));
    }

    #[test]
    fn thirty_two_bit_stack_flag_is_not_applied_on_wider_targets() {
        let x86 = rules(r#"[{"action":"allow","os":{"arch":"x86"}}]"#);
        assert_eq!(rules_allow(&x86), CURRENT_ARCH == "x86");
    }

    #[test]
    fn only_classifier_libraries_count_as_natives() {
        assert!(is_native("org.lwjgl:lwjgl:3.3.3:natives-windows"));
        assert!(!is_native("org.lwjgl:lwjgl:3.3.3"));
        assert!(!is_native("net.fabricmc:fabric-loader:0.19.3"));
    }

    #[test]
    fn library_versions_collapse_so_fabric_wins_over_vanilla() {
        assert_eq!(dedup_key("org.ow2.asm:asm:9.10.1"), dedup_key("org.ow2.asm:asm:9.6"));
        assert_ne!(
            dedup_key("org.lwjgl:lwjgl:3.3.3"),
            dedup_key("org.lwjgl:lwjgl:3.3.3:natives-windows")
        );
    }

    #[test]
    fn placeholders_resolve_from_the_variable_table() {
        let mut variables = HashMap::new();
        variables.insert("natives_directory", "C:\\natives".to_string());
        variables.insert("auth_player_name", "Steve".to_string());

        assert_eq!(
            substitute("-Djava.library.path=${natives_directory}", &variables),
            "-Djava.library.path=C:\\natives"
        );
        assert_eq!(substitute("${auth_player_name}", &variables), "Steve");
        assert_eq!(substitute("${unknown}", &variables), "${unknown}");
    }

    #[test]
    fn conditional_argument_groups_expand_in_order() {
        let mut variables = HashMap::new();
        variables.insert("classpath", "a.jar;b.jar".to_string());

        let items: Vec<Value> = serde_json::from_str(
            r#"["-cp","${classpath}",
                {"rules":[{"action":"allow","features":{"has_custom_resolution":true}}],
                 "value":["--width","640"]}]"#,
        )
        .expect("arguments must parse");

        let mut out = Vec::new();
        collect_arguments(&items, &variables, &mut out);
        assert_eq!(out, vec!["-cp", "a.jar;b.jar"]);
    }
}

#[cfg(unix)]
fn mark_executable(paths: &[PathBuf]) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;

    for path in paths {
        if let Ok(metadata) = fs::metadata(path) {
            let mut permissions = metadata.permissions();
            permissions.set_mode(permissions.mode() | 0o755);
            fs::set_permissions(path, permissions).map_err(io_error)?;
        }
    }
    Ok(())
}

#[cfg(not(unix))]
fn mark_executable(_paths: &[PathBuf]) -> Result<(), String> {
    Ok(())
}
