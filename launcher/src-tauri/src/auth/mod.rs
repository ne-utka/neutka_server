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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthenticatedProfile {
    pub id: String,
    pub name: String,
}

#[derive(Default)]
pub struct AuthState {
    session: Mutex<Option<AuthSession>>,
}

struct AuthSession {
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
        let session = AuthSession {
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

    pub fn launch_identity(&self, _nickname: &str) -> Result<LaunchIdentity, String> {
        let session = self
            .session
            .lock()
            .map_err(|_| "Не удалось прочитать сессию авторизации".to_string())?;

        if let Some(session) = session.as_ref() {
            return Ok(LaunchIdentity {
                name: session.profile.name.clone(),
                uuid: hyphenate_uuid(&session.profile.id),
                access_token: session.minecraft_access_token.clone(),
            });
        }

        Err(
            "Для запуска SpringRP требуется авторизация Microsoft. Вернитесь на экран входа и войдите в аккаунт с приобретённой Minecraft: Java Edition."
                .into(),
        )
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
    let (xbox_token, _) =
        authenticate_xbox_live(&client, &microsoft_token.access_token).await?;
    let (xsts_token, user_hash) = authorize_xsts(&client, &xbox_token).await?;
    let minecraft_access_token =
        authenticate_minecraft(&client, &user_hash, &xsts_token).await?;
    let profile =
        load_minecraft_profile(&client, &minecraft_access_token).await?;

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
    if !response.status().is_success() {
        return Err(api_error("Minecraft Profile", response).await);
    }

    response
        .json()
        .await
        .map_err(|_| "Minecraft вернул некорректный профиль".to_string())
}

fn network_error(_: reqwest::Error) -> String {
    "Нет соединения с сервисами Microsoft".into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn launch_without_microsoft_session_is_rejected() {
        let state = AuthState::default();
        let error = state.launch_identity("OfflineName").unwrap_err();
        assert!(error.contains("авторизация Microsoft"));
    }

    #[test]
    fn launch_uses_the_authenticated_minecraft_identity() {
        let state = AuthState::default();
        state
            .replace(
                AuthenticatedProfile {
                    id: "123456781234123412341234567890ab".into(),
                    name: "SpringPlayer".into(),
                },
                "minecraft-token".into(),
                None,
            )
            .unwrap();

        let identity = state.launch_identity("IgnoredName").unwrap();
        assert_eq!(identity.name, "SpringPlayer");
        assert_eq!(identity.uuid, "12345678-1234-1234-1234-1234567890ab");
        assert_eq!(identity.access_token, "minecraft-token");
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
