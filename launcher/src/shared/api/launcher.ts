import { invoke } from "@tauri-apps/api/core";
import type { ArchitectureStatus } from "@/entities/launcher/model";

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
