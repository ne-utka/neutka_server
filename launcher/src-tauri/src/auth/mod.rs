use std::{
    sync::Mutex,
    time::{Duration, Instant},
};

use reqwest::{Client, StatusCode};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

const CLIENT_ID: &str = "d901c992-cb44-480a-b86d-d59b74083e04";
const MICROSOFT_SCOPE: &str = "XboxLive.signin offline_access";
const DEVICE_CODE_URL: &str =
    "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode";
const TOKEN_URL: &str =
    "https://login.microsoftonline.com/consumers/oauth2/v2.0/token";
const NICKNAME_AUTH_URL: &str = "https://springrp.ru/auth-bot/launcher.php";
const OFFLINE_PROFILE_ID: &str = "00000000000000000000000000000000";
const OFFLINE_ACCESS_TOKEN: &str = "0";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceCodeChallenge {
    pub device_code: String,
    pub user_code: String,
    pub verification_uri: String,
    pub expires_in: u64,
    pub interval: u64,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NicknameChallenge {
    pub code: String,
    pub user_code: String,
    pub nick: String,
    pub expires_in: u64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ProfileKind {
    Microsoft,
    Telegram,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthenticatedProfile {
    pub id: String,
    pub name: String,
    pub kind: ProfileKind,
}

#[derive(Default)]
pub struct AuthState {
    session: Mutex<Option<AuthSession>>,
}

enum AuthKind {
    Telegram,
    Microsoft,
}

struct AuthSession {
    kind: AuthKind,
    profile: AuthenticatedProfile,
    minecraft_access_token: String,
    _microsoft_refresh_token: Option<String>,
}

#[derive(Debug, Clone)]
pub struct LaunchIdentity {
    pub name: String,
    pub uuid: String,
    pub access_token: String,
}

impl AuthState {
    pub fn replace(
        &self,
        profile: AuthenticatedProfile,
        minecraft_access_token: String,
        microsoft_refresh_token: Option<String>,
    ) -> Result<(), String> {
        self.replace_session(
            AuthKind::Microsoft,
            profile,
            minecraft_access_token,
            microsoft_refresh_token,
        )
    }

    pub fn replace_telegram(&self, name: &str) -> Result<AuthenticatedProfile, String> {
        if !is_minecraft_nick(name) {
            return Err("Ник должен быть 3–16 символов: латиница, цифры и _".into());
        }
        let profile = AuthenticatedProfile {
            id: OFFLINE_PROFILE_ID.into(),
            name: name.to_string(),
            kind: ProfileKind::Telegram,
        };
        self.replace_session(
            AuthKind::Telegram,
            profile.clone(),
            OFFLINE_ACCESS_TOKEN.into(),
            None,
        )?;
        Ok(profile)
    }

    fn replace_session(
        &self,
        kind: AuthKind,
        profile: AuthenticatedProfile,
        minecraft_access_token: String,
        microsoft_refresh_token: Option<String>,
    ) -> Result<(), String> {
        let mut profile = profile;
        profile.kind = match kind {
            AuthKind::Microsoft => ProfileKind::Microsoft,
            AuthKind::Telegram => ProfileKind::Telegram,
        };
        let session = AuthSession {
            kind,
            profile,
            minecraft_access_token,
            _microsoft_refresh_token: microsoft_refresh_token,
        };
        *self
            .session
            .lock()
            .map_err(|_| "Не удалось сохранить сессию авторизации".to_string())? =
            Some(session);
        Ok(())
    }

    pub fn clear(&self) -> Result<(), String> {
        *self
            .session
            .lock()
            .map_err(|_| "Не удалось завершить сессию авторизации".to_string())? =
            None;
        Ok(())
    }

    pub fn profile(&self) -> Result<Option<AuthenticatedProfile>, String> {
        Ok(self
            .session
            .lock()
            .map_err(|_| "Не удалось прочитать сессию авторизации".to_string())?
            .as_ref()
            .map(|session| session.profile.clone()))
    }

    pub fn launch_identity(&self) -> Result<LaunchIdentity, String> {
        let session = self
            .session
            .lock()
            .map_err(|_| "Не удалось прочитать сессию авторизации".to_string())?;
        let session = session
            .as_ref()
            .ok_or_else(|| "Сначала авторизуйтесь".to_string())?;

        match session.kind {
            AuthKind::Telegram => Ok(LaunchIdentity {
                name: session.profile.name.clone(),
                uuid: hyphenate_uuid(OFFLINE_PROFILE_ID),
                access_token: OFFLINE_ACCESS_TOKEN.into(),
            }),
            AuthKind::Microsoft => Ok(LaunchIdentity {
                name: session.profile.name.clone(),
                uuid: hyphenate_uuid(&session.profile.id),
                access_token: session.minecraft_access_token.clone(),
            }),
        }
    }
}

fn hyphenate_uuid(value: &str) -> String {
    let compact: String = value.chars().filter(|ch| *ch != '-').collect();
    if compact.len() != 32 {
        return value.to_string();
    }
    format!(
        "{}-{}-{}-{}-{}",
        &compact[0..8],
        &compact[8..12],
        &compact[12..16],
        &compact[16..20],
        &compact[20..32]
    )
}

#[derive(Deserialize)]
struct DeviceCodeResponse {
    device_code: String,
    user_code: String,
    verification_uri: String,
    expires_in: u64,
    interval: Option<u64>,
    message: String,
}

#[derive(Deserialize)]
struct MicrosoftTokenResponse {
    access_token: String,
    refresh_token: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct XboxTokenResponse {
    token: String,
    display_claims: XboxDisplayClaims,
}

#[derive(Deserialize)]
struct XboxDisplayClaims {
    xui: Vec<XboxUserClaim>,
}

#[derive(Deserialize)]
struct XboxUserClaim {
    uhs: String,
}

#[derive(Deserialize)]
struct MinecraftTokenResponse {
    access_token: String,
}

pub struct MicrosoftAuthResult {
    pub profile: AuthenticatedProfile,
    pub minecraft_access_token: String,
    pub microsoft_refresh_token: Option<String>,
}

pub async fn request_device_code() -> Result<DeviceCodeChallenge, String> {
    let response = Client::new()
        .post(DEVICE_CODE_URL)
        .form(&[("client_id", CLIENT_ID), ("scope", MICROSOFT_SCOPE)])
        .send()
        .await
        .map_err(network_error)?;

    if !response.status().is_success() {
        return Err(api_error("Microsoft", response).await);
    }

    let response: DeviceCodeResponse = response
        .json()
        .await
        .map_err(|_| "Microsoft вернул некорректный ответ".to_string())?;

    Ok(DeviceCodeChallenge {
        device_code: response.device_code,
        user_code: response.user_code,
        verification_uri: response.verification_uri,
        expires_in: response.expires_in,
        interval: response.interval.unwrap_or(5),
        message: response.message,
    })
}

pub async fn complete_device_flow(
    device_code: &str,
    interval: u64,
    expires_in: u64,
) -> Result<MicrosoftAuthResult, String> {
    let client = Client::new();
    let microsoft_token =
        poll_microsoft_token(&client, device_code, interval, expires_in).await?;
    minecraft_session_from_microsoft_token(&client, microsoft_token).await
}

pub enum MicrosoftRestoreError {
    Expired,
    Unavailable,
}

pub async fn restore_microsoft_session(
    access_token: &str,
    refresh_token: Option<&str>,
) -> Result<MicrosoftAuthResult, MicrosoftRestoreError> {
    let client = Client::new();
    if let Some(refresh) = refresh_token.filter(|value| !value.is_empty()) {
        match refresh_microsoft_token(&client, refresh).await {
            Ok(token) => {
                return minecraft_session_from_microsoft_token(&client, token)
                    .await
                    .map_err(|_| MicrosoftRestoreError::Unavailable);
            }
            Err(MicrosoftRestoreError::Expired) => {
                return Err(MicrosoftRestoreError::Expired);
            }
            Err(MicrosoftRestoreError::Unavailable) => {}
        }
    }

    match load_minecraft_profile(&client, access_token).await {
        Ok(profile) => Ok(MicrosoftAuthResult {
            profile,
            minecraft_access_token: access_token.to_string(),
            microsoft_refresh_token: refresh_token.map(str::to_owned),
        }),
        Err(error) if error == "expired" => Err(MicrosoftRestoreError::Expired),
        Err(_) => Err(MicrosoftRestoreError::Unavailable),
    }
}

async fn minecraft_session_from_microsoft_token(
    client: &Client,
    microsoft_token: MicrosoftTokenResponse,
) -> Result<MicrosoftAuthResult, String> {
    let (xbox_token, _) =
        authenticate_xbox_live(client, &microsoft_token.access_token).await?;
    let (xsts_token, user_hash) = authorize_xsts(client, &xbox_token).await?;
    let minecraft_access_token =
        authenticate_minecraft(client, &user_hash, &xsts_token).await?;
    let profile = load_minecraft_profile(client, &minecraft_access_token).await?;

    Ok(MicrosoftAuthResult {
        profile,
        minecraft_access_token,
        microsoft_refresh_token: microsoft_token.refresh_token,
    })
}

async fn poll_microsoft_token(
    client: &Client,
    device_code: &str,
    interval: u64,
    expires_in: u64,
) -> Result<MicrosoftTokenResponse, String> {
    let deadline =
        Instant::now() + Duration::from_secs(expires_in.clamp(60, 1_800));
    let mut delay = interval.clamp(5, 30);

    while Instant::now() < deadline {
        tokio::time::sleep(Duration::from_secs(delay)).await;

        let response = client
            .post(TOKEN_URL)
            .form(&[
                (
                    "grant_type",
                    "urn:ietf:params:oauth:grant-type:device_code",
                ),
                ("client_id", CLIENT_ID),
                ("device_code", device_code),
            ])
            .send()
            .await
            .map_err(network_error)?;

        let status = response.status();
        let payload: Value = response
            .json()
            .await
            .map_err(|_| "Microsoft вернул некорректный ответ".to_string())?;

        if status.is_success() {
            return serde_json::from_value(payload)
                .map_err(|_| "Microsoft не вернул access token".to_string());
        }

        match payload.get("error").and_then(Value::as_str) {
            Some("authorization_pending") => continue,
            Some("slow_down") => {
                delay = (delay + 5).min(30);
                continue;
            }
            Some("authorization_declined") | Some("access_denied") => {
                return Err("Авторизация Microsoft была отменена".into());
            }
            Some("expired_token") | Some("code_expired") => {
                return Err("Код Microsoft истёк. Попробуйте ещё раз".into());
            }
            _ => {
                return Err(payload
                    .get("error_description")
                    .and_then(Value::as_str)
                    .unwrap_or("Microsoft отклонил авторизацию")
                    .to_string());
            }
        }
    }

    Err("Время ожидания авторизации Microsoft истекло".into())
}

async fn refresh_microsoft_token(
    client: &Client,
    refresh_token: &str,
) -> Result<MicrosoftTokenResponse, MicrosoftRestoreError> {
    let response = client
        .post(TOKEN_URL)
        .form(&[
            ("grant_type", "refresh_token"),
            ("client_id", CLIENT_ID),
            ("refresh_token", refresh_token),
            ("scope", MICROSOFT_SCOPE),
        ])
        .send()
        .await
        .map_err(|_| MicrosoftRestoreError::Unavailable)?;

    let status = response.status();
    let payload: Value = response
        .json()
        .await
        .map_err(|_| MicrosoftRestoreError::Unavailable)?;

    if status.is_success() {
        return serde_json::from_value(payload).map_err(|_| MicrosoftRestoreError::Unavailable);
    }

    match payload.get("error").and_then(Value::as_str) {
        Some("invalid_grant") | Some("expired_token") | Some("code_expired") => {
            Err(MicrosoftRestoreError::Expired)
        }
        _ => Err(MicrosoftRestoreError::Unavailable),
    }
}

async fn authenticate_xbox_live(
    client: &Client,
    microsoft_access_token: &str,
) -> Result<(String, String), String> {
    let response = client
        .post("https://user.auth.xboxlive.com/user/authenticate")
        .json(&json!({
            "Properties": {
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": format!("d={microsoft_access_token}")
            },
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT"
        }))
        .send()
        .await
        .map_err(network_error)?;

    if !response.status().is_success() {
        return Err(api_error("Xbox Live", response).await);
    }

    xbox_token_from_response(response).await
}

async fn authorize_xsts(
    client: &Client,
    xbox_token: &str,
) -> Result<(String, String), String> {
    let response = client
        .post("https://xsts.auth.xboxlive.com/xsts/authorize")
        .json(&json!({
            "Properties": {
                "SandboxId": "RETAIL",
                "UserTokens": [xbox_token]
            },
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT"
        }))
        .send()
        .await
        .map_err(network_error)?;

    if response.status() == StatusCode::UNAUTHORIZED {
        let payload: Value = response.json().await.unwrap_or_default();
        return Err(match payload.get("XErr").and_then(Value::as_u64) {
            Some(2_148_916_233) => {
                "У аккаунта Microsoft нет профиля Xbox".into()
            }
            Some(2_148_916_235) => {
                "Xbox Live недоступен в регионе аккаунта".into()
            }
            Some(2_148_916_238) => {
                "Детскому аккаунту требуется добавление в семейную группу"
                    .into()
            }
            _ => "Xbox XSTS отклонил авторизацию".into(),
        });
    }

    if !response.status().is_success() {
        return Err(api_error("Xbox XSTS", response).await);
    }

    xbox_token_from_response(response).await
}

async fn xbox_token_from_response(
    response: reqwest::Response,
) -> Result<(String, String), String> {
    let token: XboxTokenResponse = response
        .json()
        .await
        .map_err(|_| "Xbox вернул некорректный ответ".to_string())?;
    let user_hash = token
        .display_claims
        .xui
        .first()
        .map(|claim| claim.uhs.clone())
        .ok_or_else(|| "Xbox не вернул идентификатор пользователя".to_string())?;
    Ok((token.token, user_hash))
}

async fn authenticate_minecraft(
    client: &Client,
    user_hash: &str,
    xsts_token: &str,
) -> Result<String, String> {
    let response = client
        .post("https://api.minecraftservices.com/authentication/login_with_xbox")
        .json(&json!({
            "identityToken": format!("XBL3.0 x={user_hash};{xsts_token}")
        }))
        .send()
        .await
        .map_err(network_error)?;

    if !response.status().is_success() {
        return Err(api_error("Minecraft", response).await);
    }

    response
        .json::<MinecraftTokenResponse>()
        .await
        .map(|token| token.access_token)
        .map_err(|_| "Minecraft не вернул access token".to_string())
}

#[derive(Deserialize)]
struct MinecraftProfileResponse {
    id: String,
    name: String,
}

async fn load_minecraft_profile(
    client: &Client,
    access_token: &str,
) -> Result<AuthenticatedProfile, String> {
    let response = client
        .get("https://api.minecraftservices.com/minecraft/profile")
        .bearer_auth(access_token)
        .send()
        .await
        .map_err(network_error)?;

    if response.status() == StatusCode::NOT_FOUND {
        return Err("На аккаунте нет приобретённой Minecraft: Java Edition".into());
    }
    if response.status() == StatusCode::UNAUTHORIZED {
        return Err("expired".into());
    }
    if !response.status().is_success() {
        return Err(api_error("Minecraft Profile", response).await);
    }

    let profile: MinecraftProfileResponse = response
        .json()
        .await
        .map_err(|_| "Minecraft вернул некорректный профиль".to_string())?;
    Ok(AuthenticatedProfile {
        id: profile.id,
        name: profile.name,
        kind: ProfileKind::Microsoft,
    })
}

pub async fn start_nickname_auth(nick: &str) -> Result<NicknameChallenge, String> {
    let nick = nick.trim();
    if !is_minecraft_nick(nick) {
        return Err("Ник должен быть 3–16 символов: латиница, цифры и _".into());
    }

    let response = Client::new()
        .post(NICKNAME_AUTH_URL)
        .json(&json!({ "nick": nick }))
        .send()
        .await
        .map_err(|_| "Нет соединения с сервером авторизации".to_string())?;

    let payload: Value = response
        .json()
        .await
        .map_err(|_| "Сервер авторизации вернул некорректный ответ".to_string())?;

    if payload.get("ok").and_then(Value::as_bool) != Some(true) {
        return Err(match payload.get("error").and_then(Value::as_str) {
            Some("not_bound") => "not_bound".into(),
            Some("bad_nick") => {
                "Ник должен быть 3–16 символов: латиница, цифры и _".into()
            }
            _ => "Не удалось начать вход по нику".into(),
        });
    }

    let code = payload
        .get("code")
        .and_then(Value::as_str)
        .ok_or_else(|| "Сервер авторизации не вернул код".to_string())?;
    let user_code = payload
        .get("user_code")
        .and_then(Value::as_str)
        .map(str::to_owned)
        .unwrap_or_else(|| format_login_code(code));
    let bound_nick = payload
        .get("nick")
        .and_then(Value::as_str)
        .unwrap_or(nick)
        .to_string();
    let expires_in = payload
        .get("expires_in")
        .and_then(Value::as_u64)
        .unwrap_or(300);

    Ok(NicknameChallenge {
        code: code.to_string(),
        user_code,
        nick: bound_nick,
        expires_in,
    })
}

pub async fn complete_nickname_auth(
    code: &str,
    expires_in: u64,
) -> Result<String, String> {
    let client = Client::new();
    let deadline = Instant::now() + Duration::from_secs(expires_in.clamp(30, 600));

    loop {
        let response = client
            .get(format!("{NICKNAME_AUTH_URL}?code={code}"))
            .send()
            .await
            .map_err(|_| "Нет соединения с сервером авторизации".to_string())?;
        let payload: Value = response
            .json()
            .await
            .map_err(|_| "Сервер авторизации вернул некорректный ответ".to_string())?;

        match payload.get("status").and_then(Value::as_str) {
            Some("verified") => {
                let nick = payload
                    .get("nick")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .trim();
                if is_minecraft_nick(nick) {
                    return Ok(nick.to_string());
                }
                return Err("Сервер авторизации вернул некорректный ник".into());
            }
            Some("pending") => {}
            Some("expired") => {
                return Err("Код истёк. Нажмите «Продолжить» ещё раз".into());
            }
            Some("missing") => {
                return Err("Код больше не действует. Нажмите «Продолжить» ещё раз".into());
            }
            _ => {
                return Err("Сервер авторизации вернул некорректный ответ".into());
            }
        }

        if Instant::now() >= deadline {
            return Err("Время ожидания кода истекло. Нажмите «Продолжить» ещё раз".into());
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

pub async fn nickname_still_bound(nick: &str) -> Result<bool, String> {
    let nick = nick.trim();
    if !is_minecraft_nick(nick) {
        return Ok(false);
    }

    let response = Client::new()
        .get(format!("{NICKNAME_AUTH_URL}?nick={nick}"))
        .send()
        .await
        .map_err(|_| "unavailable".to_string())?;
    let payload: Value = response
        .json()
        .await
        .map_err(|_| "unavailable".to_string())?;

    if payload.get("ok").and_then(Value::as_bool) == Some(true) {
        return Ok(true);
    }
    if payload.get("error").and_then(Value::as_str) == Some("not_bound") {
        return Ok(false);
    }
    Err("unavailable".into())
}

pub(crate) fn is_minecraft_nick(value: &str) -> bool {
    let len = value.len();
    (3..=16).contains(&len) && value.chars().all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn format_login_code(code: &str) -> String {
    if code.len() == 6 {
        format!("{} {}", &code[..3], &code[3..])
    } else {
        code.to_string()
    }
}

fn network_error(_: reqwest::Error) -> String {
    "Нет соединения с сервисами Microsoft".into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn launch_without_session_requires_authorization() {
        let state = AuthState::default();
        let error = state.launch_identity().unwrap_err();
        assert_eq!(error, "Сначала авторизуйтесь");
    }

    #[test]
    fn launch_telegram_session_uses_offline_identity() {
        let state = AuthState::default();
        let profile = state.replace_telegram("OfflineName").unwrap();
        assert_eq!(profile.name, "OfflineName");

        let identity = state.launch_identity().unwrap();
        assert_eq!(identity.name, "OfflineName");
        assert_eq!(identity.uuid, "00000000-0000-0000-0000-000000000000");
        assert_eq!(identity.access_token, "0");
        assert_eq!(profile.kind, ProfileKind::Telegram);
    }

    #[test]
    fn launch_uses_the_authenticated_minecraft_identity() {
        let state = AuthState::default();
        state
            .replace(
                AuthenticatedProfile {
                    id: "123456781234123412341234567890ab".into(),
                    name: "SpringPlayer".into(),
                    kind: ProfileKind::Microsoft,
                },
                "minecraft-token".into(),
                None,
            )
            .unwrap();

        let identity = state.launch_identity().unwrap();
        assert_eq!(identity.name, "SpringPlayer");
        assert_eq!(identity.uuid, "12345678-1234-1234-1234-1234567890ab");
        assert_eq!(identity.access_token, "minecraft-token");
        assert_eq!(
            state.profile().unwrap().unwrap().kind,
            ProfileKind::Microsoft
        );
    }

    #[test]
    fn login_code_is_shown_in_two_groups() {
        assert_eq!(format_login_code("482193"), "482 193");
    }

    #[test]
    fn minecraft_nicks_match_offline_rules() {
        assert!(is_minecraft_nick("Steve"));
        assert!(is_minecraft_nick("A_1"));
        assert!(!is_minecraft_nick("аб"));
        assert!(!is_minecraft_nick("ab"));
    }
}

async fn api_error(service: &str, response: reqwest::Response) -> String {
    let status = response.status();
    let detail = response
        .json::<Value>()
        .await
        .ok()
        .and_then(|payload| {
            payload
                .get("error_description")
                .or_else(|| payload.get("errorMessage"))
                .or_else(|| payload.get("message"))
                .and_then(Value::as_str)
                .map(str::to_owned)
        });

    if detail
        .as_deref()
        .is_some_and(|message| message.contains("Invalid app registration"))
    {
        return "SpringRP ожидает одобрения Minecraft Services. Авторизация станет доступна после проверки Client ID."
            .into();
    }

    detail.unwrap_or_else(|| format!("{service} вернул ошибку {status}"))
}
