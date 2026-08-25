import { invoke } from "@tauri-apps/api/core";
import type {
  ArchitectureStatus,
  DistributionStatus,
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

export interface AuthenticatedProfile {
  id: string;
  name: string;
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

export function getAuthenticatedProfile(): Promise<AuthenticatedProfile | null> {
  return invoke<AuthenticatedProfile | null>("get_authenticated_profile");
}

export function signOutMicrosoft(): Promise<void> {
  return invoke("sign_out_microsoft");
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

export function playGame(nickname: string): Promise<PlayResult> {
  return invoke<PlayResult>("play_game", { nickname });
}

export function openGameFolder(): Promise<void> {
  return invoke("open_game_folder");
}
