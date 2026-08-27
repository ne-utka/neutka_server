import { invoke } from "@tauri-apps/api/core";
import type {
  ArchitectureStatus,
  DistributionStatus,
  LaunchStatus,
  PlayResult,
} from "@/entities/launcher/model";

export interface DeviceCodeChallenge {
  deviceCode: string;
  userCode: string;
  verificationUri: string;
  expiresIn: number;
  interval: number;
  message: string;
}

export interface NicknameChallenge {
  code: string;
  userCode: string;
  nick: string;
  expiresIn: number;
}

export interface AuthenticatedProfile {
  id: string;
  name: string;
  kind: "microsoft" | "telegram";
}

const NICKNAME_AUTH_URL = "https://springrp.ru/auth-bot/launcher.php";

function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

function formatLoginCode(code: string): string {
  return code.length === 6 ? `${code.slice(0, 3)} ${code.slice(3)}` : code;
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function startNicknameAuthInBrowser(
  nick: string,
): Promise<NicknameChallenge> {
  const response = await fetch(NICKNAME_AUTH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ nick }),
  });
  const payload = (await response.json()) as {
    ok?: boolean;
    error?: string;
    code?: string;
    user_code?: string;
    nick?: string;
    expires_in?: number;
  };
  if (!payload.ok) {
    throw payload.error === "not_bound"
      ? "not_bound"
      : "Не удалось начать вход по нику";
  }
  const code = payload.code ?? "";
  return {
    code,
    userCode: payload.user_code ?? formatLoginCode(code),
    nick: payload.nick ?? nick,
    expiresIn: payload.expires_in ?? 300,
  };
}

async function completeNicknameAuthInBrowser(
  challenge: NicknameChallenge,
): Promise<AuthenticatedProfile> {
  const deadline = Date.now() + Math.min(600, Math.max(30, challenge.expiresIn)) * 1000;
  while (Date.now() < deadline) {
    const response = await fetch(
      `${NICKNAME_AUTH_URL}?code=${encodeURIComponent(challenge.code)}`,
    );
    const payload = (await response.json()) as {
      status?: string;
      nick?: string;
    };
    if (payload.status === "verified") {
      return {
        id: "0",
        name: payload.nick || challenge.nick,
        kind: "telegram",
      };
    }
    if (payload.status === "expired") {
      throw "Код истёк. Нажмите «Продолжить» ещё раз";
    }
    if (payload.status === "missing") {
      throw "Код больше не действует. Нажмите «Продолжить» ещё раз";
    }
    await delay(2000);
  }
  throw "Время ожидания кода истекло. Нажмите «Продолжить» ещё раз";
}

/**
 * The only frontend boundary for launcher-related Tauri commands.
 * UI modules must not call `invoke` directly.
 */
export function getArchitectureStatus(): Promise<ArchitectureStatus> {
  return invoke<ArchitectureStatus>("get_architecture_status");
}

export function startMicrosoftAuth(): Promise<DeviceCodeChallenge> {
  return invoke<DeviceCodeChallenge>("start_microsoft_auth");
}

export function completeMicrosoftAuth(
  challenge: DeviceCodeChallenge,
): Promise<AuthenticatedProfile> {
  return invoke<AuthenticatedProfile>("complete_microsoft_auth", {
    deviceCode: challenge.deviceCode,
    interval: challenge.interval,
    expiresIn: challenge.expiresIn,
  });
}

export function startNicknameAuth(nick: string): Promise<NicknameChallenge> {
  if (!isTauri()) {
    return startNicknameAuthInBrowser(nick);
  }
  return invoke<NicknameChallenge>("start_nickname_auth", { nick });
}

export function completeNicknameAuth(
  challenge: NicknameChallenge,
): Promise<AuthenticatedProfile> {
  if (!isTauri()) {
    return completeNicknameAuthInBrowser(challenge);
  }
  return invoke<AuthenticatedProfile>("complete_nickname_auth", {
    code: challenge.code,
    expiresIn: challenge.expiresIn,
  });
}

export function getAuthenticatedProfile(): Promise<AuthenticatedProfile | null> {
  return invoke<AuthenticatedProfile | null>("get_authenticated_profile");
}

export function signOut(): Promise<void> {
  return invoke("sign_out");
}

export function getDistributionStatus(): Promise<DistributionStatus> {
  return invoke<DistributionStatus>("get_distribution_status");
}

export function setOptionalMods(ids: string[]): Promise<void> {
  return invoke("set_optional_mods", { ids });
}

export function setMemoryGb(memoryGb: number): Promise<void> {
  return invoke("set_memory_gb", { memoryGb });
}

export function getLaunchStatus(): Promise<LaunchStatus> {
  return invoke<LaunchStatus>("get_launch_status");
}

export function playGame(): Promise<PlayResult> {
  return invoke<PlayResult>("play_game");
}

export function reinstallGame(): Promise<PlayResult> {
  return invoke<PlayResult>("reinstall_game");
}

export function openGameFolder(): Promise<void> {
  return invoke("open_game_folder");
}
